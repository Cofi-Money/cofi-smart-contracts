// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vault, SwapProtocol, Modifiers } from '../libs/LibAppStorage.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibSwap } from '../libs/LibSwap.sol';
import { LibReward } from '../libs/LibReward.sol';
import { LibVault } from '../libs/LibVault.sol';
import { StableMath } from '../libs/external/StableMath.sol';
import { PercentageMath } from '../libs/external/PercentageMath.sol';
import { IERC4626 } from '../interfaces/IERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Vault Manager Facet
    @notice Provides logic for managing vaults and distributing yield.
 */

contract VaultManagerFacet is Modifiers {
    using StableMath for uint256;
    using PercentageMath for uint256;

    /*//////////////////////////////////////////////////////////////
                            Yield Distribution
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Syncs cofi token supply to reflect vault earnings.
     * @param _cofi The cofi token to distribute yield earnings for.
     */
    function rebase(
        address _cofi
    )   external
        returns (uint256 assets, uint256 yield, uint256 shareYield)
    {
        if (s.rebasePublic[_cofi] == 0)
            require(
                s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
                'YieldFacet: Caller not Upkeep or Admin'
            );
        return LibToken._poke(_cofi);
    }

    /*//////////////////////////////////////////////////////////////
                            Asset Migration
    //////////////////////////////////////////////////////////////*/

    // /**
    //  * @notice Migrates assets to '_newVault'.
    //  * @dev Ensure that a buffer of the relevant underlying token resides at this contract
    //  *      before executing to account for slippage.
    //  * @param _cofi     The cofi token to migrate underlying tokens for.
    //  * @param _newVault The new ERC4626 vault.
    //  */
    // function migrate(
    //     address _cofi,
    //     address _newVault
    // )   external
    //     returns (bool)
    // {
    //     require(
    //         s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
    //         'YieldFacet: Caller not Upkeep or Admin'
    //     );

    //     // Pull funds from old vault.
    //     uint256 assets = IERC4626(s.vault[_cofi]).redeem(
    //         IERC20(s.vault[_cofi]).balanceOf(address(this)),
    //         address(this),
    //         address(this)
    //     );

    //     /**
    //      * @notice Logic to switch underlying token if new vault accepts another asset.
    //      * @dev Need to ensure that (A) swap params have been set and;
    //      *      (B) _to asset's decimals have been set and;
    //      *      (C) 'buffer' is set for new underlying and resides at this address and;
    //      *      (D) 'harvestable' bool is indicated for new vault if required.
    //      */
    //     if (IERC4626(s.vault[_cofi]).asset() != IERC4626(_newVault).asset()) {
    //         assets = LibSwap._swapERC20ForERC20(
    //             assets,
    //             IERC4626(s.vault[_cofi]).asset(),
    //             IERC4626(_newVault).asset(),
    //             address(this)
    //         );
    //         // Update underlying for cofi token.
    //         s.underlying[_cofi] = IERC4626(_newVault).asset();
    //     }

    //     // Approve '_newVault' spend for this contract.
    //     SafeERC20.safeApprove(
    //         IERC20(IERC4626(_newVault).asset()),
    //         _newVault,
    //         assets + s.buffer[s.underlying[_cofi]]
    //     );

    //     // Deploy funds to new vault.
    //     LibVault._wrap(
    //         assets + s.buffer[s.underlying[_cofi]],
    //         _newVault
    //     );

    //     require(
    //         /// @dev No need to convert decimals as both values denominated in same asset.
    //         assets <= LibVault._totalValue(_newVault),
    //         'YieldFacet: Vault migration slippage exceeded'
    //     );
    //     emit LibVault.VaultMigration(
    //         _cofi,
    //         s.vault[_cofi],
    //         _newVault,
    //         assets,
    //         LibVault._totalValue(_newVault)
    //     );

    //     s.vault[_cofi] = _newVault; // Update vault for cofi token.

    //     LibToken._poke(_cofi); // Sync cofi token supply to assets in vault.

    //     return true;
    // }

    function migrateUnderlying(
        address _cofi,
        Vault[] calldata _vaults
    )   external
        onlyUpkeepOrAdmin
        returns (bool)
    {
        uint256 oldAssets;
        // Pull funds from old vaults.
        for (uint i = 0; i < s.vaults[_cofi].length; i++) {
            oldAssets += IERC4626(s.vaults[_cofi][i].vault).redeem(
                IERC20(s.vaults[_cofi][i].vault).balanceOf(address(this)),
                address(this),
                address(this)
            );
            emit LibVault.VaultAllocationUpdated(s.vaults[_cofi][i].vault, 0);
        }

        address oldUnderlying = IERC4626(s.vaults[_cofi][0].vault).asset();
        address newUnderlying = IERC4626(_vaults[0].vault).asset();
        require(
            s.decimals[newUnderlying] != 0,
            'VaultManagerFacet: Decimals for new underlying not set'
        );
        require(
            s.swapProtocol[oldUnderlying][newUnderlying] != SwapProtocol(0),
            'VaultManagerFacet: Swap path not set for migration'
        );

        uint256 underlyingOut = LibSwap._swapERC20ForERC20(
            oldAssets,
            oldUnderlying,
            newUnderlying,
            address(this)
        );

        require(
            IERC20(newUnderlying).balanceOf(address(this)) >=
                s.buffer[newUnderlying] * _vaults.length,
            'VaultManagerFacet: Insufficient buffer to execute migration'
        );
        uint256 newAssets;
        /// @dev If any new vaults are harvestable then needs to be set beforehand.
        for (uint i = 0; i < _vaults.length; i++) {
            uint256 underlyingIn =
                underlyingOut.percentMul(_vaults[i].allocation) + s.buffer[newUnderlying];
            SafeERC20.safeApprove(
                IERC20(newUnderlying),
                _vaults[i].vault,
                underlyingIn
            );
            newAssets += IERC4626(_vaults[i].vault).previewRedeem(
                LibVault._wrap(
                    underlyingIn,
                    _vaults[i].vault
                )
            );
            emit LibVault.VaultAllocationUpdated(
                s.vaults[_cofi][i].vault,
                s.vaults[_cofi][i].allocation
            );
        }

        require(
            LibToken._toCofiDecimals(newUnderlying, newAssets) >=
                LibToken._toCofiDecimals(oldUnderlying, oldAssets),
            'VaultManagerFacet: Vaults migration slippage exceeded'
        );

        s.vaults[_cofi] = _vaults; // Update vaults for cofi token.

        LibToken._poke(_cofi); // Sync cofi token supply to assets in new vaults.

        return true;
    }

    function migrateAllocation(
        uint256 _allocationTo,
        address _cofi,
        address _vaultA,
        address _vaultB
    )   public
        onlyUpkeepOrAdmin
        returns (bool)
    {
        uint i;
        // Find '_vaultA' location in vaults array.
        for (uint j = 0; i < s.vaults[_cofi].length; j++) {
            if (_vaultA == s.vaults[_cofi][j].vault) {
                i = j;
                break;
            }
        }

        uint256 assets = IERC4626(_vaultA).redeem(
            IERC20(_vaultA).balanceOf(address(this))
                .percentMul(_allocationTo.divPrecisely(s.vaults[_cofi][i].allocation)
                .scaleBy(4, 18)),
            address(this),
            address(this)
        );

        // Deduct allocation from vaultA. 
        s.vaults[_cofi][i].allocation -= _allocationTo;
        emit LibVault.VaultAllocationUpdated(
            _vaultA,
            s.vaults[_cofi][i].allocation
        );

        // If empty then remove from vaults array.
        if (s.vaults[_cofi][i].allocation == 0) {
            s.vaults[_cofi][i] = s.vaults[_cofi][s.vaults[_cofi].length - 1];
            s.vaults[_cofi].pop();
        }

        address underlying = IERC4626(_vaultB).asset();

        // Approve '_vaultB' spend for this contract.
        SafeERC20.safeApprove(
            IERC20(underlying),
            _vaultB,
            assets + s.buffer[underlying]
        );

        // Deploy funds to new vault.
        LibVault._wrap(
            assets + s.buffer[underlying],
            _vaultB
        );

        require(
            /// @dev No need to convert decimals as both values denominated in same asset.
            assets <= LibVault._totalValue(_vaultB),
            'VaultManagerFacet: Vault migration slippage exceeded'
        );

        uint256 newAllocation;
        for (uint j = 0; i < s.vaults[_cofi].length; j++) {
            if (_vaultB == s.vaults[_cofi][j].vault) {
                s.vaults[_cofi][j].allocation += _allocationTo;
                newAllocation = s.vaults[_cofi][j].allocation;
                i = type(uint256).max;
                break;
            }
        }

        // If vaultB is not already in vaults array.
        if (i != type(uint256).max) {
            Vault memory vault;
            vault.vault = _vaultB;
            vault.allocation = _allocationTo;
            newAllocation = _allocationTo;
            s.vaults[_cofi].push(vault);
        }

        LibToken._poke(_cofi); // Sync cofi token supply to assets in vault.

        emit LibVault.VaultAllocationUpdated(
            _vaultB,
            newAllocation
        );
        return true;
    }

    function rebalance(
        address _cofi
    )   external
        onlyUpkeepOrAdmin
        returns (bool)
    {
        uint256 oldAssets;
        // First, pull funds from all vaults.
        for (uint i = 0; i < s.vaults[_cofi].length; i++) {
            oldAssets += IERC4626(s.vaults[_cofi][i].vault).redeem(
                IERC20(s.vaults[_cofi][i].vault).balanceOf(address(this)),
                address(this),
                address(this)
            );
        }

        address underlying = IERC4626(s.vaults[_cofi][0].vault).asset();
        uint256 newAssets;
        // Second, redeploy assets with vaults' respective allocations.
        for (uint i = 0; i < s.vaults[_cofi].length; i++) {
            uint256 assets = oldAssets.percentMul(s.vaults[_cofi][i].allocation);
            SafeERC20.safeApprove(
                IERC20(underlying),
                s.vaults[_cofi][i].vault,
                assets + s.buffer[underlying]
            );
            newAssets += LibVault._getAssets(
                LibVault._wrap(
                    assets + s.buffer[underlying],
                    s.vaults[_cofi][i].vault
                ),
                s.vaults[_cofi][i].vault
            );
        }
        require(
            LibToken._toCofiDecimals(underlying, newAssets) >=
                LibToken._toCofiDecimals(underlying, oldAssets),
            'VaultManagerFacet: Vaults migration slippage exceeded'
        );
        emit LibVault.Rebalance(_cofi);

        LibToken._poke(_cofi);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                            Admin - Setters
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev The buffer is an amount of underlying that resides at this contract for the purpose
     *      of ensuring a successful migration. This is because a rebase must execute to "sync"
     *      balances, which can only occur if the new supply is greater than the previous supply.
     *      Because withdrawals may incur slippage, therefore, need to overcome this.
     */
    function setBuffer(
        address _underlying,
        uint256 _buffer
    )   external
        onlyAdmin
        returns (bool)
    {
        s.buffer[_underlying] = _buffer;
        return true;
    }

    function setDecimals(
        address _underlying,
        uint8   _decimals
    )   external
        returns (bool)
    {
        s.decimals[_underlying] = _decimals;
        return true;
    }

    /// @dev Only for setting up a new cofi token. 'migrateVault()' must be used otherwise.
    function setVaults(
        address _cofi,
        Vault[] calldata _vaults
    )   external
        onlyAdmin
        returns (bool)
    {
        require(
            s.vaults[_cofi].length == 0,
            'VaultManagerFacet: Setting vaults requires no previous vaults attached'
        );
        s.vaults[_cofi] = _vaults;
        return true;
    }

    function setRebasePublic(
        address _cofi,
        uint8   _enabled
    )   external
        onlyAdmin
        returns (bool)
    {
        s.rebasePublic[_cofi] = _enabled;
        return true;
    }

    function setHarvestable(
        address _vault,
        uint8   _enabled
    )   external
        onlyAdmin
        returns (bool)
    {
        s.harvestable[_vault] = _enabled;
        return true;
    }

    /// @notice Ops this contract into receiving yield on holding of cofi tokens.
    function rebaseOptIn(
        address _cofi
    )   external
        onlyAdmin
        returns (bool)
    {
        LibToken._rebaseOptIn(_cofi);
        return true;
    }

    function rebaseOptOut(
        address _cofi
    )   external
        onlyAdmin
        returns (bool)
    {
        LibToken._rebaseOptOut(_cofi);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                                Getters
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  Returns the total assets held within all vaults for a given cofi token.
     *          This value should therefore closely mirror the cofi token's total supply.
     * @dev Should match index with vault to determine amount for that vault.
     * @param _cofi The cofi token to enquire for.
     */
    function getTotalAssets(
        address _cofi
    )   external view
        returns (uint256[] memory assets)
    {
        for (uint i = 0; i < s.vaults[_cofi].length; i++) {
            assets[i] = LibVault._totalValue(s.vaults[_cofi][i].vault);
        }
    }

    /// @notice Returns a list of vaults and their allocations for a given cofi token.
    function getVaults(
        address _cofi
    )   external view
        returns (Vault[] memory vaults)
    {
        return s.vaults[_cofi];
    }

    /**
     * @notice  Returns the 'buffer' for an underlying, which is an amount of tokens that
     *          resides at this contract for the purpose of executing migrations.
     *          This is because the new cofi token supply must "sync" to the new assets by
     *          rebasing, which can only occur if there are more assets than previously captured.
     */
    function getBuffer(
        address _underlying
    )   external view
        returns (uint256)
    {
        return s.buffer[_underlying];
    }

    /// @notice Indicates if rebases can be called by any account for a given cofi token.
    function getRebasePublic(
        address _cofi
    )   external view
        returns (uint8)
    {
        return s.rebasePublic[_cofi];
    }

    /**
     * @notice  Indicates if the vault has a 'harvest()' function, which executes some action
     *          (e.g., reinvest staking rewards) prior to rebasing.
     */
    function getHarvestable(
        address _vault
    )   external view
        returns (uint8)
    {
        return s.harvestable[_vault];
    }

    function getDecimals(
        address _underlying
    )   external view
        returns (uint8)
    {
        return s.decimals[_underlying];
    }
}