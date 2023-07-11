// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ERC4626} from "solmate/src/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {StableMath} from "./libs/StableMath.sol";
import {ICERC20} from "./interfaces/ICERC20.sol";
import {LibCompound} from "./libs/LibCompound.sol";
import {IComptroller} from "./interfaces/IComptroller.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {DexSwap} from "./utils/swapUtils.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "hardhat/console.sol";

/// @title CompoundV2ERC4626Wrapper
/// @notice Custom implementation of yield-daddy wrappers with flexible reinvesting logic
/// @notice Rationale: Forked protocols often implement custom functions and modules on top of forked code.
/// @author ZeroPoint Labs
contract CompoundV2ERC4626Wrapper is ERC4626 {
    /*//////////////////////////////////////////////////////////////
                            LIBRARIES USAGE
    //////////////////////////////////////////////////////////////*/

    using LibCompound for ICERC20;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using StableMath for uint;
    using StableMath for int;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a call to Compound returned an error.
    /// @param errorCode The error code returned by Compound
    error COMPOUND_ERROR(uint256 errorCode);
    /// @notice Thrown when reinvest amount is not enough.
    error MIN_AMOUNT_ERROR();
    /// @notice Thrown when caller is not the manager.
    error INVALID_ACCESS_ERROR();
    /// @notice Thrown when swap path fee in reinvest is invalid.
    error INVALID_FEE_ERROR();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant NO_ERROR = 0;

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLES & VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Access Control for harvest() route
    address public immutable manager;

    /// @notice The COMP-like token contract
    ERC20 public immutable reward;

    /// @notice The Compound cToken contract
    ICERC20 public immutable cToken;

    /// @notice The Compound comptroller contract
    IComptroller public immutable comptroller;

    /// @notice Pointer to swapInfo
    bytes public swapPath;

    ISwapRouter public immutable swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    /// Compact struct to make two swaps (PancakeSwap on BSC)
    /// A => B (using pair1) then B => asset (of Wrapper) (using pair2)
    struct swapInfo {
        address token;
        address pair1;
        address pair2;
    }

    /* Swap params */
    struct SwapParams {
        uint256 minHarvest;
        uint256 slippage;
        uint256 wait;
        uint24 poolFee;
        uint8 enabled;
    }

    SwapParams swapParams;

    /*//////////////////////////////////////////////////////////////
                        CHAINLINK PRICE FEEDS
    //////////////////////////////////////////////////////////////*/

    AggregatorV3Interface public rewardPriceFeed =
        AggregatorV3Interface(0x0D276FC14719f9292D5C1eA2198673d1f4269246);

    AggregatorV3Interface public wantPriceFeed;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the CompoundV2ERC4626Wrapper
    /// @param asset_ The address of the underlying asset
    /// @param reward_ The address of the reward token
    /// @param cToken_ The address of the cToken
    /// @param comptroller_ The address of the comptroller
    /// @param manager_ The address of the manager
    constructor(
        ERC20 asset_, // underlying
        ERC20 reward_, // comp token or other
        ICERC20 cToken_, // compound concept of a share
        IComptroller comptroller_,
        AggregatorV3Interface wantPriceFeed_,
        address manager_,
        

    ) ERC4626(asset_, _vaultName(asset_), _vaultSymbol(asset_)) {
        reward = reward_;
        cToken = cToken_;
        comptroller = comptroller_;
        wantPriceFeed = wantPriceFeed_;
        manager = manager_;
        ICERC20[] memory cTokens = new ICERC20[](1);
        cTokens[0] = cToken;
        comptroller.enterMarkets(cTokens);
    }

    /*//////////////////////////////////////////////////////////////
                            CUSTOM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Updates value of "exchangeRateStored()"
    function accrueInterest() public {
        cToken.accrueInterest();
    }

    /*//////////////////////////////////////////////////////////////
                            REWARDS
    //////////////////////////////////////////////////////////////*/

    /// @notice sets the swap path for reinvesting rewards
    /// @param poolFee1_ fee for first swap
    /// @param tokenMid_ token for first swap
    /// @param poolFee2_ fee for second swap
    function setRoute(
        uint24 poolFee1_,
        address tokenMid_,
        uint24 poolFee2_
    ) external {
        if (msg.sender != manager) revert INVALID_ACCESS_ERROR();
        if (poolFee1_ == 0) revert INVALID_FEE_ERROR();
        if (poolFee2_ == 0 || tokenMid_ == address(0))
            swapPath = abi.encodePacked(reward, poolFee1_, address(asset));
        else
            swapPath = abi.encodePacked(
                reward,
                poolFee1_,
                tokenMid_, // usually wETH
                poolFee2_,
                address(asset)
            );
        ERC20(reward).approve(address(swapRouter), type(uint256).max); /// max approve
    }

    /// @notice Claims liquidity mining rewards from Compound and performs low-lvl swap with instant reinvesting
    /// Calling harvest() claims COMP-Fork token through direct Pair swap for best control and lowest cost
    /// harvest() can be called by anybody. ideally this function should be adjusted per needs (e.g add fee for harvesting)
    function harvest() external returns (uint256 deposited) {
        ICERC20[] memory cTokens = new ICERC20[](1);
        cTokens[0] = cToken;
        // Sonne returns OP + SONNE
        // Note (?) Add minHarvest
        comptroller.claimComp(address(this), cTokens);

        if (reward.balanceOf(address(this)) < swapParams.minHarvest) {
            return 0;
        }

        // Need to divide by Chainlink answer 8 decimals after multiplying
        uint minOut = (_amountIn.mulDivUp(getLatestPrice(), 1e8))
        // yVault always has same decimals as its underlying
            .percentMul(1e4 - swapParams.slippage)
            .scaleBy(decimals(), reward.decimals());

        console.log("minOut: %s", minOut);

        uint256 earned = ERC20(reward).balanceOf(address(this));
        uint256 reinvestAmount;
        /// @dev Swap rewards to asset
        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: swapPath,
                recipient: address(this), // msg.sender,
                deadline: block.timestamp,
                amountIn: earned,
                amountOutMinimum: minAmountOut_
            });

        console.log("Executing swap");
        // Executes the swap.
        reinvestAmount = swapRouter.exactInput(params);
        if (reinvestAmount < minAmountOut_) {
            revert MIN_AMOUNT_ERROR();
        }
        console.log("Reinvest amount: %s", reinvestAmount);
        console.log("Executing after deposit operation");
        afterDeposit(asset.balanceOf(address(this)), 0);
        // Added for harvest to immediately take effect.
        accrueInterest();

        return (reinvestAmount);
    }

    /// @return answer with 8 decimals
    function getLatestPrice() public view returns (uint256 answer) {
        (, int _answer, , , ) = rewardPriceFeed.latestRoundData();

        console.logInt(_answer);

        answer = _answer.abs();

        console.log("Reward asset price ($): %s", answer);

        // I.e., if the want asset is not tied to USD (e.g., wETH).
        if (address(wantPriceFeed) != address(0)) {
            (, _answer, , , ) = wantPriceFeed.latestRoundData();

            console.logInt(_answer);

            // Scales to 18 but need to return answer in 8 decimals
            answer = answer.divPrecisely(_answer.abs()).scaleBy(8, 18);

            console.log("Reward asset price (want): %s", answer);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 OVERRIDES
    We can't inherit directly from Yield-daddy because of rewardClaim lock
    //////////////////////////////////////////////////////////////*/

    // Note may be slightly out of date as relies on "exchangeRateStored()"
    // (so as to not break ERC4626-compatibility).
    /// @dev Can be mitigated by calling "accrueInterest()" immediately prior.
    function totalAssets() public view virtual override returns (uint256) {
        return cToken.viewUnderlyingBalanceOf(address(this));
    }

    function beforeWithdraw(
        uint256 assets_,
        uint256 /*shares*/
    ) internal virtual override {
        uint256 errorCode = cToken.redeemUnderlying(assets_);
        if (errorCode != NO_ERROR) {
            revert COMPOUND_ERROR(errorCode);
        }
    }

    function afterDeposit(
        uint256 assets_,
        uint256 /*shares*/
    ) internal virtual override {
        // approve to cToken
        asset.safeApprove(address(cToken), assets_);
        // deposit into cToken
        uint256 errorCode = cToken.mint(assets_);
        if (errorCode != NO_ERROR) {
            revert COMPOUND_ERROR(errorCode);
        }
    }

    function maxDeposit(address) public view override returns (uint256) {
        if (comptroller.mintGuardianPaused(cToken)) return 0;
        return type(uint256).max;
    }

    function maxMint(address) public view override returns (uint256) {
        if (comptroller.mintGuardianPaused(cToken)) return 0;
        return type(uint256).max;
    }

    function maxWithdraw(address owner_)
        public
        view
        override
        returns (uint256)
    {
        uint256 cash = cToken.getCash();
        uint256 assetsBalance = convertToAssets(balanceOf[owner_]);
        return cash < assetsBalance ? cash : assetsBalance;
    }

    function maxRedeem(address owner_) public view override returns (uint256) {
        uint256 cash = cToken.getCash();
        uint256 cashInShares = convertToShares(cash);
        uint256 shareBalance = balanceOf[owner_];
        return cashInShares < shareBalance ? cashInShares : shareBalance;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 METADATA
    //////////////////////////////////////////////////////////////*/

    function _vaultName(ERC20 asset_)
        internal
        view
        virtual
        returns (string memory vaultName)
    {
        vaultName = string.concat("CompStratERC4626- ", asset_.symbol());
    }

    function _vaultSymbol(ERC20 asset_)
        internal
        view
        virtual
        returns (string memory vaultSymbol)
    {
        vaultSymbol = string.concat("cS-", asset_.symbol());
    }
}