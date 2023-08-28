// LibAppStorage.sol
/*//////////////////////////////////////////////////////////////
                    Loan Types {Update ?}
//////////////////////////////////////////////////////////////*/

// struct Safe {
//     uint256 bal; // [shares]
//     uint256 debt; // [assets]
//     uint256 deadline;
// }

// struct Collateral {
//     uint256 CR;
//     uint256 duration;
//     // Collateral earmarked for vaults.
//     // totalSupply - occupied = redeemable.
//     uint256 occupied; // [shares]
//     address debt; // [assets]
//     address underlying; // [assets]
//     address pool;
//     Funnel funnel;
// }

// struct Funnel {
//     Stake[] stakes;
//     // Collateral earmarked for redemptions.
//     uint256 loaded; // [assets]
//     uint256 loadFromIndex;
// }

// struct Stake {
//     uint256 assets;
//     address account;
// }

// struct RedemptionInfo {
//     uint256 redeemable;
//     uint256 directRedeemAllowance;
// }

/*//////////////////////////////////////////////////////////////
                    Loan Params {Update ?}
//////////////////////////////////////////////////////////////*/

// // E.g., Alice => coUSD => Safe.
// mapping(address => mapping(address => Safe)) safe;

// // E.g., coUSD => Collateral.
// mapping(address => Collateral) collateral;

// // E.g., Alice => coUSD => RedemptionInfo.
// mapping(address => mapping(address => RedemptionInfo)) redemptionInfo;

// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { Stake, Modifiers } from '../libs/LibAppStorage.sol';
// import "../interfaces/IERC4626.sol";

// interface IDebtToken {

//     function mint(address _account, uint256 _assets) external;

//     function burn(address _account, uint256 _assets) external;
// }

// contract LoanFacet is Modifiers {

//     function deposit(
//         address _collateral,
//         uint256 _assets
//     ) public returns (uint256 shares) {

//         // Deposit assets to pool.
//         shares = IERC4626(s.collateral[_collateral].pool).deposit(_assets, address(this));
//         // Increase balance by shares received.
//         s.safe[msg.sender][_collateral].bal += shares;
//         // Increase occupied collateral by shares received.
//         s.collateral[_collateral].occupied += shares;
//     }

//     function withdraw(
//         address _collateral,
//         uint256 _assets
//     ) public returns (uint256 assets) {

//         require(
//             _assets <= getWithdrawAllowance(msg.sender, _collateral),
//             "Amount exceeds withdraw allowance"
//         );
//         // Get corresponding shares to redeem for withdrawal amount.
//         uint256 shares = IERC4626(s.collateral[_collateral].pool).previewDeposit(_assets);
//         // Deduct occupied collateral.
//         s.collateral[_collateral].occupied -= shares;
//         // Deduct balance from safe.
//         s.safe[msg.sender][_collateral].bal -= shares;
//         // Redeem assets from pool.
//         assets = IERC4626(s.collateral[_collateral].pool).redeem(shares, msg.sender, address(this));
//     }

//     function borrow(
//         address _collateral,
//         uint256 _assets
//     ) public returns (uint256 deadline) {
        
//         require(
//             _assets <= getBorrowAllowance(msg.sender, _collateral),
//             "Amount exceeds borrow allowance"
//         );
//         // Update deadline if borrowing more than current debt.
//         if (_assets > s.safe[msg.sender][_collateral].debt) {
//             s.safe[msg.sender][_collateral].deadline =
//                 block.timestamp + s.collateral[_collateral].duration;
//         }
//         deadline = s.safe[msg.sender][_collateral].deadline;
//         // Increase debt of safe.
//         s.safe[msg.sender][_collateral].debt += _assets;
//         // Mint tokens to account.
//         IDebtToken(s.collateral[_collateral].debt).mint(msg.sender, _assets);
//     }

//     function repay(
//         address _collateral,
//         uint256 _assets
//     ) public returns (uint256 outstanding) {
        
//         require(s.safe[msg.sender][_collateral].debt > 0, "Zero debt to repay");
//         if (_assets > s.safe[msg.sender][_collateral].debt) {
//             _assets = s.safe[msg.sender][_collateral].debt;
//         }
//         // Burn tokens from account.
//         IDebtToken(s.collateral[_collateral].debt).burn(msg.sender, _assets);
//         // Reduce debt of safe.
//         return s.safe[msg.sender][_collateral].debt -= _assets;
//     }

//     function repayWithUnderlying() public {}

//     function recycle(
//         address _collateral
//     ) public returns (uint256 deadline) {

//         require(s.safe[msg.sender][_collateral].debt > 0, "Zero debt to recycle");
//         if (
//             IERC20(s.collateral[_collateral].debt).balanceOf(msg.sender) >=
//             s.safe[msg.sender][_collateral].debt
//         ) {
//             s.safe[msg.sender][_collateral].deadline =
//                 block.timestamp + s.collateral[_collateral].duration;
//         }
//         return s.safe[msg.sender][_collateral].deadline;
//     }

//     function directMint() public {

//         // Deposit collateral to pool.

//         // Increase occupied collateral.

//         // Increase direct redeem allowance.

//         // Mint debt tokens to user.
//     }

//     function directRedeem() public {

//         // Check if user has direct redeem allowance.

//         // Burn debt tokens from user.

//         // Decrease direct redeem allowance.

//         // Decrease occupied collateral.

//         // Redeem collateral from pool.
//     }

//     function directMintUnderlying() public {

//         // Deposit underlying to yield venue.

//         // Mint collateral to self.

//         // Deposit collateral to pool.

//         // Increase occupied collateral.

//         // Increase direct redeem allowance.

//         // Mint debt tokens to user.
//     }

//     function directRedeemUnderlying() public {

//         // Check if user has direct redeem allowance.

//         // Burn debt tokens from user.

//         // Decrease direct redeem allowance.

//         // Decrease occupied collateral.

//         // Redeem collateral from pool.

//         // Burn collateral from self.

//         // Redeem underlying from yield venue.
//     }

//     function liquidate(
//         address _account,
//         address _collateral,
//         uint256 _deadline
//     ) external returns (uint256 liquidated) {

//         address[] memory accounts = new address[](1);
//         accounts[0] = _account;
//         return batchLiquidate(accounts, _collateral, _deadline);
//     }

//     function batchLiquidate(
//         address[] memory _accounts,
//         address _collateral,
//         uint256 _deadline
//     ) public returns (uint256 liquidatedTotal) {

//         if (_deadline > block.timestamp) {
//             _deadline = block.timestamp;
//         }
//         uint256 liquidated;
//         for(uint i = 0; i < _accounts.length; i++) {
//             if(
//                 // If safe has outstanding debt.
//                 s.safe[_accounts[i]][_collateral].debt > 0 ||
//                 // If safe's deadline has surpassed.
//                 s.safe[_accounts[i]][_collateral].deadline < _deadline
//             ) {
//                 // Retrieve debt amount denominated in shares.
//                 liquidated = IERC4626(s.collateral[_collateral].pool).previewDeposit(
//                     s.safe[msg.sender][_collateral].debt
//                 );
//                 // Reduce safe's balance by debt outstanding.
//                 s.safe[_accounts[i]][_collateral].bal -= liquidated;
//                 // Wipe safe's debt.
//                 s.safe[_accounts[i]][_collateral].debt = 0;
//                 // Make liquidation amount available for redemptions.
//                 s.collateral[_collateral].occupied -= liquidated;
//                 liquidatedTotal += liquidated;
//             }
//         }
//     }

//     /// @notice Frees up collateral (e.g., if account has no intention to repay).
//     /// @return liquidated [shares].
//     function selfLiquidate(
//         address _collateral,
//         uint256 _assets
//     ) external returns (uint256 liquidated) {

//         // Retrieve debt amount denominated in shares.
//         uint256 shares = IERC4626(s.collateral[_collateral].pool).previewDeposit(_assets);
//         liquidated = shares > s.safe[msg.sender][_collateral].bal ?
//             s.safe[msg.sender][_collateral].bal :
//             shares;
//         // Reduce account's balance by debt outstanding.
//         s.safe[msg.sender][_collateral].bal -= liquidated;
//         // Reduce safe's debt.
//         s.safe[msg.sender][_collateral].debt -= _assets > s.safe[msg.sender][_collateral].debt ?
//             s.safe[msg.sender][_collateral].debt :
//             _assets;
//         // Make liquidation amount available for redemptions.
//         s.collateral[_collateral].occupied -= liquidated;
//     }

//     /// @notice Stake submission is irreversible.
//     function stake(
//         address _collateral,
//         uint256 _assets
//     ) external returns (bool) {

//         IDebtToken(s.collateral[_collateral].debt).burn(msg.sender, _assets);

//         Stake memory _stake;
//         _stake.assets = _assets;
//         _stake.account = msg.sender;
//         s.collateral[_collateral].funnel.stakes.push(_stake);
//         return true;
//     }

//     function loadFunnel(
//         address _collateral,
//         uint256 _assets
//     ) external returns (uint256 loaded) {

//         if(_assets > totalRedeemable(_collateral)) {
//             _assets = totalRedeemable(_collateral);
//         }
//         for(
//             uint i = s.collateral[_collateral].funnel.loadFromIndex;
//             i < s.collateral[_collateral].funnel.stakes.length;
//             i++
//         ) {
//             if (_assets > s.collateral[_collateral].funnel.stakes[i].assets) {
//                 // Make full stake amount redeemable.
//                 s.redemptionInfo[s.collateral[_collateral].funnel.stakes[i].account][_collateral].redeemable
//                     += s.collateral[_collateral].funnel.stakes[i].assets;
//                 _assets -= s.collateral[_collateral].funnel.stakes[i].assets;
//             } else {
//                 // Make partial stake amount redeemable.
//                 s.redemptionInfo[s.collateral[_collateral].funnel.stakes[i].account][_collateral].redeemable
//                     += _assets;
//                 // Reduce stake amount to fulfil at most remaining on next execution.
//                 s.collateral[_collateral].funnel.stakes[i].assets -= _assets;
//                 // Ensure to load from this index upon next execution.
//                 s.collateral[_collateral].funnel.loadFromIndex = i;
//             }
//         }
//         return _assets;
//     }

//     function redeem(
//         address _collateral
//     ) external returns (bool) {

//         require(s.redemptionInfo[msg.sender][_collateral].redeemable > 0, "Nothing to redeem");
//         IERC4626(s.collateral[_collateral].pool).redeem(
//             // Get shares from redeemable assets.
//             IERC4626(s.collateral[_collateral].pool)
//                 .previewDeposit(s.redemptionInfo[msg.sender][_collateral].redeemable),
//             msg.sender,
//             address(this)
//         );
//         // Decrease loaded by amount redeemed.
//         s.collateral[_collateral].funnel.loaded -= s.redemptionInfo[msg.sender][_collateral].redeemable;
//         // Reset assets redeemable.
//         s.redemptionInfo[msg.sender][_collateral].redeemable = 0;
//         return true;
//     }

//     function balanceOf(
//         address _account,
//         address _collateral
//     ) public view returns (uint256 assets) {

//         return IERC4626(s.collateral[_collateral].pool).previewRedeem(
//             s.safe[_account][_collateral].bal
//         );
//     }

//     function getWithdrawAllowance(
//         address _account,
//         address _collateral
//     ) public view returns (uint256 allowance) {

//         return balanceOf(_account, _collateral) -
//             s.safe[_account][_collateral].debt * s.collateral[_collateral].CR > 0 ?
//                 balanceOf(_account, _collateral) -
//                     s.safe[_account][_collateral].debt * s.collateral[_collateral].CR :
//                 0;
//     }

//     function getBorrowAllowance(
//         address _account,
//         address _collateral
//     ) public view returns (uint256 allowance) {
        
//         return balanceOf(_account, _collateral) / s.collateral[_collateral].CR - 
//             s.safe[_account][_collateral].debt > 0 ?
//                 balanceOf(_account, _collateral) / s.collateral[_collateral].CR -
//                     s.safe[_account][_collateral].debt :
//                 0;
//     }

//     function totalRedeemable(
//         address _collateral
//     ) public view returns (uint256 assets) {

//         return IERC4626(s.collateral[_collateral].pool).previewRedeem(
//             IERC20(s.collateral[_collateral].pool).totalSupply()
//                 - s.collateral[_collateral].occupied
//         ) - s.collateral[_collateral].funnel.loaded;
//     }
// }