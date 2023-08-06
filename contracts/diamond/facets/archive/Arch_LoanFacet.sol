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

//     // function loan(
//     //     address _fi,
//     //     uint256 _coOut,
//     //     address _recipient
//     // )   external
//     //     nonReentrant isWhitelisted loanEnabled(_fi) minBorrow(_coOut, _fi)
//     //     returns (uint256 loanAfterFee)
//     // {
//     //     uint256 fiLocked = LibToken._getToLock(_fi, _coOut);

//     //     LibToken._lock(_fi, msg.sender, fiLocked);

//     //     LoanParams memory loanParams;

//     //     loanParams.fiLocked = fiLocked;
//     //     loanParams.coIssued = _coOut;
//     //     loanParams.maxDuration = s.maxDuration[_fi];

//     //     s.loanParams[msg.sender].push(loanParams);

//     //     // Mint co token.

//     //     // Emit event.
//     // }

//     // function repay(
//     //     address _fi,
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
// }