// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SwapProtocol, Modifiers } from '../libs/LibAppStorage.sol';
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
                'VaultManagerFacet: Caller not Upkeep or Admin'
            );
        return LibToken._poke(_cofi);
    }

    /*//////////////////////////////////////////////////////////////
                            Asset Migration
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Migrates assets to '_newVault'.
     * @dev Ensure that a buffer of the relevant underlying token resides at this contract
     *      before executing to account for slippage.
     * @param _cofi     The cofi token to migrate underlying tokens for.
     * @param _newVault The new ERC4626 vault.
     */
    function migrate(
        address _cofi,
        address _newVault
    )   external
        returns (bool)
    {
        require(
            s.isUpkeep[msg.sender] == 1 || s.isAdmin[msg.sender] == 1,
            'VaultManagerFacet: Caller not Upkeep or Admin'
        );
        require(
            s.migrationEnabled[s.vault[_cofi]][_newVault] == 1,
            'VaultManagerFacet: Migration from current vault to new vault disabled'
        );

        // Pull funds from old vault.
        uint256 assets = IERC4626(s.vault[_cofi]).redeem(
            IERC20(s.vault[_cofi]).balanceOf(address(this)),
            address(this),
            address(this)
        );

        address underlying = IERC4626(s.vault[_cofi]).asset();

        /**
         * @notice Logic to switch underlying token if new vault accepts another asset.
         * @dev Need to ensure that (A) swap params have been set and;
         *      (B) _to asset's decimals have been set and;
         *      (C) 'buffer' is set for new underlying and resides at this address and;
         *      (D) 'harvestable' bool is indicated for new vault if required.
         */
        if (underlying != IERC4626(_newVault).asset()) {
            address newUnderlying = IERC4626(_newVault).asset();
            require(
                s.swapProtocol[underlying][newUnderlying] != SwapProtocol(0),
                'VaultManagerFacet: Swap route not set for migration'
            );
            assets = LibSwap._swapERC20ForERC20(
                assets,
                underlying,
                newUnderlying,
                address(this)
            );
            underlying = newUnderlying;
        }

        // Approve '_newVault' spend for this contract.
        SafeERC20.safeApprove(
            IERC20(IERC4626(_newVault).asset()),
            _newVault,
            assets + s.buffer[underlying]
        );

        // Deploy funds to new vault.
        LibVault._wrap(
            assets + s.buffer[underlying],
            _newVault
        );

        uint256 newAssets = LibVault._totalValue(_newVault);
        /// @dev No need to convert decimals as both values denominated in same asset.
        require(assets <= newAssets, 'VaultManagerFacet: Vault migration slippage exceeded');

        emit LibVault.VaultMigration(
            _cofi,
            s.vault[_cofi],
            _newVault,
            assets,
            LibVault._totalValue(_newVault)
        );

        s.vault[_cofi] = _newVault; // Update vault for cofi token.

        LibToken._poke(_cofi); // Sync cofi token supply to assets in vault.

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

    function setMigrationEnabled(
        address _vaultA,
        address _vaultB,
        uint8   _enabled
    )   external
        onlyAdmin
        returns (bool)
    {
        s.migrationEnabled[_vaultA][_vaultB] = _enabled;
        return true;
    }

    /// @dev Only for setting up a new cofi token. 'migrateVault()' must be used otherwise.
    function setVault(
        address _cofi,
        address _vault
    )   external
        onlyAdmin
        returns (bool)
    {
        require(s.vault[_cofi] == address(0), 'VaultManagerFacet: Vault already set');
        s.vault[_cofi] = _vault;
        return true;
    }

    function setRateLimit(
        address _cofi,
        uint256 _rateLimit
    )   external
        onlyAdmin
        returns (bool)
    {
        s.rateLimit[_cofi] = _rateLimit;
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
     * @notice  Returns the total assets held within the vault for a given cofi token.
     *          This value should therefore closely mirror the cofi token's total supply.
     * @param _cofi The cofi token to enquire for.
     */
    function getTotalAssets(
        address _cofi
    )   external view
        returns (uint256 assets)
    {
        return LibVault._totalValue(s.vault[_cofi]);
    }

    function getVault(
        address _cofi
    )   external view
        returns (address vault)
    {
        return s.vault[_cofi];
    }

    function getRateLimit(
        address _cofi
    )   external view
        returns (uint256)
    {
        return s.rateLimit[_cofi];
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
}