// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './interfaces/yearn/IVaultWrapper.sol';
import './interfaces/yearn/IStakingRewardsZap.sol';
import './interfaces/yearn/IStakingRewards.sol';
import { VaultAPI, IYearnRegistry } from './interfaces/yearn/VaultAPI.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';
import { FixedPointMathLib } from './libs/FixedPointMathLib.sol';
import { PercentageMath } from './libs/PercentageMath.sol';
import { StableMath } from './libs/StableMath.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import 'hardhat/console.sol';

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author The Stoa Corporation Ltd. (Adapted from RobAnon, 0xTraub, 0xTinder).
    @title  YearnV2StakingRewards
    @notice Provides 4626-compatibility and functions for reinvesting
            staking rewards.
    @dev    This is a passthrough wrapper and hence underlying assets reside
            in the respective protocol.
 */

contract YearnV2StakingRewards is ERC4626, IVaultWrapper, Ownable2Step, ReentrancyGuard {

    /*//////////////////////////////////////////////////////////////
                            LIBRARIES USAGE
    //////////////////////////////////////////////////////////////*/

    using FixedPointMathLib for uint256;
    using PercentageMath for uint256;
    using StableMath for uint256;
    using StableMath for int256;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        YEARN FINANCE INTEGRATION
    //////////////////////////////////////////////////////////////*/

    IYearnRegistry public registry =
        IYearnRegistry(0x79286Dd38C9017E5423073bAc11F53357Fc5C128);

    VaultAPI public yVault;

    VaultAPI public yVaultReward; // yvOP

    IStakingRewards public stakingRewards;

    IStakingRewardsZap public stakingRewardsZap =
        IStakingRewardsZap(0x498d9dCBB1708e135bdc76Ef007f08CBa4477BE2);

    /*//////////////////////////////////////////////////////////////
                        CHAINLINK PRICE FEEDS
    //////////////////////////////////////////////////////////////*/

    AggregatorV3Interface public rewardPriceFeed =
        AggregatorV3Interface(0x0D276FC14719f9292D5C1eA2198673d1f4269246);

    AggregatorV3Interface public wantPriceFeed;

    /*//////////////////////////////////////////////////////////////
                        SWAP & DEPOSIT PARAMS
    //////////////////////////////////////////////////////////////*/

    ISwapRouter public swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    uint8 preemptiveHarvestEnabled;

    uint256 private constant MIN_DEPOSIT = 1e3;

    /* Swap params */
    struct SwapParams {
        // As yvOP is accumulating rewards, do not want to claim without reinvesting immediately.
        uint256 getRewardMin;
        uint256 amountInMin; // The min amount of reward to execute a swap for.
        uint256 slippage;
        uint256 wait;
        uint24  poolFee;
        uint8   enabled;
    }

    SwapParams public swapParams;

    /*//////////////////////////////////////////////////////////////
                                ACCESS
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint8) public authorized;
    uint8 public authorizedEnabled;

    mapping(address => uint8) public admin;

    address public rewardShareReceiver;

    /// @dev Ensure to set 'rewardShareReceiver' after deploying.
    constructor(
        VaultAPI _vault,
        VaultAPI _rewardVault,
        IStakingRewards _stakingRewards,
        AggregatorV3Interface _wantPriceFeed,
        uint256 _getRewardMin,
        uint256 _amountInMin,
        uint256 _slippage,
        uint256 _wait,
        uint24  _poolFee,
        uint8   _enabled
    )
        ERC20(
            string(abi.encodePacked('COFI Wrapped ', _vault.name())),
            string(abi.encodePacked('cw', _vault.symbol()))
        )
        ERC4626(
            IERC20(_vault.token()) // OZ contract retrieves decimals from asset
        )
    {
        yVault          = _vault;
        yVaultReward    = _rewardVault;
        stakingRewards  = _stakingRewards;
        wantPriceFeed   = _wantPriceFeed;
        swapParams.getRewardMin = _getRewardMin;
        swapParams.amountInMin  = _amountInMin;
        swapParams.slippage     = _slippage;
        swapParams.wait         = _wait;
        swapParams.poolFee      = _poolFee;
        swapParams.enabled      = _enabled;
        admin[msg.sender]       = 1;
        authorizedEnabled = 1;
    }

    function vault() external view returns (address) {
        return address(yVault);
    }

    /// @dev This number will be different from this token's totalSupply.
    function vaultTotalSupply() external view returns (uint256) {
        return yVault.totalSupply();
    }

    /*//////////////////////////////////////////////////////////////
                    STAKING REWARDS REINVEST LOGIC
    //////////////////////////////////////////////////////////////*/

    function harvest() public onlyAuthorized returns (uint256 deposited) {
        console.log('Entering harvest');
        return swapParams.enabled == 1 ?
            harvestWithSwap() :
            flush();
    }

    function harvestWithSwap() internal returns (uint256 deposited) {
        console.log('Entering harvest with swap');
        if (
            convertYearnRewardSharesToAssets(
                stakingRewards.earned(address(this))
            ) > swapParams.getRewardMin
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
        console.log('Attempting to swap');
        /// @dev Can trigger harvest by transferring OP.
        if (rewardAssets > swapParams.amountInMin) {
            // Swap for want
            swapExactInputSingle(rewardAssets);
        }
        console.log('Attempting to flush');
        // Deposit to yVault
        return flush();
    }

    /// @param _amountIn The amount of reward asset to swap for want.
    function swapExactInputSingle(
        uint256 _amountIn
    )   internal
        returns (uint256 amountOut)
    {
        address tokenIn = yVaultReward.token();

        IERC20(tokenIn).approve(address(swapRouter), _amountIn);

        // Need to divide by Chainlink answer 8 decimals after multiplying
        uint256 amountOutMin = (_amountIn.mulDivUp(getLatestPrice(), 1e8))
        // yVault always has same decimals as its underlying
            .percentMul(1e4 - swapParams.slippage)
            .scaleBy(decimals(), yVaultReward.decimals());
        console.log('amountOutMin: %s', amountOutMin);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: asset(),
                fee: swapParams.poolFee,
                recipient: address(this),
                deadline: block.timestamp + swapParams.wait,
                amountIn: _amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter.exactInputSingle(params);
        console.log('amountOut: %s', amountOut);
    }

    /// @return answer with 8 decimals
    function getLatestPrice() public view returns (uint256 answer) {
        (uint80 _roundID, int256 _answer, , uint256 _timestamp, uint80 _answeredInRound)
            = rewardPriceFeed.latestRoundData();

        require(_answeredInRound >= _roundID, 'YearnV2ERC4626Reinvest: Stale price');
        require(_timestamp != 0,'YearnV2ERC4626Reinvest: Round not complete');
        require(_answer > 0,'YearnV2ERC4626Reinvest: Chainlink answer reporting 0');

        answer = _answer.abs();

        // I.e., if the want asset is not tied to USD (e.g., wETH).
        if (address(wantPriceFeed) != address(0)) {
            (, _answer, , , ) = wantPriceFeed.latestRoundData();

            // Scales to 18 but need to return answer in 8 decimals.
            answer = answer.divPrecisely(_answer.abs()).scaleBy(8, 18);
        }
    }

    /// @notice Manually claim rewards.
    function claimRewards() external onlyAdmin {
        stakingRewards.getReward();
    }

    /// @notice Useful for manual rewards reinvesting (executed by receiver).
    ///         where there is a lack of a trusted price feed.
    ///
    /// @param _token           The ERC20 token to recover.
    /// @param _claimRewards    Whether to claim rewards in same tx.
    function recoverERC20(
        IERC20 _token,
        uint8  _claimRewards
    )   external onlyAdmin
    {
        if (_claimRewards == 1) {
            stakingRewards.getReward();
        }
        _token.safeTransfer(msg.sender, _token.balanceOf(address(this)));
    }

    /// @notice Deposits this contract's balance of want into venue.
    /// @dev    Need to mint reward shares to receiver (in COFI's conetxt, the diamond contract).
    ///         This ensures yield from rewards is reflected in the rebasing token rather than shares.
    function flush() public onlyAdmin returns (uint256 deposited) {
        console.log('Entering flush');
        console.log('Want bal: %s', IERC20(asset()).balanceOf(address(this)));
        if (IERC20(asset()).balanceOf(address(this)) > 0) {
            (deposited, ) = _doRewardDeposit(
                IERC20(asset()).balanceOf(address(this)), rewardShareReceiver
            );
        } else return 0;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @param _getRewardMin The minimum amount of rewards to claim from the staking contract.
    function setGetRewardMin(
        uint256 _getRewardMin
    )   external onlyAdmin
        returns (bool)
    {
        swapParams.getRewardMin = _getRewardMin;
        return true;
    }

    /// @dev Extremely small Uniswap trades can incur high slippage, hence important to set this
    ///
    /// @param _amountInMin The minimum amount of reward assets to initiate a swap.
    function setAmountInMin(
        uint256 _amountInMin
    )   external onlyAdmin
        returns (bool)
    {
        swapParams.amountInMin = _amountInMin;
        return true;
    }

    /// @param _slippage The maximum amount of slippage a swap can incur (in basis points).
    function setSlippage(
        uint256 _slippage
    )   external onlyAdmin
        returns (bool)
    {
        swapParams.slippage = _slippage;
        return true;
    }

    /// @param _wait The maximum wait time for a swap to execute (in seconds).
    function setWait(
        uint256 _wait
    )   external onlyAdmin
        returns (bool)
    {
        swapParams.wait = _wait;
        return true;
    }

    /// @param _poolFee Identifier for the Uniswap pool to exchange through.
    function setPoolFee(
        uint24 _poolFee
    )   external onlyAdmin
        returns (bool)
    {
        swapParams.poolFee = _poolFee;
        return true;
    }

    /// @param _enabled Indicates whether swapping is enabled.
    function setEnabled(
        uint8 _enabled
    )   external onlyAdmin
        returns (bool)
    {
        swapParams.enabled = _enabled;
        return true;
    }

    /// @param _enabled Indicates whether to preemptively harves given the relevant function call.
    function setPreemptiveHarvest(
        uint8 _enabled
    )   external onlyAdmin
        returns (bool)
    {
        preemptiveHarvestEnabled = _enabled;
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
            'YearnV2ERC4626Wrapper: Cannot remove admin status of Owner'
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

    /**
     * @notice  The rewardShareReceiver should be tha account owning share tokens.
     *          "reward shares" are shares received by investing wants received from rewards
     *          into the vault (e.g., yvUSDC).
     */
    function setRewardShareReceiver(
        address _account
    )   external onlyOwner
        returns (bool)
    {
        rewardShareReceiver = _account;
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(
        uint256 _assets,
        address _receiver
    )   public override nonReentrant onlyAuthorized preemptivelyHarvest
        returns (uint256 shares)
    {
        if (_assets < MIN_DEPOSIT) {
            revert MinimumDepositNotMet();
        }
        (_assets, shares) = _deposit(_assets, _receiver, msg.sender);

        emit Deposit(msg.sender, _receiver, _assets, shares);
    }

    function mint(
        uint256 _shares,
        address _receiver
    )   public override nonReentrant onlyAuthorized preemptivelyHarvest
        returns (uint256 assets)
    {
        // No need to check for rounding error, previewMint rounds up.
        assets = previewMint(_shares);

        uint256 expectedShares = _shares;
        (assets, _shares) = _deposit(assets, _receiver, msg.sender);

        if (assets < MIN_DEPOSIT) {
            revert MinimumDepositNotMet();
        }

        if (_shares != expectedShares) {
            revert NotEnoughAvailableAssetsForAmount();
        }

        emit Deposit(msg.sender, _receiver, assets, _shares);
    }

    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner
    )   public override nonReentrant onlyAuthorized preemptivelyHarvest
        returns (uint256 shares)
    {
        if (_assets == 0) {
            revert NonZeroArgumentExpected();
        }

        (_assets, shares) = _withdraw(_assets, _receiver, _owner);

        emit Withdraw(msg.sender, _receiver, _owner, _assets, shares);
    }

    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    )   public override nonReentrant onlyAuthorized preemptivelyHarvest
        returns (uint256 assets)
    {
        if (_shares == 0) {
            revert NonZeroArgumentExpected();
        }

        (assets, _shares) = _redeem(_shares, _receiver, _owner);

        emit Withdraw(msg.sender, _receiver, _owner, assets, _shares);
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
        uint256 _amount,
        address _receiver,
        address _depositor
    ) internal returns (uint256 deposited, uint256 mintedShares) {
        IERC20 _token = IERC20(asset());

        if (_amount == type(uint256).max) {
            _amount = Math.min(
                _token.balanceOf(_depositor),
                _token.allowance(_depositor, address(this))
            );
        }

        SafeERC20.safeTransferFrom(_token, _depositor, address(this), _amount);

        SafeERC20.safeApprove(_token, address(stakingRewardsZap), _amount);

        uint256 beforeBal = _token.balanceOf(address(this));

        mintedShares = stakingRewardsZap.zapIn(address(yVault), _amount);

        uint256 afterBal = _token.balanceOf(address(this));
        deposited = beforeBal - afterBal;

        // afterDeposit custom logic
        _mint(_receiver, mintedShares);
    }

    /// @notice Deposit want obtained from reward (e.g., USDC received from swapping OP).
    function _doRewardDeposit(
        uint256 _amount,
        address _receiver
    ) internal returns (uint256 deposited, uint256 mintedShares) {
        IERC20 _token = IERC20(asset());

        SafeERC20.safeApprove(_token, address(stakingRewardsZap), _amount);

        uint256 beforeBal = _token.balanceOf(address(this));
        // Returns 'toStake'
        mintedShares = stakingRewardsZap.zapIn(address(yVault), _amount);

        uint256 afterBal = _token.balanceOf(address(this));
        deposited = beforeBal - afterBal;

        // afterDeposit custom logic
        _mint(_receiver, mintedShares);
    }

    function _withdraw(
        uint256 _amount,
        address _receiver,
        address _sender
    ) internal returns (uint256 assets, uint256 shares) {
        VaultAPI _vault = yVault;

        shares = previewWithdraw(_amount);
        uint256 yearnShares = convertAssetsToYearnShares(_amount);

        assets = _doWithdrawal(shares, yearnShares, _sender, _receiver, _vault);

        if (assets < _amount) {
            revert NotEnoughAvailableSharesForAmount();
        }
    }

    function _redeem(
        uint256 _shares,
        address _receiver,
        address _sender
    ) internal returns (uint256 assets, uint256 sharesBurnt) {
        VaultAPI _vault = yVault;
        uint256 yearnShares = convertSharesToYearnShares(_shares);
        assets = _doWithdrawal(_shares, yearnShares, _sender, _receiver, _vault);
        sharesBurnt = _shares;
    }

    function _doWithdrawal(
        uint256 _shares,
        uint256 _yearnShares,
        address _sender,
        address _receiver,
        VaultAPI _vault
    ) private returns (uint256 assets) {
        if (_sender != msg.sender) {
            uint256 currentAllowance = allowance(_sender, msg.sender);
            if (currentAllowance < _shares) {
                revert SpenderDoesNotHaveApprovalToBurnShares();
            }
            _approve(_sender, msg.sender, currentAllowance - _shares);
        }

        if (_shares > balanceOf(_sender)) {
            revert NotEnoughAvailableSharesForAmount();
        }

        if (_yearnShares == 0 || _shares == 0) {
            revert NoAvailableShares();
        }

        _burn(_sender, _shares);

        // withdraw from staking pool (yearn shares only, not rewards)
        stakingRewards.withdraw(_yearnShares);

        // withdraw from vault and get total used shares
        assets = _vault.withdraw(_yearnShares, _receiver, 0);
    }

    function _doRewardWithdrawal(
        uint256 _yearnShares,
        VaultAPI _vault
    ) private returns (uint256 assets) {
        if (_yearnShares == 0) {
            revert NoAvailableShares();
        }

        // Withdraw OP from yvOP vault
        assets = _vault.withdraw(_yearnShares, address(this), 0);
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
        uint256 _assets
    ) public view override returns (uint256) {
        uint256 supply = totalSupply(); // Total supply of wyvTokens

        // yvTokens held in staking contract
        uint256 localAssets = convertYearnSharesToAssets(
            stakingRewards.balanceOf(address(this))
        );
        return supply == 0 ? _assets : _assets.mulDivDown(supply, localAssets);
    }

    function convertToAssets(
        uint256 _shares
    ) public view override returns (uint256 assets) {
        uint256 supply = totalSupply();

        uint256 localAssets = convertYearnSharesToAssets(
            // Shares held in staking contract
            stakingRewards.balanceOf(address(this)) // Issue
        );

        return supply == 0 ? _shares : _shares.mulDivDown(localAssets, supply);
    }

    // Added function for reward conversion
    function convertToRewardAssets(
        uint256 _shares
    ) public view returns (uint256 assets) {
        uint256 supply = totalSupply();
        uint256 localAssets = convertYearnSharesToAssets(
            // Pending rewards
            stakingRewards.earned(address(this))
        );
        return supply == 0 ? _shares : _shares.mulDivDown(localAssets, supply);
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
        uint256 _assets
    ) public view override returns (uint256) {
        return convertToShares(_assets);
    }

    function previewWithdraw(
        uint256 _assets
    ) public view override returns (uint256) {
        uint256 supply = totalSupply();
        uint256 localAssets = convertYearnSharesToAssets(
            stakingRewards.balanceOf(address(this))
        );
        return supply == 0 ? _assets : _assets.mulDivUp(supply, localAssets);
    }

    function previewMint(
        uint256 _shares
    ) public view override returns (uint256) {
        uint256 supply = totalSupply();
        uint256 localAssets = convertYearnSharesToAssets(
            stakingRewards.balanceOf(address(this))
        );
        return supply == 0 ? _shares : _shares.mulDivUp(localAssets, supply);
    }

    function previewRedeem(
        uint256 _shares
    ) public view override returns (uint256) {
        return convertToAssets(_shares);
    }

    // Only concerned about redeem op for rewards reinvesting
    function previewRedeemReward(uint256 _shares) public view returns (uint256) {
        return convertToRewardAssets(_shares);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function convertAssetsToYearnShares(
        uint256 _assets
    ) internal view returns (uint256 yShares) {
        uint256 supply = yVault.totalSupply();
        return supply == 0 ? _assets : _assets.mulDivUp(supply, getFreeFunds());
    }

    /// @dev yvTokens held in staking rewards contract
    function convertYearnSharesToAssets(
        uint256 _yearnShares
    ) internal view returns (uint256 assets) {
        uint256 supply = yVault.totalSupply();
        return
            supply == 0 ? _yearnShares : (_yearnShares * getFreeFunds()) / supply;
    }

    /// @dev Added function for rewards
    function convertYearnRewardSharesToAssets(
        uint256 _yearnShares
    ) internal view returns (uint256 assets) {
        uint256 supply = yVaultReward.totalSupply();
        return
            supply == 0
                ? _yearnShares
                : (_yearnShares * getFreeRewardFunds()) / supply;
    }

    function convertSharesToYearnShares(
        uint256 _shares
    ) internal view returns (uint256 yearnShares) {
        uint256 supply = totalSupply();
        return
            supply == 0
                ? _shares
                : _shares.mulDivUp(
                    stakingRewards.balanceOf(address(this)),
                    totalSupply()
                );
    }

    function allowance(
        address _owner,
        address _spender
    ) public view virtual override(ERC20, IERC20) returns (uint256) {
        return super.allowance(_owner, _spender);
    }

    function balanceOf(
        address account
    ) public view virtual override(ERC20, IERC20) returns (uint256) {
        return super.balanceOf(account);
    }

    function name() public view virtual override(
        ERC20,
        IERC20Metadata
    )   returns (string memory)
    {
        return super.name();
    }

    function symbol() public view virtual override(
        ERC20,
        IERC20Metadata
    )
        returns (string memory)
    {
        return super.symbol();
    }

    function totalSupply() public view virtual override(
        ERC20,
        IERC20
    )
        returns (uint256)
    {
        return super.totalSupply();
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier preemptivelyHarvest() {
        if (preemptiveHarvestEnabled > 0) {
            harvest();
        }
        _;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == owner() || authorized[msg.sender] > 0,
            'YearnV2ERC4626Wrapper: Caller not admin'
        );
        _;
    }

    /// @dev Add to prevent operation outside of app context.
    modifier onlyAuthorized() {
        if (authorizedEnabled > 0) {
            require(
                authorized[msg.sender] == 1,
                'YearnV2ERC4626Wrapper: Caller not authorized'
            );
        }
        _;
    }
}