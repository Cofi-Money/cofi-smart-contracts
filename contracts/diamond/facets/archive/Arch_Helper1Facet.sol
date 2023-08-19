// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { Modifiers } from '../libs/LibAppStorage.sol';

// /**

//     █▀▀ █▀█ █▀▀ █
//     █▄▄ █▄█ █▀░ █

//     @author Sam Goodenough, The Stoa Corporation Ltd.
//     @title  Helper1 Facet
//     @notice Helper contract with helpful functions.
//  */

// contract Helper1Facet is Modifiers {

//     /// @dev Only use in special circumstances (e.g., no assets reside in the vault to migrate from).
//     function helper1SetVault(
//         address _cofi,
//         address _vault
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         s.vault[_cofi] = _vault;
//         return true;
//     }

//     function helper1SetDecimals(
//         address _cofi,
//         uint8   _decimals
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         s.decimals[_cofi] = _decimals;
//         return true;
//     }
// }