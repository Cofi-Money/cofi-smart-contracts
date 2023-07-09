// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AppStorage, LibAppStorage } from "./LibAppStorage.sol";
import { IERC4626 } from ".././interfaces/IERC4626.sol";

library LibVault {

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a wrap operation is executed.
    ///
    /// @param  amount      The amount of underlyingAssets wrapped.
    /// @param  depositFrom The account which supplied the underlyingAssets.
    /// @param  vault       The ERC4626 Vault.
    /// @param  shares      The amount of shares minted.
    event Wrap(uint256 amount, address indexed depositFrom, address indexed vault, uint256 shares);

    /// @notice Emitted when an unwrap operation is executed.
    ///
    /// @param  amount      The amount of fiAssets redeemed.
    /// @param  shares      The amount of shares burned.
    /// @param  vault       The ERC4626 Vault.
    /// @param  assets      The amount of underlyingAssets received from the Vault.
    /// @param  recipient   The recipient of the underlyingAssets.
    event Unwrap(uint256 amount, uint256 shares, address indexed vault, uint256 assets, address indexed recipient);

    /// @notice Emitted when a vault migration is executed.
    ///
    /// @param  fiAsset     The fiAsset to migrate underlyingAssets for.
    /// @param  oldVault    The vault migrated from.
    /// @param  newVault    The vault migrated to.
    /// @param  oldAssets   The amount of assets pre-migration.
    /// @param  newAssets   The amount of assets post-migration.
    event VaultMigration(address indexed fiAsset, address indexed oldVault, address indexed newVault, uint256 oldAssets, uint256 newAssets);

    /// @notice Emitted when a harvest operation is executed (usually immediately prior to a rebase).
    ///
    /// @param fiAsset  The fiAsset being harvested for.
    /// @param vault    The actual vault where the harvest operation resides.
    /// @param assets   The amount of assets deposited.
    /// @param shares   The amount of shares returned from the deposit operation.
    event Harvest(address indexed fiAsset, address indexed vault, uint256 assets, uint256 shares);

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function _getAssets(
        uint256 shares,
        address vault
    ) internal view returns (uint256 assets) {

        assets = IERC4626(vault).previewRedeem(shares);
    }

    function _getShares(
        uint256 assets,
        address vault
    ) internal view returns (uint256 shares) {

        shares = IERC4626(vault).previewDeposit(assets);
    }

    /// @notice Gets total value of Diamond's holding of shares from the relevant Vault.
    function _totalValue(
        address vault
    ) internal returns (uint256 assets) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // I.e., if vault is using a derivative.
        if (s.derivParams[vault].toUnderlying != 0) {
            // Sets RETURN_ASSETS to equivalent number of underlying.
            (bool success, ) = address(this).call(abi.encodeWithSelector(
                s.derivParams[vault].convertToUnderlying,
                IERC4626(vault).maxWithdraw(address(this))
            ));
            require(success, 'LibVault: Convert to underlying operation failed');
            assets = s.RETURN_ASSETS;
            s.RETURN_ASSETS = 0;
        }
        else assets = IERC4626(vault).maxWithdraw(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                            STATE CHANGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Wraps an underlyingAsset into shares via a Vault.
    /// @dev    Shares reside at the Diamond at all times.
    ///
    /// @param  amount      The amount of underlyingAssets to wrap.
    /// @param  vault       The ERC4626 Vault.
    /// @param  depositFrom The account supplying underlyingAssets from.
    function _wrap(
        uint256 amount,
        address vault,
        address depositFrom
    ) internal returns (uint256 shares) {

        shares = IERC4626(vault).deposit(amount, address(this));
        emit Wrap(amount, depositFrom, vault, shares);
    }

    /// @notice Unwraps shares into underlyingAssets via the relevant Vault.
    ///
    /// @param  amount      The amount of fiAssets to redeem (target 1:1 correlation to underlyingAssets).
    /// @param  vault       The ERC4626 Vault.
    /// @param  recipient   The recipient of the underlyingAssets.
    function _unwrap(
        uint256 amount,
        address vault,
        address recipient
    ) internal returns (uint256 assets) {

        // Retrieve the corresponding number of shares for the amount of fiAssets provided.
        uint256 shares = IERC4626(vault).previewDeposit(amount);    // Need to convert from USDC to USDC-LP

        assets = IERC4626(vault).redeem(shares, recipient, address(this));
        emit Unwrap(amount, shares, vault, assets, recipient);
    }

    function _harvest(
        address fiAsset
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        (uint256 assets, uint256 shares) = IERC4626(s.vault[fiAsset]).harvest();
        if (assets == 0 || shares == 0) return;
        emit Harvest(fiAsset, s.vault[fiAsset], assets, shares);
    }
}