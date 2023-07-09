// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author The Stoa Corporation Ltd. (Adapted from RobAnon, 0xTraub, 0xTinder).
    @title  Yearn Zap Reinvest Wrapper
    @notice Provides 4626-compatibility and functions for reinvesting
            staking rewards.
 */

import "./interfaces/IVaultWrapper.sol";
import "./interfaces/IStakingRewardsZap.sol";
import "./interfaces/IStakingRewards.sol";
import {VaultAPI, IYearnRegistry} from "./interfaces/VaultAPI.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {FixedPointMathLib} from "./lib/FixedPointMathLib.sol";
import {PercentageMath} from "./lib/PercentageMath.sol";
import {StableMath} from "./lib/StableMath.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "hardhat/console.sol";

contract YearnZapReinvestWrapper is
    ERC4626,
    IVaultWrapper,
    Ownable2Step,
    ReentrancyGuard
{
    using FixedPointMathLib for uint;
    using PercentageMath for uint;
    using StableMath for uint;
    using StableMath for int;
    using SafeERC20 for IERC20;

    IYearnRegistry public registry =
        IYearnRegistry(0x79286Dd38C9017E5423073bAc11F53357Fc5C128);

    VaultAPI public yVault;

    VaultAPI public yVaultReward; // yvOP

    IStakingRewards public stakingRewards;

    IStakingRewardsZap public stakingRewardsZap =
        IStakingRewardsZap(0x498d9dCBB1708e135bdc76Ef007f08CBa4477BE2);

    AggregatorV3Interface public rewardPriceFeed =
        AggregatorV3Interface(0x0D276FC14719f9292D5C1eA2198673d1f4269246);

    AggregatorV3Interface public basePriceFeed;

    ISwapRouter public swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    mapping(address => uint8) authorized;

    uint256 private constant MIN_DEPOSIT = 1e3;

    /* Swap params */
    struct SwapParams {
        uint256 minHarvest;
        uint256 slippage;
        uint256 wait;
        uint24 poolFee;
        uint8 enabled;
    }

    SwapParams private swapParams;

    event Harvest(uint256 rewardAssets, uint256 deposited, uint256 yearnShares);
    // Visibility of emission not obvious (?)
    event HarvestAttempted(
        uint256 rewardShares,
        uint256 rewardAssets,
        uint256 minHarvest
    );
    event HarvestIsDisabled();

    constructor(
        VaultAPI _vault,
        // VaultAPI _rewardVault,
        // IStakingRewards _stakingRewards,
        // AggregatorV3Interface _basePriceFeed,
        address _underlying
        // uint256 _minHarvest,
        // uint256 _slippage,
        // uint256 _wait,
        // uint24 _poolFee,
        // uint8 _enabled
    )
        ERC20(
            string(
                abi.encodePacked("Wrapped ", _vault.name(), "-Reinvest4626")
            ),
            string(abi.encodePacked("w", _vault.symbol(), "-R4626"))
        )
        ERC4626(
            IERC20(_underlying) // OZ contract retrieves decimals from asset
        )
    {
        // yVault = _vault;
        // yVaultReward = _rewardVault;
        // stakingRewards = _stakingRewards;
        // basePriceFeed = _basePriceFeed;
        // swapParams.minHarvest = 1000000000000000000;
        // swapParams.slippage = 200;
        // swapParams.wait = 12;
        // swapParams.poolFee = 3000;
        // swapParams.enabled = 1;
        // authorized[msg.sender] = 1;
    }

    function vault() external view returns (address) {
        return address(yVault);
    }

    // Note this number will be different from this token's totalSupply
    function vaultTotalSupply() external view returns (uint256) {
        return yVault.totalSupply();
    }

    /*//////////////////////////////////////////////////////////////
                    STAKING REWARDS REINVEST LOGIC
    //////////////////////////////////////////////////////////////*/

    function harvest()
        public
        onlyAuthorized
        returns (uint256 deposited, uint256 yearnShares)
    {
        if (swapParams.enabled != 1) {
            emit HarvestIsDisabled();
            return (0, 0);
        }

        if (
            convertYearnRewardSharesToAssets(
                stakingRewards.earned(address(this))
            ) > swapParams.minHarvest
        ) {
            // Obtain yvOP from StakingRewards contract.
            stakingRewards.getReward();
            // Redeem yvOP for OP.
            _doRewardWithdrawal(
                IERC20(yVaultReward).balanceOf(address(this)),
                yVaultReward
            );
        }

        uint256 rewardAssets = IERC20(yVaultReward.token()).balanceOf(
            address(this)
        );

        /// @dev Can trigger harvest by transferring OP.
        if (rewardAssets > swapParams.minHarvest) {
            // Swap for want
            uint256 amountOut = swapExactInputSingle(rewardAssets);
            // Deposit to yVault
            (deposited, yearnShares) = _doRewardDeposit(amountOut);
            emit Harvest(rewardAssets, deposited, yearnShares);
        }
    }

    function swapExactInputSingle(
        uint256 _amountIn
    ) internal returns (uint256 amountOut) {
        address tokenIn = yVaultReward.token();

        IERC20(tokenIn).approve(address(swapRouter), _amountIn);

        // Need to divide by Chainlink answer 8 decimals after multiplying
        uint minOut = (_amountIn.mulDivUp(getLatestPrice(), 1e8))
        // yVault always has same decimals as its underlying
            .percentMul(1e4 - swapParams.slippage)
            .scaleBy(decimals(), yVaultReward.decimals());

        console.log("minOut: %s", minOut);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: asset(),
                fee: swapParams.poolFee,
                recipient: address(this),
                deadline: block.timestamp + swapParams.wait,
                amountIn: _amountIn,
                amountOutMinimum: minOut,
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter.exactInputSingle(params);

        console.log("amountOut: %s", amountOut);
    }

    /// @return answer with 8 decimals
    function getLatestPrice() public view returns (uint256 answer) {
        (, int _answer, , , ) = rewardPriceFeed.latestRoundData();

        console.logInt(_answer);

        answer = _answer.abs();

        console.log("Reward asset price ($): %s", answer);

        // I.e., if the want asset is not USD.
        if (address(basePriceFeed) != address(0)) {
            (, _answer, , , ) = basePriceFeed.latestRoundData();

            console.logInt(_answer);

            // Scales to 18 but need to return answer in 8 decimals
            answer = answer.divPrecisely(_answer.abs()).scaleBy(8, 18);

            console.log("Want asset price ($): %s", answer);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Extremely small Uniswap trades can incur high slippage, hence important to set this
    function setMinHarvest(
        uint256 _minHarvest
    ) external onlyOwner returns (bool) {
        swapParams.minHarvest = _minHarvest;
        return true;
    }

    function setSlippage(uint256 _slippage) external onlyOwner returns (bool) {
        swapParams.slippage = _slippage;
        return true;
    }

    function setWait(uint256 _wait) external onlyOwner returns (bool) {
        swapParams.wait = _wait;
        return true;
    }

    function setPoolFee(uint24 _poolFee) external onlyOwner returns (bool) {
        swapParams.poolFee = _poolFee;
        return true;
    }

    function setEnabled(uint8 _enabled) external onlyOwner returns (bool) {
        swapParams.enabled = _enabled;
        return true;
    }

    function toggleAuthorized(
        address account
    ) external onlyOwner returns (bool) {
        require(
            account != owner(),
            "YearnZapReinvestWrapper: Cannot remove authorisation of Owner"
        );
        authorized[account] == 0
            ? authorized[account] = 1
            : authorized[account] = 0;
        return authorized[account] == 1 ? true : false;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(
        uint256 assets,
        address receiver
    ) public override nonReentrant returns (uint256 shares) {
        // Harvest to ensure depositor does not earn others rewards
        if (stakingRewards.balanceOf(address(this)) > 0) {
            harvest();
        }

        if (assets < MIN_DEPOSIT) {
            revert MinimumDepositNotMet();
        }

        (assets, shares) = _deposit(assets, receiver, msg.sender);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(
        uint256 shares,
        address receiver
    ) public override nonReentrant returns (uint256 assets) {
        // Harvest to ensure depositor does not earn others rewards
        if (stakingRewards.balanceOf(address(this)) > 0) {
            harvest();
        }

        // No need to check for rounding error, previewMint rounds up.
        assets = previewMint(shares);

        uint expectedShares = shares;
        (assets, shares) = _deposit(assets, receiver, msg.sender);

        if (assets < MIN_DEPOSIT) {
            revert MinimumDepositNotMet();
        }

        if (shares != expectedShares) {
            revert NotEnoughAvailableAssetsForAmount();
        }

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address _owner
    ) public override nonReentrant returns (uint256 shares) {
        // Harvest to ensure withdrawer gets their due rewards
        if (stakingRewards.balanceOf(address(this)) > 0) {
            harvest();
        }

        if (assets == 0) {
            revert NonZeroArgumentExpected();
        }

        (assets, shares) = _withdraw(assets, receiver, _owner);

        emit Withdraw(msg.sender, receiver, _owner, assets, shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address _owner
    ) public override nonReentrant returns (uint256 assets) {
        // Harvest to ensure withdrawer gets their due rewards
        if (stakingRewards.balanceOf(address(this)) > 0) {
            harvest();
        }

        if (shares == 0) {
            revert NonZeroArgumentExpected();
        }

        (assets, shares) = _redeem(shares, receiver, _owner);

        emit Withdraw(msg.sender, receiver, _owner, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view override returns (uint256) {
        return yVault.availableDepositLimit();
    }

    function maxMint(address _account) public view override returns (uint256) {
        return maxDeposit(_account) / yVault.pricePerShare();
    }

    function maxWithdraw(
        address _owner
    ) public view override returns (uint256) {
        return convertToAssets(this.balanceOf(_owner));
    }

    function maxRedeem(address _owner) public view override returns (uint256) {
        return this.balanceOf(_owner);
    }

    function _deposit(
        uint256 amount,
        address receiver,
        address depositor
    ) internal returns (uint256 deposited, uint256 mintedShares) {
        IERC20 _token = IERC20(asset());

        if (amount == type(uint256).max) {
            amount = Math.min(
                _token.balanceOf(depositor),
                _token.allowance(depositor, address(this))
            );
        }

        SafeERC20.safeTransferFrom(_token, depositor, address(this), amount);

        SafeERC20.safeApprove(_token, address(stakingRewardsZap), amount);

        uint256 beforeBal = _token.balanceOf(address(this));

        mintedShares = stakingRewardsZap.zapIn(address(yVault), amount);

        uint256 afterBal = _token.balanceOf(address(this));
        deposited = beforeBal - afterBal;

        // afterDeposit custom logic
        _mint(receiver, mintedShares);
    }

    /// @notice Deposit want obtained from reward (e.g., USDC received from swapping OP).
    function _doRewardDeposit(
        uint256 amount
    ) internal returns (uint256 deposited, uint256 mintedShares) {
        IERC20 _token = IERC20(asset());

        SafeERC20.safeApprove(_token, address(stakingRewardsZap), amount);

        uint256 beforeBal = _token.balanceOf(address(this));

        // Returns 'toStake'
        mintedShares = stakingRewardsZap.zapIn(address(yVault), amount);

        uint256 afterBal = _token.balanceOf(address(this));
        deposited = beforeBal - afterBal;
    }

    function _withdraw(
        uint256 amount,
        address receiver,
        address sender
    ) internal returns (uint256 assets, uint256 shares) {
        VaultAPI _vault = yVault;

        shares = previewWithdraw(amount);
        uint yearnShares = convertAssetsToYearnShares(amount);

        assets = _doWithdrawal(shares, yearnShares, sender, receiver, _vault);

        if (assets < amount) {
            revert NotEnoughAvailableSharesForAmount();
        }
    }

    function _redeem(
        uint256 shares,
        address receiver,
        address sender
    ) internal returns (uint256 assets, uint256 sharesBurnt) {
        VaultAPI _vault = yVault;
        uint yearnShares = convertSharesToYearnShares(shares);
        assets = _doWithdrawal(shares, yearnShares, sender, receiver, _vault);
        sharesBurnt = shares;
    }

    function _doWithdrawal(
        uint shares,
        uint yearnShares,
        address sender,
        address receiver,
        VaultAPI _vault
    ) private returns (uint assets) {
        if (sender != msg.sender) {
            uint currentAllowance = allowance(sender, msg.sender);
            if (currentAllowance < shares) {
                revert SpenderDoesNotHaveApprovalToBurnShares();
            }
            _approve(sender, msg.sender, currentAllowance - shares);
        }

        if (shares > balanceOf(sender)) {
            revert NotEnoughAvailableSharesForAmount();
        }

        if (yearnShares == 0 || shares == 0) {
            revert NoAvailableShares();
        }

        _burn(sender, shares);

        // withdraw from staking pool (yearn shares only, not rewards)
        stakingRewards.withdraw(yearnShares);

        // withdraw from vault and get total used shares
        assets = _vault.withdraw(yearnShares, receiver, 0);
    }

    function _doRewardWithdrawal(
        uint yearnShares,
        VaultAPI _vault
    ) private returns (uint assets) {
        if (yearnShares == 0) {
            revert NoAvailableShares();
        }

        // Withdraw OP from yvOP vault
        assets = _vault.withdraw(yearnShares, address(this), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view override returns (uint256) {
        // This contract is a passthrough wrapper. Assets are held in the respective staking contract.
        return
            convertYearnSharesToAssets(stakingRewards.balanceOf(address(this)));
    }

    function convertToShares(
        uint256 assets
    ) public view override returns (uint256) {
        uint supply = totalSupply(); // Total supply of wyvTokens

        // yvTokens held in staking contract
        uint localAssets = convertYearnSharesToAssets(
            stakingRewards.balanceOf(address(this))
        );
        return supply == 0 ? assets : assets.mulDivDown(supply, localAssets);
    }

    function convertToAssets(
        uint256 shares
    ) public view override returns (uint assets) {
        uint supply = totalSupply();

        uint localAssets = convertYearnSharesToAssets(
            // Shares held in staking contract
            stakingRewards.balanceOf(address(this))
        );
        console.log("local assets: %s", localAssets);

        return supply == 0 ? shares : shares.mulDivDown(localAssets, supply);
    }

    // Added function for reward conversion
    function convertToRewardAssets(
        uint256 shares
    ) public view returns (uint assets) {
        uint supply = totalSupply();
        uint localAssets = convertYearnSharesToAssets(
            // Pending rewards
            stakingRewards.earned(address(this))
        );
        return supply == 0 ? shares : shares.mulDivDown(localAssets, supply);
    }

    function getFreeFunds() public view virtual returns (uint256) {
        uint256 lockedFundsRatio = (block.timestamp - yVault.lastReport()) *
            yVault.lockedProfitDegradation();
        uint256 _lockedProfit = yVault.lockedProfit();

        uint256 DEGRADATION_COEFFICIENT = 10 ** 18;
        uint256 lockedProfit = lockedFundsRatio < DEGRADATION_COEFFICIENT
            ? _lockedProfit -
                ((lockedFundsRatio * _lockedProfit) / DEGRADATION_COEFFICIENT)
            : 0; // hardcoded DEGRADATION_COEFFICIENT
        return yVault.totalAssets() - lockedProfit;
    }

    // Added function for reward conversion
    function getFreeRewardFunds() public view virtual returns (uint256) {
        uint256 lockedFundsRatio = (block.timestamp -
            yVaultReward.lastReport()) * yVaultReward.lockedProfitDegradation();
        uint256 _lockedProfit = yVaultReward.lockedProfit();

        uint256 DEGRADATION_COEFFICIENT = 10 ** 18;
        uint256 lockedProfit = lockedFundsRatio < DEGRADATION_COEFFICIENT
            ? _lockedProfit -
                ((lockedFundsRatio * _lockedProfit) / DEGRADATION_COEFFICIENT)
            : 0; // hardcoded DEGRADATION_COEFFICIENT
        return yVaultReward.totalAssets() - lockedProfit;
    }

    function previewDeposit(
        uint256 assets
    ) public view override returns (uint256) {
        return convertToShares(assets);
    }

    function previewWithdraw(
        uint256 assets
    ) public view override returns (uint256) {
        uint supply = totalSupply();
        uint localAssets = convertYearnSharesToAssets(
            stakingRewards.balanceOf(address(this))
        );
        return supply == 0 ? assets : assets.mulDivUp(supply, localAssets);
    }

    function previewMint(
        uint256 shares
    ) public view override returns (uint256) {
        uint supply = totalSupply();
        uint localAssets = convertYearnSharesToAssets(
            stakingRewards.balanceOf(address(this))
        );
        return supply == 0 ? shares : shares.mulDivUp(localAssets, supply);
    }

    function previewRedeem(
        uint256 shares
    ) public view override returns (uint256) {
        return convertToAssets(shares);
    }

    // Only concerned about redeem op for rewards reinvesting
    function previewRedeemReward(uint256 shares) public view returns (uint256) {
        return convertToRewardAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function convertAssetsToYearnShares(
        uint assets
    ) internal view returns (uint yShares) {
        uint256 supply = yVault.totalSupply();
        return supply == 0 ? assets : assets.mulDivUp(supply, getFreeFunds());
    }

    /// @dev yvTokens held in staking rewards contract
    function convertYearnSharesToAssets(
        uint yearnShares
    ) internal view returns (uint assets) {
        uint supply = yVault.totalSupply();
        return
            supply == 0 ? yearnShares : (yearnShares * getFreeFunds()) / supply;
    }

    /// @dev Added function for rewards
    function convertYearnRewardSharesToAssets(
        uint yearnShares
    ) internal view returns (uint assets) {
        uint supply = yVaultReward.totalSupply();
        return
            supply == 0
                ? yearnShares
                : (yearnShares * getFreeRewardFunds()) / supply;
    }

    function convertSharesToYearnShares(
        uint shares
    ) internal view returns (uint yShares) {
        uint supply = totalSupply();
        return
            supply == 0
                ? shares
                : shares.mulDivUp(
                    stakingRewards.balanceOf(address(this)),
                    totalSupply()
                );
    }

    function allowance(
        address _owner,
        address spender
    ) public view virtual override(ERC20, IERC20) returns (uint256) {
        return super.allowance(_owner, spender);
    }

    function balanceOf(
        address account
    ) public view virtual override(ERC20, IERC20) returns (uint256) {
        return super.balanceOf(account);
    }

    function name()
        public
        view
        virtual
        override(ERC20, IERC20Metadata)
        returns (string memory)
    {
        return super.name();
    }

    function symbol()
        public
        view
        virtual
        override(ERC20, IERC20Metadata)
        returns (string memory)
    {
        return super.symbol();
    }

    function totalSupply()
        public
        view
        virtual
        override(ERC20, IERC20)
        returns (uint256)
    {
        return super.totalSupply();
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Add to prevent state change outside of app context
    modifier onlyAuthorized() {
        require(
            authorized[msg.sender] == 1,
            "YearnZapReinvestWrapper: Caller not authorized"
        );
        _;
    }
}
