// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { Modifiers } from "../libs/LibAppStorage.sol";
// // import { Modifiers, LoanParams } from "../libs/LibAppStorage.sol";
// import { LibToken } from '../libs/LibToken.sol';
// import { LibVault } from '../libs/LibVault.sol';
// import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

// /**

//     █▀▀ █▀█ █▀▀ █
//     █▄▄ █▄█ █▀░ █

//     @author Sam Goodenough, The Stoa Corporation Ltd.
//     @title  Loan Facet
//  */

// contract LoanFacet is Modifiers {

//     function loan(
//         address _cofi,
//         uint256 _fiOut,
//         address _recipient
//     )   external
//         nonReentrant isWhitelisted loanEnabled(_cofi) minBorrow(_fiOut, _cofi)
//         returns (uint256 loanAfterFee)
//     {
//         uint256 cofiLocked = LibToken._getToLock(_cofi, _fiOut);

//         LibToken._lock(_cofi, msg.sender, cofiLocked);

//         LoanParams memory loanParams;

//         loanParams.cofiLocked = cofiLocked;
//         loanParams.fiIssued = _fiOut;
//         loanParams.maxDuration = s.maxDuration[_cofi];

//         s.loanParams[msg.sender].push(loanParams);

//         // Mint co token.

//         // Emit event.
//     }

//     // function repay(
//     //     address _cofi,
//     //     uint256 _coIn,
//     //     address _depositFrom,
//     //     address _recipient
//     // )   external
//     //     nonReentrant isWhitelisted //minRepay()
//     // {
        
//     // }

//     // function liquidate() {}

//     // /**
//     //  * @notice Rather than incentivize with tokens, impose repayment deadline.
//     //  * @dev + borrow and supply fn in one tx.
//     //  */
//     // function supplyLP() {}

//     // function redeem() {}

// pragma solidity ^0.8.0;

// import "./IERC4626.sol";

// interface IDebtToken {

//     function mint(address _account, uint256 _amount) external;

//     function burn(address _account, uint256 _amount) external;
// }

// // To-do:
// // * Add liquidation penalty.
// // * Add origination fee.
// // * Generalize liquidate() / remove '_account' argument.
// // * Set unique deadline for each loan item.

// contract Loan {

//     struct Vault {
//         uint256 bal; // [shares]
//         uint256 debt; // [assets]
//         uint256 deadline;
//     }

//     struct Collateral {
//         uint256 CR;
//         uint256 duration;
//         uint256 redeemable;
//         address debt;
//         address pool;
//     }

//     mapping(address => mapping(address => Vault)) vault;
//     mapping(address => Collateral) collateral;

//     function deposit(
//         address _collateral,
//         uint256 _amount
//     ) public returns (uint256 shares) {

//         // Deposit assets to pool.
//         shares = IERC4626(collateral[_collateral].pool).deposit(_amount, address(this));
//         // Increase balance by shares received.
//         vault[msg.sender][_collateral].bal += shares;
//     }

//     function withdraw(
//         address _collateral,
//         uint256 _amount
//     ) public returns (uint256 assets) {

//         require(
//             _amount <= getWithdrawAllowance(msg.sender, _collateral),
//             "Amount exceeds withdraw allowance"
//         );
//         // Get corresponding shares to redeem for withdrawal amount.
//         uint256 shares = IERC4626(collateral[_collateral].pool).previewDeposit(_amount);
//         // Deduct balance from vault.
//         vault[msg.sender][_collateral].bal -= shares;
//         // Redeem assets from pool.
//         assets = IERC4626(collateral[_collateral].pool).redeem(shares, msg.sender, address(this));
//     }

//     function borrow(
//         address _collateral,
//         uint256 _amount
//     ) public returns (uint256 deadline) {
        
//         require(
//             _amount <= getBorrowAllowance(msg.sender, _collateral),
//             "Amount exceeds borrow allowance"
//         );
//         // Set deadline for loan if initiating new.
//         if (vault[msg.sender][_collateral].debt == 0) {
//             vault[msg.sender][_collateral].deadline =
//                 block.timestamp + collateral[_collateral].duration;
//         }
//         deadline = vault[msg.sender][_collateral].deadline;
//         // Increase debt of vault.
//         vault[msg.sender][_collateral].debt += _amount;
//         // Mint tokens to account.
//         IDebtToken(collateral[_collateral].debt).mint(msg.sender, _amount);
//     }

//     function repay(
//         address _collateral,
//         uint256 _amount
//     ) public returns (uint256 outstanding) {
        
//         require(vault[msg.sender][_collateral].debt > 0, "Zero debt to repay");
//         if (_amount > vault[msg.sender][_collateral].debt) {
//             _amount = vault[msg.sender][_collateral].debt;
//         }
//         // Burn tokens from account.
//         IDebtToken(collateral[_collateral].debt).burn(msg.sender, _amount);
//         // Reduce debt of vault.
//         return vault[msg.sender][_collateral].debt -= _amount;
//     }

//     function repayWithUnderlying() public {}

//     function recycle(
//         address _collateral
//     ) public returns (uint256 deadline) {

//         require(vault[msg.sender][_collateral].debt > 0, "Zero debt to recycle");
//         if (
//             IERC20(collateral[_collateral].debt).balanceOf(msg.sender) >=
//             vault[msg.sender][_collateral].debt
//         ) {
//             vault[msg.sender][_collateral].deadline =
//                 block.timestamp + collateral[_collateral].duration;
//         }
//         deadline = collateral[_collateral].duration;
//     }

//     function liquidate(
//         address _account,
//         address _collateral
//     ) external returns (uint256 liquidated) {

//         require(vault[msg.sender][_collateral].debt > 0, "Zero debt to liquidate");
//         require(vault[msg.sender][_collateral].deadline < block.timestamp, "Deadline not surpassed");
//         // Retrieve debt amount denominated in shares.
//         liquidated = IERC4626(collateral[_collateral].pool).previewDeposit(vault[msg.sender][_collateral].debt);
//         // Reduce account's balance by debt outstanding.
//         vault[_account][_collateral].bal -= liquidated;
//         // Make liquidation amount available for redemptions.
//         collateral[_collateral].redeemable += liquidated;
//     }

//     function batchLiquidate() public {}

//     function stake(
//         address _collateral
//     ) external {

//     }

//     function redeem(
//         address _collateral
//     ) external {

//     }

//     function loadRedemptions(
//         address _collateral
//     ) external {
        
//     }

//     function getWithdrawAllowance(
//         address _account,
//         address _collateral
//     ) public view returns (uint256 allowance) {

//         return balanceOf(_account, _collateral) -
//             vault[_account][_collateral].debt * collateral[_collateral].CR > 0 ?
//                 balanceOf(_account, _collateral) -
//                     vault[_account][_collateral].debt * collateral[_collateral].CR :
//                 0;
//     }

//     function getBorrowAllowance(
//         address _account,
//         address _collateral
//     ) public view returns (uint256 allowance) {
        
//         return balanceOf(_account, _collateral) / collateral[_collateral].CR - 
//             vault[_account][_collateral].debt > 0 ?
//                 balanceOf(_account, _collateral) / collateral[_collateral].CR -
//                     vault[_account][_collateral].debt :
//                 0;
//     }

//     function balanceOf(
//         address _account,
//         address _collateral
//     ) public view returns (uint256 assets) {

//         return IERC4626(collateral[_collateral].pool).previewRedeem(
//             vault[_account][_collateral].bal
//         );
//     }
// }
// }