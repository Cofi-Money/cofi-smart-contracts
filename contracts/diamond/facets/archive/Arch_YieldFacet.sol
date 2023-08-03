// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { Modifiers } from '../libs/LibAppStorage.sol';
// import { LibToken } from '../libs/LibToken.sol';
// import { LibReward } from '../libs/LibReward.sol';
// import { LibVault } from '../libs/LibVault.sol';
// import { IERC4626 } from '../interfaces/IERC4626.sol';
// import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
// import 'hardhat/console.sol';

// /**

//     █▀▀ █▀█ █▀▀ █
//     █▄▄ █▄█ █▀░ █

//     @author Sam Goodenough, The Stoa Corporation Ltd.
//     @title  Yield Facet
//     @notice Provides logic for distributing and managing yield.
//  */

// contract YieldFacet is Modifiers {

//     /*//////////////////////////////////////////////////////////////
//                             YIELD DISTRIBUTION
//     //////////////////////////////////////////////////////////////*/

//     /// @notice Function for updating fi token supply relative to vault earnings.
//     ///
//     /// @param  _fi The fi token to distribute yield earnings for.
//     function rebase(
//         address _fi
//     )   public
//         returns (uint256 assets, uint256 yield, uint256 shareYield)
//     {
//         if (s.rebasePublic[_fi] == 0)
//             require(
//                 s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
//                 'YieldFacet: Caller not Upkeep or Admin'
//             );
//         return LibToken._poke(_fi);
//     }

//     /*//////////////////////////////////////////////////////////////
//                             MIGRATION FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     /// @notice Function for migrating to a new Vault. The new Vault must support the
//     ///         same underlying token (e.g., USDC).
//     ///
//     /// @dev    Opt to trigger the relevant route rather than a single migrate function
//     ///         that has to deduce the correct route.
//     ///
//     /// @dev    Ensure that a buffer of the underlying token resides in the Diamond
//     ///         beforehand to account for slippage.
//     ///
//     /// @param  _fi         The fi token to migrate vault backing for.
//     /// @param  _newVault   The vault to migrate to (must adhere to ERC4626).
//     function migrateVault(
//         address _fi,
//         address _newVault
//     )   external
//         returns (bool)
//     {
//         require(
//             s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
//             'YieldFacet: Caller not Upkeep or Admin'
//         );
//         if (
//             IERC4626(s.vault[_fi]).asset() == IERC4626(_newVault).asset()
//         ) return migrateMutual(_fi, _newVault); // U => U; D => D.
//         else if (
//             s.underlying[_fi] == IERC4626(s.vault[_fi]).asset() &&
//             s.underlying[_fi] != IERC4626(_newVault).asset()
//         ) return migrateToDeriv(_fi, _newVault); // U => D.
//         else if (
//             s.underlying[_fi] != IERC4626(s.vault[_fi]).asset() &&
//             s.underlying[_fi] == IERC4626(_newVault).asset()
//         ) return migrateToUnderlying(_fi, _newVault); // D => U.
//         else return migrateToUnlikeDeriv(_fi, _newVault); // D => D'.
//     }

//     /// @dev    U => U; D => D.
//     function migrateMutual(
//         address _fi,
//         address _newVault
//     )   internal
//         returns (bool)
//     {
//         // Pull funds from old vault.
//         uint256 assets = IERC4626(s.vault[_fi]).redeem(
//             IERC20(s.vault[_fi]).balanceOf(address(this)),
//             address(this),
//             address(this)
//         );

//         // Approve _newVault spend for Diamond.
//         SafeERC20.safeApprove(
//             IERC20(IERC4626(s.vault[_fi]).asset()),
//             _newVault,
//             assets + s.buffer[_fi]
//         );

//         // Deploy funds to new vault.
//         LibVault._wrap(
//             assets + s.buffer[_fi],
//             _newVault,
//             address(this)
//         );

//         require(
//             // Vaults use same asset, therefore same decimals.
//             assets <= LibVault._totalValue(_newVault),
//             'YieldFacet: Vault migration slippage exceeded'
//         );
//         emit LibVault.VaultMigration(
//             _fi,
//             s.vault[_fi],
//             _newVault,
//             assets,
//             LibVault._totalValue(_newVault)
//         );

//         s.vault[_fi] = _newVault; // Update vault for fi token.

//         LibToken._poke(_fi); // Sync fi token supply to assets in vault.

//         return true;
//     }

//     /// @dev U => D.
//     function migrateToDeriv(
//         address _fi,
//         address _newVault
//     )   internal
//         extGuardOn
//         returns (bool)
//     {
//         require(
//             s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
//             'YieldFacet: Caller not Upkeep or Admin'
//         );
//         // Obtain U.
//         uint256 assets = IERC4626(s.vault[_fi]).redeem(
//             IERC20(s.vault[_fi]).balanceOf(address(this)),
//             address(this),
//             address(this)
//         );

//         // Get D from U.
//         (bool success, ) = address(this).call(abi.encodeWithSelector(
//             s.derivParams[s.vault[_fi]].toDeriv,
//             assets + s.buffer[_fi]  // Convert U buffer to D here.
//         )); // Will fail here if set vault is not using a derivative.
//         require(success, 'YieldFacet: Underlying to derivative operation failed');
//         require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');

//         // Approve _newVault spend for Diamond.
//         SafeERC20.safeApprove(
//             IERC20(IERC4626(_newVault).asset()),
//             _newVault,
//             s.RETURN_ASSETS
//         );

//         (success, ) = address(this).call(abi.encodeWithSelector(
//             s.derivParams[s.vault[_fi]].convertToUnderlying,
//             LibVault._getAssets(
//                 // Deploy D.
//                 LibVault._wrap(
//                     s.RETURN_ASSETS,
//                     s.vault[_fi],
//                     address(this)
//                 ),
//                 s.vault[_fi]
//             )
//         ));
//         require(success, 'YieldFacet: Convert to underlying operation failed');
//         require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');

//         require(
//             // Ensure same decimals for accurate comparison.
//             LibToken._toFiDecimals(_fi, assets) <=
//                 LibToken._toFiDecimals(_fi, LibVault._totalValue(_newVault)),
//             'YieldFacet: Vault migration slippage exceeded'
//         );
//         emit LibVault.VaultMigration(
//             _fi,
//             s.vault[_fi],
//             _newVault,
//             assets,
//             LibVault._totalValue(_newVault)
//         );

//         s.vault[_fi] = _newVault; // Update vault for fi token.

//         LibToken._poke(_fi); // Sync fi token supply to assets in vault.

//         return true;
//     }

//     /// @dev D => U.
//     function migrateToUnderlying(
//         address _fi,
//         address _newVault
//     )   internal
//         extGuardOn
//         returns (bool)
//     {
//         require(
//             s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
//             'YieldFacet: Caller not Upkeep or Admin'
//         );

//         // Get U from D.
//         (bool success, ) = address(this).call(abi.encodeWithSelector(
//             s.derivParams[s.vault[_fi]].toUnderlying,
//             // Obtain D.
//             IERC4626(s.vault[_fi]).redeem( // E.g., 100 USDC-LP.
//                 IERC20(s.vault[_fi]).balanceOf(address(this)),
//                 address(this),
//                 address(this)
//             )
//         )); // Will fail here if set vault is not using a derivative.
//         require(success, 'YieldFacet: Underlying to derivative operation failed');
//         require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');

//         // Approve _newVault spend for Diamond.
//         SafeERC20.safeApprove(
//             IERC20(IERC4626(_newVault).asset()),
//             _newVault,
//             s.RETURN_ASSETS + s.buffer[_fi] // Include buffer here.
//         );

//         // Deploy U. Remaining logic same as 'migrateMutual()'.
//         LibVault._wrap(
//             s.RETURN_ASSETS + s.buffer[_fi],
//             _newVault,
//             address(this)
//         );

//         require(
//             // '_totalValue()' returns underlying equivalent, therefore same decimals.
//             s.RETURN_ASSETS <= LibVault._totalValue(_newVault),
//             'YieldFacet: Vault migration slippage exceeded'
//         );
//         emit LibVault.VaultMigration(
//             _fi,
//             s.vault[_fi],
//             _newVault,
//             s.RETURN_ASSETS,
//             LibVault._totalValue(_newVault)
//         );

//         s.vault[_fi] = _newVault; // Update vault for fi token.

//         LibToken._poke(_fi); // Sync fi token supply to assets in vault.

//         return true;
//     }

//     /// @dev D => D' (= D => U => D').
//     function migrateToUnlikeDeriv(
//         address _fi,
//         address _newVault
//     )   internal
//         extGuardOn
//         returns (bool)
//     {
//         require(
//             s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
//             'YieldFacet: Caller not Upkeep or Admin'
//         );
//         // Obtain D.
//         uint256 assets = IERC4626(s.vault[_fi]).redeem(
//             IERC20(s.vault[_fi]).balanceOf(address(this)),
//             address(this),
//             address(this)
//         );

//         // Get U from D.
//         (bool success, ) = address(this).call(abi.encodeWithSelector(
//             s.derivParams[s.vault[_fi]].toUnderlying,
//             assets  // Buffer already exists in underlying so no need to convert.
//         )); // Will fail here if set vault is not using a derivative.
//         require(success, 'YieldFacet: Underlying to derivative operation failed');
//         require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');
//         assets = s.RETURN_ASSETS;
//         s.RETURN_ASSETS = 0; // Need to reset for next operation.

//         // Get D' from U.
//         (success, ) = address(this).call(abi.encodeWithSelector(
//             s.derivParams[_newVault].toDeriv,
//             assets + s.buffer[_fi]  // Convert U buffer to D' here.
//         )); // Will fail here if new vault is not using a derivative.
//         require(success, 'YieldFacet: Underlying to derivative operation failed');
//         require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');

//         // Approve new vault spend for Diamond.
//         SafeERC20.safeApprove(
//             IERC20(IERC4626(_newVault).asset()),
//             _newVault,
//             s.RETURN_ASSETS
//         );

//         // Deploy D'.
//         (success, ) = address(this).call(abi.encodeWithSelector(
//             s.derivParams[_newVault].convertToUnderlying,
//             LibVault._getAssets(
//                 LibVault._wrap(
//                     s.RETURN_ASSETS,
//                     _newVault,
//                     address(this)
//                 ),
//                 s.vault[_fi]
//             )
//         ));
//         require(success, 'YieldFacet: Convert to underlying operation failed');
//         require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');

//         require(
//             // Ensure same decimals for accurate comparison.
//             LibToken._toFiDecimals(_fi, assets) <=
//                 LibToken._toFiDecimals(_fi, LibVault._totalValue(_newVault)),
//             'YieldFacet: Vault migration slippage exceeded'
//         );
//         emit LibVault.VaultMigration(
//             _fi,
//             s.vault[_fi],
//             _newVault,
//             assets,
//             LibVault._totalValue(_newVault)
//         );

//         s.vault[_fi] = _newVault; // Update vault for fi token.

//         LibToken._poke(_fi); // Sync fi token supply to assets in vault

//         return true;
//     }

//     /*//////////////////////////////////////////////////////////////
//                             ADMIN - SETTERS
//     //////////////////////////////////////////////////////////////*/

//     /// @dev    The buffer is an amount of underlying that resides at this contract for the
//     ///         purpose of ensuring a successful migration. This is because a rebase
//     ///         must execute to "sync" balances, which can only occur if the new supply is
//     ///         greater than the previous supply. Because withdrawals may incur slippage,
//     ///         therefore, need to overcome this.
//     function setBuffer(
//         address _fi,
//         uint256 _buffer
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         s.buffer[_fi] = _buffer;
//         return true;
//     }

//     /// @dev Only for setting up a new fi token. 'migrateVault()' must be used otherwise.
//     function setVault(
//         address _fi,
//         address _vault
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         require(
//             s.vault[_fi] == address(0),
//             'YieldFacet: Fi token must not already link with a vault'
//         );
//         s.vault[_fi] = _vault;
//         return true;
//     }

//     function setRebasePublic(
//         address _fi,
//         uint8   _enabled
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         s.rebasePublic[_fi] = _enabled;
//         return true;
//     }

//     /// @notice Opts the diamond into receiving yield on holding of fi tokens (which fees
//     ///         are captured in). Note that the feeCollector is a separate contract.
//     ///         By default, elect to not activate (thereby passing on yield to holders).
//     function rebaseOptIn(
//         address _fi
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         LibToken._rebaseOptIn(_fi);
//         return true;
//     }

//     function rebaseOptOut(
//         address _fi
//     )   external
//         onlyAdmin
//         returns (bool)
//     {
//         LibToken._rebaseOptOut(_fi);
//         return true;
//     }

//     /*//////////////////////////////////////////////////////////////
//                             ADMIN - GETTERS
//     //////////////////////////////////////////////////////////////*/

//     function getBuffer(
//         address _fi
//     )   external
//         view
//         returns (uint256)
//     {
//         return s.buffer[_fi];
//     }
// }