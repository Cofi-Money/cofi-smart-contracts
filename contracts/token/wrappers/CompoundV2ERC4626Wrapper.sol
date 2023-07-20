// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { ERC20 } from "solmate/src/tokens/ERC20.sol";
import { ERC4626 } from "solmate/src/mixins/ERC4626.sol";
import { SafeTransferLib } from "solmate/src/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "solmate/src/utils/FixedPointMathLib.sol";
import { PercentageMath } from "./libs/PercentageMath.sol";
import { StableMath } from "./libs/StableMath.sol";
import { ICERC20 } from "./interfaces/ICERC20.sol";
import { LibCompound } from "./libs/LibCompound.sol";
import { IComptroller } from "./interfaces/IComptroller.sol";
import { ISwapRouter } from "./interfaces/ISwapRouter.sol";
import { DexSwap } from "./utils/swapUtils.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
            (Adapted from ZeroPoint Labs).
    @title  CompoundV2ERC4626Wrapper
    @notice Custom implementation of yield-daddy wrapper with flexible
            reinvesting logic.
    @dev    This is a passthrough wrapper and hence underlying assets reside
            in the respective protocol.
 */

contract CompoundV2ERC4626Wrapper is ERC4626, Ownable2Step, ReentrancyGuard {

    /*//////////////////////////////////////////////////////////////
                            LIBRARIES USAGE
    //////////////////////////////////////////////////////////////*/

    using LibCompound for ICERC20;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using PercentageMath for uint;
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
    /// @notice Thrown when swap path fee in reinvest is invalid.
    error INVALID_FEE_ERROR();
    error NOT_AUTHORIZED();
    error NOT_ADMIN();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant NO_ERROR = 0;

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLES & VARIABLES
    //////////////////////////////////////////////////////////////*/

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

    /* Swap params */
    struct SwapParams {
        uint256 amountInMin;
        uint256 slippage;
        uint256 wait;
        uint8   enabled;
    }

    SwapParams public swapParams;

    /*//////////////////////////////////////////////////////////////
                        CHAINLINK PRICE FEEDS
    //////////////////////////////////////////////////////////////*/

    // OP price feed
    AggregatorV3Interface public rewardPriceFeed =
        AggregatorV3Interface(0x0D276FC14719f9292D5C1eA2198673d1f4269246);

    AggregatorV3Interface public wantPriceFeed;

    /*//////////////////////////////////////////////////////////////
                                ACCESS
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint8) public authorized;
    uint8 public authorizedEnabled;

    mapping(address => uint8) public admin;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the CompoundV2ERC4626Wrapper.
    /// @param _asset       The address of the underlying asset.
    /// @param _reward      The address of the reward token.
    /// @param _cToken      The address of the cToken.
    /// @param _comptroller The address of the comptroller.
    /// @param _amountInMin The min amount of reward to execute swap for.
    /// @param _slippage    The max slippage incurred by swap (in basis points).
    /// @param _wait        The max wait time for swap execution (in seconds).
    constructor(
        ERC20        _asset,    // Underlying
        ERC20        _reward,   // COMP token or other
        ICERC20      _cToken,   // Compound concept of a share
        IComptroller _comptroller,
        AggregatorV3Interface _wantPriceFeed,
        address _authorized,
        uint256 _amountInMin,
        uint256 _slippage,
        uint256 _wait
    ) ERC4626(
        _asset,
        _vaultName(_asset),
        _vaultSymbol(_asset)
    ) {
        reward          = _reward;
        cToken          = _cToken;
        comptroller     = _comptroller;
        wantPriceFeed   = _wantPriceFeed;
        ICERC20[] memory cTokens = new ICERC20[](1);
        cTokens[0] = cToken;
        comptroller.enterMarkets(cTokens);
        swapParams.amountInMin  = _amountInMin;
        swapParams.slippage     = _slippage;
        swapParams.wait         = _wait;
        swapParams.enabled      = 1;
        admin[msg.sender]       = 1; // Also admin.
        authorized[_authorized] = 1;
        authorizedEnabled = 1;
    }

    /*//////////////////////////////////////////////////////////////
                            REWARDS
    //////////////////////////////////////////////////////////////*/

    /// @dev Updates value of "exchangeRateStored()"
    function accrueInterest() public onlyAuthorizedOrAdmin {
        cToken.accrueInterest();
    }

    /// @notice Sets the swap path for reinvesting rewards.
    ///
    /// @param _poolFee1    Fee for first swap.
    /// @param _tokenMid    Token for first swap.
    /// @param _poolFee2    Fee for second swap.
    function setRoute(
        uint24  _poolFee1,
        address _tokenMid,
        uint24  _poolFee2
    )   external onlyAdmin
    {
        if (_poolFee1 == 0) {
            revert INVALID_FEE_ERROR();
        }
        if (_poolFee2 == 0 || _tokenMid == address(0)) {
            swapPath = abi.encodePacked(reward, _poolFee1, address(asset));
        }
        else {
            swapPath = abi.encodePacked(
                reward,
                _poolFee1,
                _tokenMid, // Usually wETH.
                _poolFee2,
                address(asset)
            );
        }
        ERC20(reward).approve(address(swapRouter), type(uint256).max);
    }

    /// @dev Harvest operation accrues interest.
    function harvest() external onlyAuthorizedOrAdmin returns (uint256 deposited) {
        if (swapParams.enabled > 0) {
            console.log("Attempting to harvest with swap");
            return harvestWithSwap();
        } else {
            console.log("Attempting to harvest without swap");
            return flush();
        }
    }

    /// @notice Claims liquidity mining rewards from Compound and performs low-lvl swap
    ///         with instant reinvesting.
    function harvestWithSwap() internal returns (uint256 deposited) {
        ICERC20[] memory cTokens = new ICERC20[](1);
        cTokens[0] = cToken;
        // Sonne returns OP + SONNE.
        comptroller.claimComp(address(this), cTokens);

        uint256 amountIn = reward.balanceOf(address(this));

        // Check to see if we have enough reward assets for swap.
        if (amountIn < swapParams.amountInMin) {
            return 0;
        }

        // Need to divide by Chainlink answer 8 decimals after multiplying.
        uint256 amountOutMin = (amountIn.mulDivUp(getLatestPrice(), 1e8))
            .percentMul(1e4 - swapParams.slippage)
            .scaleBy(asset.decimals(), reward.decimals());

        console.log("amountOutMin: %s", amountOutMin);

        uint256 earned = ERC20(reward).balanceOf(address(this));

        // Swap rewards for want.
        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: swapPath,
                recipient: address(this), // Formerly msg.sender(), leaving for ref.
                deadline: block.timestamp + swapParams.wait,
                amountIn: earned,
                amountOutMinimum: amountOutMin // [want].
            });

        // Executes the swap.
        uint256 amountOut = swapRouter.exactInput(params);
        console.log("amountOut: %s", amountOut);
        if (amountOut < amountOutMin) {
            revert MIN_AMOUNT_ERROR();
        }
        // If want assets already resides at this address
        // prior to swap, deposited > amountOut.
        return flush();
    }

    /// @notice Deposits this contract's balance of want into venue.
    function flush() public onlyAuthorizedOrAdmin returns (uint256 deposited) {
        deposited = asset.balanceOf(address(this));
        // afterDeposit does not mint shares, therefore other shares worth more.
        afterDeposit(deposited, 0);
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

            // Scales to 18 but need to return answer in 8 decimals.
            answer = answer.divPrecisely(_answer.abs()).scaleBy(8, 18);

            console.log("Reward asset price (want): %s", answer);
        }
    }

    /// @notice Manually claim rewards.
    function claimRewards() external onlyAdmin {
        comptroller.claimComp(address(this));
    }

    /// @notice Useful for manual rewards reinvesting (executed by receiver).
    ///         where there is a lack of a trusted price feed.
    ///
    /// @param _token           The ERC20 token to recover.
    /// @param _claimRewards    Indicates whether to claim rewards in same tx.
    function recoverERC20(
        ERC20 _token,
        uint8 _claimRewards
    )   external onlyAdmin
    {
        if (_claimRewards == 1) {
            comptroller.claimComp(address(this));
        }
        _token.safeTransfer(msg.sender, _token.balanceOf(address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @param _amountInMin The min amount of reward asset to be exchanged.
    ///
    /// @dev An extremely small or large number can result in an undesiriable exchange rate.
    ///
    /// @param _amountInMin The min amount of reward assets to allow a swap for.
    function setAmountInMin(
        uint256 _amountInMin
    )   external onlyAdmin
        returns (bool)
    {
        swapParams.amountInMin = _amountInMin;
        return true;
    }

    /// @param _slippage The slippage tolerance in basis points.
    function setSlippage(
        uint256 _slippage
    )   external onlyAdmin
        returns (bool)
    {
        swapParams.slippage = _slippage;
        return true;
    }

    /// @param _wait The wait time for a swap to execute in seconds.
    function setWait(
        uint256 _wait
    )   external onlyAdmin
        returns (bool)
    {
        swapParams.wait = _wait;
        return true;
    }

    /// @notice Disables swap route for harvest operation.
    ///
    /// @param _enabled Indicates whether swapping is enabled.
    function setEnabled(
        uint8 _enabled
    )   external
        onlyAdmin
        returns (bool)
    {
        swapParams.enabled = _enabled;
        return true;
    }

    /// @param _account The account to amend admin status for.
    /// @param _enabled Whether the account has admin status.
    function setAdmin(
        address _account,
        uint8   _enabled
    )   external onlyOwner
        returns (bool)
    {
        require(
            _account != owner(),
            "CompoundV2ERC4626Wrapper: Cannot remove admin status of Owner"
        );
        admin[_account] = _enabled;
        return true;
    }

    /// @param _account The account to provide authorization for.
    /// @param _enabled Whether the account has authorization.
    function setAuthorized(
        address _account,
        uint8   _enabled
    )   external onlyOwner
        returns (bool)
    {
        authorized[_account] = _enabled;
        return true;
    }

    function setAuthorizedEnabled(
        uint8 _enabled
    )   external onlyOwner
        returns (bool)
    {
        authorizedEnabled = _enabled;
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 OVERRIDES
    We can't inherit directly from Yield-daddy because of rewardClaim lock
    //////////////////////////////////////////////////////////////*/

    function deposit(
        uint256 _assets,
        address _receiver
    )   public override nonReentrant onlyAuthorized
        returns (uint256 shares)
    {
        console.log("Entering deposit");
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(_assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), _assets);

        _mint(_receiver, shares);

        emit Deposit(msg.sender, _receiver, _assets, shares);

        afterDeposit(_assets, shares);
    }

    function mint(
        uint256 _shares,
        address _receiver
    )   public override nonReentrant onlyAuthorized
        returns (uint256 assets)
    {
         // No need to check for rounding error, previewMint rounds up.
        assets = previewMint(_shares);

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(_receiver, _shares);

        emit Deposit(msg.sender, _receiver, assets, _shares);

        afterDeposit(assets, _shares);
    }

    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner
    )   public override nonReentrant onlyAuthorized
        returns (uint256 shares)
    {
         // No need to check for rounding error, previewMint rounds up.
        shares = previewWithdraw(_assets);

        if (msg.sender != _owner) {
            uint256 allowed = allowance[_owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[_owner][msg.sender] = allowed - shares;
        }

        beforeWithdraw(_assets, shares);

        _burn(_owner, shares);

        emit Withdraw(msg.sender, _receiver, _owner, _assets, shares);

        asset.safeTransfer(_receiver, _assets);
    }

    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    )   public override nonReentrant onlyAuthorized
        returns (uint256 assets)
    {
        if (msg.sender != _owner) {
            uint256 allowed = allowance[_owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[_owner][msg.sender] = allowed - _shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(_shares)) != 0, "ZERO_ASSETS");

        beforeWithdraw(assets, _shares);

        _burn(_owner, _shares);

        emit Withdraw(msg.sender, _receiver, _owner, assets, _shares);

        asset.safeTransfer(_receiver, assets);
    }

    /// @dev    May be slightly out of date as relies on "exchangeRateStored()"
    //          (so as to not break ERC4626-compatibility). Can be mitigated by
    ///         calling "accrueInterest()" immediately prior.
    function totalAssets() public view virtual override returns (uint256) {
        return cToken.viewUnderlyingBalanceOf(address(this));
    }

    function beforeWithdraw(
        uint256 _assets,
        uint256 /*shares*/
    )   internal virtual override
    {
        uint256 errorCode = cToken.redeemUnderlying(_assets);
        if (errorCode != NO_ERROR) {
            revert COMPOUND_ERROR(errorCode);
        }
    }

    function afterDeposit(
        uint256 _assets,
        uint256 /*shares*/
    )   internal virtual override
    {
        // Approve to cToken
        asset.safeApprove(address(cToken), _assets);
        // Deposit into cToken
        uint256 errorCode = cToken.mint(_assets);
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

    function maxWithdraw(
        address _owner
    )   public view override
        returns (uint256)
    {
        uint256 cash = cToken.getCash();
        uint256 assetsBalance = convertToAssets(balanceOf[_owner]);
        return cash < assetsBalance ? cash : assetsBalance;
    }

    function maxRedeem(
        address _owner
    )   public view override returns (uint256)
    {
        uint256 cash = cToken.getCash();
        uint256 cashInShares = convertToShares(cash);
        uint256 shareBalance = balanceOf[_owner];
        return cashInShares < shareBalance ? cashInShares : shareBalance;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 METADATA
    //////////////////////////////////////////////////////////////*/

    function _vaultName(
        ERC20 _asset
    )   internal view virtual
        returns (string memory vaultName)
    {
        vaultName = string.concat("COFI Wrapped ", _asset.symbol());
    }

    function _vaultSymbol(
        ERC20 _asset
    )   internal view virtual
        returns (string memory vaultSymbol)
    {
        vaultSymbol = string.concat("cw", _asset.symbol());
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin() {
        if (msg.sender != owner() || admin[msg.sender] < 1) {
            console.log("Not admin");
            revert NOT_ADMIN();
        }
        _;
    }

    /// @dev Add to prevent state change outside of app context
    modifier onlyAuthorized() {
        if (authorizedEnabled > 0) {
            if (authorized[msg.sender] < 1) {
                console.log("Not authorized");
                revert NOT_AUTHORIZED();
            }
        }
        _;
    }

    modifier onlyAuthorizedOrAdmin() {
        if (authorizedEnabled > 0) {
            if (authorized[msg.sender] < 1) {
                console.log("Not authorized");
                revert NOT_AUTHORIZED();
            }
        }
        if (msg.sender != owner() || admin[msg.sender] < 1) {
            console.log("Not admin");
            revert NOT_ADMIN();
        }
        _;
    }
}