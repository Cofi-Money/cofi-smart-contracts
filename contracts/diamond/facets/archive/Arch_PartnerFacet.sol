// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { Modifiers, DerivParams } from "../libs/LibAppStorage.sol";
// import { LibToken } from "../libs/LibToken.sol";
// import { LibVault } from "../libs/LibVault.sol";
// import { IERC4626 } from ".././interfaces/IERC4626.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import ".././interfaces/beefy/ISwap.sol";

// /**

//     █▀▀ █▀█ █▀▀ █
//     █▄▄ █▄█ █▀░ █

//     @author Sam Goodenough, The Stoa Corporation Ltd.
//     @title  Partner Facet
//     @notice Custom functions to enable integration with certain vaults.
//     @dev    Functions are organised as (k, v) mappings, where the vault is the key.
//             Motivation in doing so is to avoid a look-up implementation and trigger
//             the function directly.
//             One caveat of calling via the low-level "call()" operation, passing
//             the bytes4 function selector, is that functions must be accessible
//             externally. Therefore, to prevent external calls, a modifier 
//             "extGuard" has been implemented.
//  */

// contract PartnerFacet is Modifiers {

//     /*//////////////////////////////////////////////////////////////
//                             BEEFY HOP VAULT
//     //////////////////////////////////////////////////////////////*/

//     function toDeriv_BeefyHop(
//         address _fi,
//         uint256 _amount
//     ) public extGuard {

//         SafeERC20.safeApprove(
//             IERC20(s.underlying[_fi]),   // Approve USDC spend.
//             s.derivParams[s.vault[_fi]].spender,
//             _amount
//         );

//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = _amount;
//         s.RETURN_ASSETS = ISwap(s.derivParams[s.vault[_fi]].spender).addLiquidity(
//             amounts,
//             0,
//             block.timestamp + 7 days
//         );
//     }

//     function toUnderlying_BeefyHop(
//         address _fi,
//         uint256 _amount
//     ) public extGuard {

//         SafeERC20.safeApprove(
//             IERC20(IERC4626(s.vault[_fi]).asset()),  // Approve HOP-USDC-LP spend.
//             s.derivParams[s.vault[_fi]].spender,
//             _amount
//         );
//         s.RETURN_ASSETS = ISwap(s.derivParams[s.vault[_fi]].spender).removeLiquidityOneToken(
//             _amount,
//             0,
//             0,
//             block.timestamp + 7 days
//         );
//     }

//     function convertToUnderlying_BeefyHop(
//         address _fi,
//         uint256 _amount
//     ) public {

//         s.RETURN_ASSETS = ISwap(s.derivParams[s.vault[_fi]].spender).calculateRemoveLiquidityOneToken(
//             address(this),
//             _amount,
//             0
//         );
//     }

//     function convertToDeriv_BeefyHop(
//         address _fi,
//         uint256 _amount
//     ) public {

//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = LibToken._toUnderlyingDecimals(_fi, _amount);
//         s.RETURN_ASSETS = ISwap(s.derivParams[s.vault[_fi]].spender).calculateTokenAmount(
//             address(this),
//             amounts,
//             false
//         );
//     }

//     /*//////////////////////////////////////////////////////////////
//                             ADMIN - SETTERS
//     //////////////////////////////////////////////////////////////*/

//     function setToDeriv(
//         address         _vault,
//         string memory   _toDeriv
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         s.derivParams[_vault].toDeriv = bytes4(keccak256(bytes(_toDeriv)));
//         return true;
//     }

//     function setToUnderlying(
//         address         _vault,
//         string memory   _toUnderlying
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         s.derivParams[_vault].toDeriv = bytes4(keccak256(bytes(_toUnderlying)));
//         return true;
//     }

//     function setConvertToDeriv(
//         address         _vault,
//         string memory   _convertToDeriv
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         s.derivParams[_vault].toDeriv = bytes4(keccak256(bytes(_convertToDeriv)));
//         return true;
//     }

//     function setConvertToUnderlying(
//         address         _vault,
//         string memory   _convertToUnderlying
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         s.derivParams[_vault].toDeriv = bytes4(keccak256(bytes(_convertToUnderlying)));
//         return true;
//     }

//     function setAdd(
//         address             _vault,
//         address[] memory    _add
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         s.derivParams[_vault].add = _add;
//         return true;
//     }

//     function setNum(
//         address             _vault,
//         uint256[] memory    _num
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         s.derivParams[_vault].num = _num;
//         return true;
//     }

//     /*//////////////////////////////////////////////////////////////
//                                 GETTERS
//     //////////////////////////////////////////////////////////////*/

//     function getDerivParams(
//         address _vault
//     )   external
//         view
//         returns (DerivParams memory)
//     {
//         return s.derivParams[_vault];
//     }
// }