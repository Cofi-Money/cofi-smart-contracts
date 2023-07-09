// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author The Stoa Corporation Ltd.
    @title  Yield Facet
    @notice Provides logic for distributing and managing yield.
 */

import { Modifiers } from '../libs/LibAppStorage.sol';
import { PercentageMath } from '../libs/external/PercentageMath.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibReward } from '../libs/LibReward.sol';
import { LibVault } from '../libs/LibVault.sol';
import { IERC4626 } from '../interfaces/IERC4626.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract YieldFacet is Modifiers {
    using PercentageMath for uint256;

    /// @notice Function for updating fiAssets originating from vaults.
    ///
    /// @param  fiAsset The fiAsset to distribute yield earnings for.
    function rebase(
        address fiAsset
    )   public
        returns (uint256 assets, uint256 yield, uint256 shareYield)
    {
        require(
            s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
            'YieldFacet: Caller not Upkeep or Admin'
        );
        uint256 currentSupply = IERC20(fiAsset).totalSupply();
        if (currentSupply == 0) {
            emit LibToken.TotalSupplyUpdated(fiAsset, 0, 0, 1e18, 0);
            return (0, 0, 0); 
        }

        if (s.harvestable[s.vault[fiAsset]] == 1) LibVault._harvest(fiAsset);

        assets = LibToken._toFiDecimals(fiAsset, LibVault._totalValue(s.vault[fiAsset]));

        if (assets > currentSupply) {

            yield = assets - currentSupply;

            shareYield = yield.percentMul(1e4 - s.serviceFee[fiAsset]);

            LibToken._changeSupply(
                fiAsset,
                currentSupply + shareYield,
                yield,
                yield - shareYield
            );

            if (yield - shareYield > 0)
                LibToken._mint(fiAsset, s.feeCollector, yield - shareYield);
        } else {
            emit LibToken.TotalSupplyUpdated(
                fiAsset,
                assets,
                0,
                LibToken._getRebasingCreditsPerToken(fiAsset),
                0
            );
            return (assets, 0, 0);
        }
    }

    /// @dev    Opt to trigger the relevant route rather than a single migrate function
    ///         that has to deduce the correct route.
    function migrateVault(
        address fiAsset,
        address newVault
    )   external
        returns (bool)
    {
        if (
            IERC4626(s.vault[fiAsset]).asset() == IERC4626(newVault).asset()
        ) return migrateMutual(fiAsset, newVault); // U => U; D => D.
        else if (
            s.underlying[fiAsset] == IERC4626(s.vault[fiAsset]).asset() &&
            s.underlying[fiAsset] != IERC4626(newVault).asset()
        ) return migrateToDeriv(fiAsset, newVault); // U => D.
        else if (
            s.underlying[fiAsset] != IERC4626(s.vault[fiAsset]).asset() &&
            s.underlying[fiAsset] == IERC4626(newVault).asset()
        ) return migrateToUnderlying(fiAsset, newVault); // D => U.
        else return migrateToUnlikeDeriv(fiAsset, newVault); // D => D'.
    }

    /// @notice Function for migrating to a new Vault. The new Vault must support the
    ///         same underlyingAsset (e.g., USDC).
    ///
    /// @dev    Ensure that a buffer of the underlyingAsset resides in the Diamond
    ///         beforehand to account for slippage.
    ///
    /// @param  fiAsset     The fiAsset to migrate vault backing for.
    /// @param  newVault    The vault to migrate to (must adhere to ERC4626).
    /// @dev    U => U; D => D.
    function migrateMutual(
        address fiAsset,
        address newVault
    )   public
        returns (bool)
    {
        require(
            s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
            'YieldFacet: Caller not Upkeep or Admin'
        );
        // Pull funds from old vault.
        uint256 assets = IERC4626(s.vault[fiAsset]).redeem(
            IERC20(s.vault[fiAsset]).balanceOf(address(this)),
            address(this),
            address(this)
        );

        // Approve newVault spend for Diamond.
        SafeERC20.safeApprove(
            IERC20(IERC4626(s.vault[fiAsset]).asset()),
            newVault,
            assets + s.buffer[fiAsset]
        );

        // Deploy funds to new vault.
        LibVault._wrap(
            assets + s.buffer[fiAsset],
            newVault,
            address(this)
        );

        require(
            // Vaults use same asset, therefore same decimals.
            assets <= LibVault._totalValue(newVault),
            'YieldFacet: Vault migration slippage exceeded'
        );
        emit LibVault.VaultMigration(
            fiAsset,
            s.vault[fiAsset],
            newVault,
            assets,
            LibVault._totalValue(newVault)
        );

        // Update vault for fiAsset.
        s.vault[fiAsset] = newVault;

        rebase(fiAsset);

        return true;
    }

    /// @dev    U => D.
    function migrateToDeriv(
        address fiAsset,
        address newVault
    )   public
        EXTGuardOn
        returns (bool)
    {
        require(
            s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
            'YieldFacet: Caller not Upkeep or Admin'
        );
        // Obtain U.
        uint256 assets = IERC4626(s.vault[fiAsset]).redeem(
            IERC20(s.vault[fiAsset]).balanceOf(address(this)),
            address(this),
            address(this)
        );

        // Get D from U.
        (bool success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[s.vault[fiAsset]].toDeriv,
            assets + s.buffer[fiAsset]  // Convert U buffer to D here.
        )); // Will fail here if set vault is not using a derivative.
        require(success, 'YieldFacet: Underlying to derivative operation failed');
        require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');

        // Approve newVault spend for Diamond.
        SafeERC20.safeApprove(
            IERC20(IERC4626(newVault).asset()),
            newVault,
            s.RETURN_ASSETS
        );

        (success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[s.vault[fiAsset]].convertToUnderlying,
            LibVault._getAssets(
                // Deploy D.
                LibVault._wrap(
                    s.RETURN_ASSETS,
                    s.vault[fiAsset],
                    address(this)
                ),
                s.vault[fiAsset]
            )
        ));
        require(success, 'YieldFacet: Convert to underlying operation failed');
        require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');
        s.RETURN_ASSETS = 0; // Reset.

        require(
            // Ensure same decimals for accurate comparison.
            LibToken._toFiDecimals(fiAsset, assets) <=
                LibToken._toFiDecimals(fiAsset, LibVault._totalValue(newVault)),
            'YieldFacet: Vault migration slippage exceeded'
        );
        emit LibVault.VaultMigration(
            fiAsset,
            s.vault[fiAsset],
            newVault,
            assets,
            LibVault._totalValue(newVault)
        );

        // Update vault for fiAsset.
        s.vault[fiAsset] = newVault;

        rebase(fiAsset);

        return true;
    }

    /// @dev    D => U.
    function migrateToUnderlying(
        address fiAsset,
        address newVault
    )   public
        EXTGuardOn
        returns (bool)
    {
        require(
            s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
            'YieldFacet: Caller not Upkeep or Admin'
        );

        // Get U from D.
        (bool success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[s.vault[fiAsset]].toUnderlying,
            // Obtain D.
            IERC4626(s.vault[fiAsset]).redeem( // E.g., 100 USDC-LP.
                IERC20(s.vault[fiAsset]).balanceOf(address(this)),
                address(this),
                address(this)
            )
        )); // Will fail here if set vault is not using a derivative.
        require(success, 'YieldFacet: Underlying to derivative operation failed');
        require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');

        // Approve newVault spend for Diamond.
        SafeERC20.safeApprove(
            IERC20(IERC4626(newVault).asset()),
            newVault,
            s.RETURN_ASSETS + s.buffer[fiAsset] // Include buffer here.
        );

        // Deploy U. Remaining logic same as 'migrateMutual()'.
        LibVault._wrap(
            s.RETURN_ASSETS + s.buffer[fiAsset],
            newVault,
            address(this)
        );

        require(
            // '_totalValue()' returns underlying equivalent, therefore same decimals.
            s.RETURN_ASSETS <= LibVault._totalValue(newVault),
            'YieldFacet: Vault migration slippage exceeded'
        );
        emit LibVault.VaultMigration(
            fiAsset,
            s.vault[fiAsset],
            newVault,
            s.RETURN_ASSETS,
            LibVault._totalValue(newVault)
        );
        s.RETURN_ASSETS = 0;

        // Update vault for fiAsset.
        s.vault[fiAsset] = newVault;

        rebase(fiAsset);

        return true;
    }

    /// @dev D => D' (= D => U => D').
    function migrateToUnlikeDeriv(
        address fiAsset,
        address newVault
    )   public
        EXTGuardOn
        returns (bool)
    {
        require(
            s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
            'YieldFacet: Caller not Upkeep or Admin'
        );
        // Obtain D.
        uint256 assets = IERC4626(s.vault[fiAsset]).redeem(
            IERC20(s.vault[fiAsset]).balanceOf(address(this)),
            address(this),
            address(this)
        );

        // Get U from D.
        (bool success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[s.vault[fiAsset]].toUnderlying,
            assets  // Buffer already exists in underlying so no need to convert.
        )); // Will fail here if set vault is not using a derivative.
        require(success, 'YieldFacet: Underlying to derivative operation failed');
        require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');
        assets = s.RETURN_ASSETS;
        s.RETURN_ASSETS = 0; // Need to reset for next operation.

        // Get D' from U.
        (success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[newVault].toDeriv,
            assets + s.buffer[fiAsset]  // Convert U buffer to D' here.
        )); // Will fail here if new vault is not using a derivative.
        require(success, 'YieldFacet: Underlying to derivative operation failed');
        require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');

        // Approve new vault spend for Diamond.
        SafeERC20.safeApprove(
            IERC20(IERC4626(newVault).asset()),
            newVault,
            s.RETURN_ASSETS
        );

        // Deploy D'.
        (success, ) = address(this).call(abi.encodeWithSelector(
            s.derivParams[newVault].convertToUnderlying,
            LibVault._getAssets(
                LibVault._wrap(
                    s.RETURN_ASSETS,
                    newVault,
                    address(this)
                ),
                s.vault[fiAsset]
            )
        ));
        require(success, 'YieldFacet: Convert to underlying operation failed');
        require(s.RETURN_ASSETS > 0, 'YieldFacet: Zero return assets received');
        s.RETURN_ASSETS = 0; // Reset.

        require(
            // Ensure same decimals for accurate comparison.
            LibToken._toFiDecimals(fiAsset, assets) <=
                LibToken._toFiDecimals(fiAsset, LibVault._totalValue(newVault)),
            'YieldFacet: Vault migration slippage exceeded'
        );
        emit LibVault.VaultMigration(
            fiAsset,
            s.vault[fiAsset],
            newVault,
            assets,
            LibVault._totalValue(newVault)
        );

        // Update vault for fiAsset.
        s.vault[fiAsset] = newVault;

        rebase(fiAsset);

        return true;
    }

    function setBuffer(
        address fiAsset,
        uint256 buffer
    )   external
        onlyAdmin
        returns (bool)
    {
        s.buffer[fiAsset] = buffer;
        return true;
    }

    /// @dev Only for setting up a new fiAsset. 'migrateVault()' must be used otherwise.
    function setVault(
        address fiAsset,
        address vault
    )   external
        onlyAdmin
        returns (bool)
    {
        require(
            s.vault[fiAsset] == address(0),
            'YieldFacet: fiAsset must not already link with a Vault'
        );
        s.vault[fiAsset] = vault;
        return true;
    }

    function rebaseOptIn(
        address fiAsset
    )   external
        onlyAdmin
        returns (bool)
    {
        LibToken._rebaseOptIn(fiAsset);
        return true;
    }

    function rebaseOptOut(
        address fiAsset
    )   external
        onlyAdmin
        returns (bool)
    {
        LibToken._rebaseOptOut(fiAsset);
        return true;
    }
}