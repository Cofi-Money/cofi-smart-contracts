// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AppStorage, LibAppStorage } from './LibAppStorage.sol';
import { IERC4626 } from '.././interfaces/IERC4626.sol';

library LibVault {

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a wrap operation is executed.
    ///
    /// @param amount   The amount of assets wrapped.
    /// @param sender   The account executing the wrap operation.
    /// @param vault    The ERC4626 Vault.
    /// @param shares   The amount of shares minted.
    event Wrap(uint256 amount, address indexed sender, address indexed vault, uint256 shares);

    /// @notice Emitted when an unwrap operation is executed.
    ///
    /// @param amount   The amount of shares unwrapped.
    /// @param sender   The account executing the wrap operation.
    /// @param vault    The ERC4626 Vault.
    /// @param assets   The amount of assets redeemed.
    event Unwrap(uint256 amount, address indexed sender, address indexed vault, uint256 assets);

    /// @notice Emitted when a vault migration is executed.
    ///
    /// @param cofi         The cofi token to migrate assets for.
    /// @param vault        The vault migrated from.
    /// @param newVault     The vault migrated to.
    /// @param assets       The amount of assets pre-migration.
    /// @param newAssets    The amount of assets post-migration.
    event VaultMigration(
        address indexed cofi,
        address indexed vault,
        address indexed newVault,
        uint256 assets,
        uint256 newAssets
    );

    /// @notice Emitted when a harvest operation is executed (usually immediately prior to a rebase).
    ///
    /// @param cofi     The cofi token being harvested for.
    /// @param vault    The actual vault where the harvest operation resides.
    /// @param assets   The amount of assets deposited.
    event Harvest(address indexed cofi, address indexed vault, uint256 assets);

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the number of assets from shares of a given vault.
    ///
    /// @param _shares  The number of shares to convert (e.g., yvUSDC => USDC).
    /// @param _vault   The relevant vault to convert via.
    function _getAssets(
        uint256 _shares,
        address _vault
    ) internal view returns (uint256 assets) {

        return IERC4626(_vault).previewRedeem(_shares);
    }

    /// @notice Returns the number of shares from assets for a given vault.
    ///
    /// @param _assets  The number of assets to convert (e.g., USDC => yvUSDC).
    /// @param _vault   The relevant vault to convert via.
    function _getShares(
        uint256 _assets,
        address _vault
    ) internal view returns (uint256 shares) {

        return IERC4626(_vault).previewDeposit(_assets);
    }

    /// @notice Gets total value of Diamond's holding of shares from the relevant vault.
    ///
    /// @param _vault The vault to enquire for.
    function _totalValue(
        address _vault
    ) internal view returns (uint256 assets) {

        return IERC4626(_vault).maxWithdraw(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                            STATE CHANGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Wraps an underlying token into corresponding shares.
    ///
    /// @param  _amount The amount of underlying tokens to wrap.
    /// @param  _vault  The ERC4626 Vault.
    function _wrap(
        uint256 _amount,
        address _vault
    ) internal returns (uint256 shares) {

        shares = IERC4626(_vault).deposit(_amount, address(this));
        emit Wrap(_amount, msg.sender, _vault, shares);
    }

    /// @notice Unwraps shares into underlying tokens via the relevant Vault.
    ///
    /// @param  _amount     The amount of cofi tokens to redeem (target 1:1 correlation to underlying tokens).
    /// @param  _vault      The ERC4626 Vault.
    /// @param  _recipient  The recipient of the underlying tokens.
    function _unwrap(
        uint256 _amount,
        address _vault,
        address _recipient
    ) internal returns (uint256 assets) {

        // Retrieve the corresponding number of shares for the amount of cofi tokens provided.
        uint256 shares = IERC4626(_vault).previewDeposit(_amount);

        assets = IERC4626(_vault).redeem(shares, _recipient, address(this));
        emit Unwrap(_amount, msg.sender, _vault, shares);
    }

    /// @notice Executes a harvest operation in the vault contract.
    ///
    /// @param _cofi The cofi token to harvest for.
    function _harvest(
        address _cofi
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 assets = IERC4626(s.vault[_cofi]).harvest();
        if (assets == 0) return;
        emit Harvest(_cofi, s.vault[_cofi], assets);
    }
}