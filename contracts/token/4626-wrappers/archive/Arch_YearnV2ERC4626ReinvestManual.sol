// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// /**

//     █▀▀ █▀█ █▀▀ █
//     █▄▄ █▄█ █▀░ █

//     @author The Stoa Corporation Ltd. (Adapted from RobAnon, 0xTraub, 0xTinder).
//     @title  Yearn Zap Reinvest Wrapper
//     @notice Provides 4626-compatibility and functions for reinvesting
//             staking rewards.
//  */

// import "./interfaces/IVaultWrapper.sol";
// import "./interfaces/IStakingRewardsZap.sol";
// import "./interfaces/IStakingRewards.sol";
// import {VaultAPI, IYearnRegistry} from "./interfaces/VaultAPI.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/access/Ownable2Step.sol";
// import {FixedPointMathLib} from "./libs/FixedPointMathLib.sol";
// import "hardhat/console.sol";

// contract YearnV2ERC4626WrapperReinvestManual is
//     ERC4626,
//     IVaultWrapper,
//     Ownable2Step
// {
//     using FixedPointMathLib for uint;
//     using SafeERC20 for IERC20;

//     IYearnRegistry public registry =
//         IYearnRegistry(0x79286Dd38C9017E5423073bAc11F53357Fc5C128);

//     VaultAPI public yVault;

//     VaultAPI public yVaultReward; // yvOP

//     IStakingRewards public stakingRewards;

//     IStakingRewardsZap public stakingRewardsZap =
//         IStakingRewardsZap(0x498d9dCBB1708e135bdc76Ef007f08CBa4477BE2);

//     mapping(address => uint8) authorized;

//     constructor(
//         VaultAPI _vault,
//         VaultAPI _rewardVault,
//         IStakingRewards _stakingRewards,
//         address _underlying
//     )
//         ERC20(
//             string(
//                 abi.encodePacked("Wrapped ", _vault.name(), "-Reinvest4626")
//             ),
//             string(abi.encodePacked("w", _vault.symbol()))
//         )
//         ERC4626(
//             IERC20(_underlying) // OZ contract retrieves decimals from asset
//         )
//     {
//         yVault = _vault;
//         yVaultReward = _rewardVault;
//         stakingRewards = _stakingRewards;
//         authorized[msg.sender] = 1;
//     }

//     function vault() external view returns (address) {
//         return address(yVault);
//     }

//     // Note this number will be different from this token's totalSupply
//     function vaultTotalSupply() external view returns (uint256) {
//         return yVault.totalSupply();
//     }

//     /*//////////////////////////////////////////////////////////////
//                     STAKING REWARDS REINVEST LOGIC
//     //////////////////////////////////////////////////////////////*/

//     function getReward(uint8 _withdrawal) public onlyAuthorized {
//         // Obtain yvOP from StakingRewards contract.
//         stakingRewards.getReward();

//         if (_withdrawal == 1) {
//             // Redeem yvOP for OP.
//             _doRewardWithdrawal(
//                 IERC20(yVaultReward).balanceOf(address(this)),
//                 yVaultReward
//             );
//         }

//     }

//     function recoverERC20(
//         IERC20 token
//     ) external onlyAuthorized {
//         token.safeTransfer(msg.sender, token.balanceOf(address(this)));
//     }

//     function harvest()
//         public
//         onlyAuthorized
//         returns (uint256 deposited, uint256 yearnShares)
//     {
//         // Deposit to yVault
//         (deposited, yearnShares) = _doRewardDeposit();
//     }

//     /*//////////////////////////////////////////////////////////////
//                             ADMIN SETTERS
//     //////////////////////////////////////////////////////////////*/

//     function toggleAuthorized(
//         address account
//     ) external onlyOwner returns (bool) {
//         require(
//             account != owner(),
//             "YearnZapReinvestWrapper: Cannot remove authorisation of Owner"
//         );
//         authorized[account] == 0
//             ? authorized[account] = 1
//             : authorized[account] = 0;
//         return authorized[account] > 0 ? true : false;
//     }

//     /*//////////////////////////////////////////////////////////////
//                         DEPOSIT/WITHDRAWAL LOGIC
//     //////////////////////////////////////////////////////////////*/

//     function deposit(
//         uint256 assets,
//         address receiver
//     ) public override returns (uint256 shares) {
//         (assets, shares) = _deposit(assets, receiver, msg.sender);

//         emit Deposit(msg.sender, receiver, assets, shares);
//     }

//     function mint(
//         uint256 shares,
//         address receiver
//     ) public override returns (uint256 assets) {
//         // No need to check for rounding error, previewMint rounds up.
//         assets = previewMint(shares);

//         uint expectedShares = shares;
//         (assets, shares) = _deposit(assets, receiver, msg.sender);

//         if (shares != expectedShares) {
//             revert NotEnoughAvailableAssetsForAmount();
//         }

//         emit Deposit(msg.sender, receiver, assets, shares);
//     }

//     function withdraw(
//         uint256 assets,
//         address receiver,
//         address _owner
//     ) public override returns (uint256 shares) {
//         if (assets == 0) {
//             revert NonZeroArgumentExpected();
//         }

//         (assets, shares) = _withdraw(assets, receiver, _owner);

//         emit Withdraw(msg.sender, receiver, _owner, assets, shares);
//     }

//     function redeem(
//         uint256 shares,
//         address receiver,
//         address _owner
//     ) public override returns (uint256 assets) {
//         if (shares == 0) {
//             revert NonZeroArgumentExpected();
//         }

//         (assets, shares) = _redeem(shares, receiver, _owner);

//         emit Withdraw(msg.sender, receiver, _owner, assets, shares);
//     }

//     /*//////////////////////////////////////////////////////////////
//                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
//     //////////////////////////////////////////////////////////////*/

//     function maxDeposit(address) public view override returns (uint256) {
//         return yVault.availableDepositLimit();
//     }

//     function maxMint(address _account) public view override returns (uint256) {
//         return maxDeposit(_account) / yVault.pricePerShare();
//     }

//     function maxWithdraw(
//         address _owner
//     ) public view override returns (uint256) {
//         return convertToAssets(this.balanceOf(_owner));
//     }

//     function maxRedeem(address _owner) public view override returns (uint256) {
//         return this.balanceOf(_owner);
//     }

//     function _deposit(
//         uint256 amount,
//         address receiver,
//         address depositor
//     ) internal returns (uint256 deposited, uint256 mintedShares) {
//         IERC20 _token = IERC20(asset());

//         if (amount == type(uint256).max) {
//             amount = Math.min(
//                 _token.balanceOf(depositor),
//                 _token.allowance(depositor, address(this))
//             );
//         }

//         SafeERC20.safeTransferFrom(_token, depositor, address(this), amount);

//         SafeERC20.safeApprove(_token, address(stakingRewardsZap), amount);

//         uint256 beforeBal = _token.balanceOf(address(this));

//         mintedShares = stakingRewardsZap.zapIn(address(yVault), amount);

//         uint256 afterBal = _token.balanceOf(address(this));
//         deposited = beforeBal - afterBal;

//         // afterDeposit custom logic
//         _mint(receiver, mintedShares);
//     }

//     /// @notice Deposit want obtained from reward (e.g., USDC received from swapping OP).
//     function _doRewardDeposit() internal returns (uint256 deposited, uint256 mintedShares) {
//         IERC20 _token = IERC20(asset());

//         uint256 amount = _token.balanceOf(address(this));

//         SafeERC20.safeApprove(_token, address(stakingRewardsZap), amount);

//         uint256 beforeBal = _token.balanceOf(address(this));

//         // Returns 'toStake'
//         mintedShares = stakingRewardsZap.zapIn(address(yVault), amount);

//         uint256 afterBal = _token.balanceOf(address(this));
//         deposited = beforeBal - afterBal;
//     }

//     function _withdraw(
//         uint256 amount,
//         address receiver,
//         address sender
//     ) internal returns (uint256 assets, uint256 shares) {
//         VaultAPI _vault = yVault;

//         shares = previewWithdraw(amount);
//         uint yearnShares = convertAssetsToYearnShares(amount);

//         assets = _doWithdrawal(shares, yearnShares, sender, receiver, _vault);

//         if (assets < amount) {
//             revert NotEnoughAvailableSharesForAmount();
//         }
//     }

//     function _redeem(
//         uint256 shares,
//         address receiver,
//         address sender
//     ) internal returns (uint256 assets, uint256 sharesBurnt) {
//         VaultAPI _vault = yVault;
//         uint yearnShares = convertSharesToYearnShares(shares);
//         assets = _doWithdrawal(shares, yearnShares, sender, receiver, _vault);
//         sharesBurnt = shares;
//     }

//     function _doWithdrawal(
//         uint shares,
//         uint yearnShares,
//         address sender,
//         address receiver,
//         VaultAPI _vault
//     ) private returns (uint assets) {
//         if (sender != msg.sender) {
//             uint currentAllowance = allowance(sender, msg.sender);
//             if (currentAllowance < shares) {
//                 revert SpenderDoesNotHaveApprovalToBurnShares();
//             }
//             _approve(sender, msg.sender, currentAllowance - shares);
//         }

//         if (shares > balanceOf(sender)) {
//             revert NotEnoughAvailableSharesForAmount();
//         }

//         if (yearnShares == 0 || shares == 0) {
//             revert NoAvailableShares();
//         }

//         _burn(sender, shares);

//         // withdraw from staking pool (yearn shares only, not rewards)
//         stakingRewards.withdraw(yearnShares);

//         // withdraw from vault and get total used shares
//         assets = _vault.withdraw(yearnShares, receiver, 0);
//     }

//     function _doRewardWithdrawal(
//         uint yearnShares,
//         VaultAPI _vault
//     ) private returns (uint assets) {
//         if (yearnShares == 0) {
//             revert NoAvailableShares();
//         }

//         // Withdraw OP from yvOP vault
//         assets = _vault.withdraw(yearnShares, address(this), 0);
//     }

//     /*//////////////////////////////////////////////////////////////
//                           ACCOUNTING LOGIC
//     //////////////////////////////////////////////////////////////*/

//     function totalAssets() public view override returns (uint256) {
//         // This contract is a passthrough wrapper. Assets are held in the respective staking contract.
//         return
//             convertYearnSharesToAssets(stakingRewards.balanceOf(address(this)));
//     }

//     function convertToShares(
//         uint256 assets
//     ) public view override returns (uint256) {
//         uint supply = totalSupply(); // Total supply of wyvTokens

//         // yvTokens held in staking contract
//         uint localAssets = convertYearnSharesToAssets(
//             stakingRewards.balanceOf(address(this))
//         );
//         return supply == 0 ? assets : assets.mulDivDown(supply, localAssets);
//     }

//     function convertToAssets(
//         uint256 shares
//     ) public view override returns (uint assets) {
//         uint supply = totalSupply();

//         uint localAssets = convertYearnSharesToAssets(
//             // Shares held in staking contract
//             stakingRewards.balanceOf(address(this))
//         );
//         console.log("local assets: %s", localAssets);

//         return supply == 0 ? shares : shares.mulDivDown(localAssets, supply);
//     }

//     // Added function for reward conversion
//     function convertToRewardAssets(
//         uint256 shares
//     ) public view returns (uint assets) {
//         uint supply = totalSupply();
//         uint localAssets = convertYearnSharesToAssets(
//             // Pending rewards
//             stakingRewards.earned(address(this))
//         );
//         return supply == 0 ? shares : shares.mulDivDown(localAssets, supply);
//     }

//     function getFreeFunds() public view virtual returns (uint256) {
//         uint256 lockedFundsRatio = (block.timestamp - yVault.lastReport()) *
//             yVault.lockedProfitDegradation();
//         uint256 _lockedProfit = yVault.lockedProfit();

//         uint256 DEGRADATION_COEFFICIENT = 10 ** 18;
//         uint256 lockedProfit = lockedFundsRatio < DEGRADATION_COEFFICIENT
//             ? _lockedProfit -
//                 ((lockedFundsRatio * _lockedProfit) / DEGRADATION_COEFFICIENT)
//             : 0; // hardcoded DEGRADATION_COEFFICIENT
//         return yVault.totalAssets() - lockedProfit;
//     }

//     // Added function for reward conversion
//     function getFreeRewardFunds() public view virtual returns (uint256) {
//         uint256 lockedFundsRatio = (block.timestamp -
//             yVaultReward.lastReport()) * yVaultReward.lockedProfitDegradation();
//         uint256 _lockedProfit = yVaultReward.lockedProfit();

//         uint256 DEGRADATION_COEFFICIENT = 10 ** 18;
//         uint256 lockedProfit = lockedFundsRatio < DEGRADATION_COEFFICIENT
//             ? _lockedProfit -
//                 ((lockedFundsRatio * _lockedProfit) / DEGRADATION_COEFFICIENT)
//             : 0; // hardcoded DEGRADATION_COEFFICIENT
//         return yVaultReward.totalAssets() - lockedProfit;
//     }

//     function previewDeposit(
//         uint256 assets
//     ) public view override returns (uint256) {
//         return convertToShares(assets);
//     }

//     function previewWithdraw(
//         uint256 assets
//     ) public view override returns (uint256) {
//         uint supply = totalSupply();
//         uint localAssets = convertYearnSharesToAssets(
//             stakingRewards.balanceOf(address(this))
//         );
//         return supply == 0 ? assets : assets.mulDivUp(supply, localAssets);
//     }

//     function previewMint(
//         uint256 shares
//     ) public view override returns (uint256) {
//         uint supply = totalSupply();
//         uint localAssets = convertYearnSharesToAssets(
//             stakingRewards.balanceOf(address(this))
//         );
//         return supply == 0 ? shares : shares.mulDivUp(localAssets, supply);
//     }

//     function previewRedeem(
//         uint256 shares
//     ) public view override returns (uint256) {
//         return convertToAssets(shares);
//     }

//     // Only concerned about redeem op for rewards reinvesting
//     function previewRedeemReward(uint256 shares) public view returns (uint256) {
//         return convertToRewardAssets(shares);
//     }

//     /*//////////////////////////////////////////////////////////////
//                             VIEW FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     function convertAssetsToYearnShares(
//         uint assets
//     ) internal view returns (uint yShares) {
//         uint256 supply = yVault.totalSupply();
//         return supply == 0 ? assets : assets.mulDivUp(supply, getFreeFunds());
//     }

//     /// @dev yvTokens held in staking rewards contract
//     function convertYearnSharesToAssets(
//         uint yearnShares
//     ) internal view returns (uint assets) {
//         uint supply = yVault.totalSupply();
//         return
//             supply == 0 ? yearnShares : (yearnShares * getFreeFunds()) / supply;
//     }

//     /// @dev Added function for rewards
//     function convertYearnRewardSharesToAssets(
//         uint yearnShares
//     ) internal view returns (uint assets) {
//         uint supply = yVaultReward.totalSupply();
//         return
//             supply == 0
//                 ? yearnShares
//                 : (yearnShares * getFreeRewardFunds()) / supply;
//     }

//     function convertSharesToYearnShares(
//         uint shares
//     ) internal view returns (uint yShares) {
//         uint supply = totalSupply();
//         return
//             supply == 0
//                 ? shares
//                 : shares.mulDivUp(
//                     stakingRewards.balanceOf(address(this)),
//                     totalSupply()
//                 );
//     }

//     function allowance(
//         address _owner,
//         address spender
//     ) public view virtual override(ERC20, IERC20) returns (uint256) {
//         return super.allowance(_owner, spender);
//     }

//     function balanceOf(
//         address account
//     ) public view virtual override(ERC20, IERC20) returns (uint256) {
//         return super.balanceOf(account);
//     }

//     function name()
//         public
//         view
//         virtual
//         override(ERC20, IERC20Metadata)
//         returns (string memory)
//     {
//         return super.name();
//     }

//     function symbol()
//         public
//         view
//         virtual
//         override(ERC20, IERC20Metadata)
//         returns (string memory)
//     {
//         return super.symbol();
//     }

//     function totalSupply()
//         public
//         view
//         virtual
//         override(ERC20, IERC20)
//         returns (uint256)
//     {
//         return super.totalSupply();
//     }

//     /*//////////////////////////////////////////////////////////////
//                             MODIFIERS
//     //////////////////////////////////////////////////////////////*/

//     /// @dev Add to prevent state change outside of app context
//     modifier onlyAuthorized() {
//         require(
//             authorized[msg.sender] == 1,
//             "YearnZapReinvestWrapper: Caller not authorized"
//         );
//         _;
//     }
// }
