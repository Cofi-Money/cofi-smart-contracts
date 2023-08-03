// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { LibDiamond } from "../../../diamond/core/libs/LibDiamond.sol";

// enum RebaseOptions {
//     NotSet,
//     OptOut,
//     OptIn
// }

// struct ERC20Storage {

//     /*//////////////////////////////////////////////////////////////
//                         COFI STABLECOIN PARAMS
//     //////////////////////////////////////////////////////////////*/

//     string name;
//     string symbol;
//     uint8 decimals;

//     mapping(address => mapping(address => uint256)) _allowances;

//     uint256 _totalSupply; // public
//     uint256 _rebasingCredits;
//     uint256 _rebasingCreditsPerToken;
//     uint256 nonRebasingSupply; // public / may change

//     address app; // "diamond"

//     mapping(address => uint256) _creditBalances; // public
//     mapping(address => uint256) nonRebasingCreditsPerToken; // public / may change
//     mapping(address => uint256) isUpgraded; // public / may change

//     mapping(address => int256) yieldExcl;

//     mapping(address => RebaseOptions) rebaseState; // public / may change

//     /*//////////////////////////////////////////////////////////////
//                             ACCESS PARAMS
//     //////////////////////////////////////////////////////////////*/

//     mapping(address => uint8) admin;
//     mapping(address => uint8) frozen;
//     mapping(address => uint8) rebaseLock;

//     uint8 paused;

//     address owner;
//     address backupOwner;
// }

// library LibERC20Storage {
//     function diamondStorage() internal pure returns (ERC20Storage storage ds) {
//         // bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
//         assembly {
//             ds.slot := 0
//         }
//     }

//     function abs(int256 x_) internal pure returns (uint256) {
//         return uint256(x_ >= 0 ? x_ : -x_);
//     }
// }

// contract Modifiers {
//     ERC20Storage internal s;

//     /**
//      * @dev Verifies that the caller is the Diamond contract
//      */
//     modifier onlyApp() {
//         require(s.app == msg.sender, 'Caller is not App');
//         _;
//     }

//     /**
//      * @dev Verifies that the caller is Owner or Admin.
//      */
//     modifier onlyAuthorized() {
//         require(
//             s.admin[msg.sender] > 0 ||
//             msg.sender == s.owner ||
//             msg.sender == s.backupOwner,
//             'Caller is not authorized'
//         );
//         _;
//     }
// }