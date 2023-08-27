// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AppStorage, LibAppStorage } from './LibAppStorage.sol';
import { LibToken } from './LibToken.sol';
import { StableMath } from './external/StableMath.sol';
import { PercentageMath } from './external/PercentageMath.sol';
import { IERC4626 } from '.././interfaces/IERC4626.sol';

library LibVault {
    using PercentageMath for uint256;
    using StableMath for uint256;

    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a wrap operation is executed.
     * @param vault     The ERC4626 vault deposited assets into. 
     * @param assets    The amount of assets wrapped.
     * @param shares    The amount of shares received.
     */
    event Wrap(address indexed vault, uint256 assets, uint256 shares);

    /**
     * @notice Emitted when an unwrap operation is executed.
     * @param vault     The ERC4626 vault shares were redeemeed from.
     * @param assets    The amount of assets redeemed.
     * @param shares    The amount of shares unwrapped.
     */
    event Unwrap(address indexed vault, uint256 assets, uint256 shares);

    /**
     * @notice Emitted when a vault's asset allocation is reduced.
     * @param vault         The reduced vault.
     * @param allocation    The new asset allocation of the vault.
     */
    event VaultAllocationUpdated(address indexed vault, uint256 allocation);

    /**
     * @notice Emitted when the vaults' assets for a cofi token are rebalanced.
     * @param cofi The cofi token whose backing assets were rebalanced for.
     */
    event Rebalance(address indexed cofi);

    /**
     * @notice Emitted when a harvest operation is executed (usually immediately prior to a rebase).
     * @param vault     The actual vault where the harvest operation resides.
     * @param assets    The amount of assets harvested.
     */
    event Harvest(address indexed vault, uint256 assets);

    /*//////////////////////////////////////////////////////////////
                            Vault Interactions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Wraps an underlying token into shares via the vault provided.
     * @param _amount   The amount of underlying tokens to wrap.
     * @param _vault    The ERC4626 vault to wrap via.
     */
    function _wrap(
        uint256 _amount,
        address _vault
    )   internal
        returns (uint256 shares)
    {
        shares = IERC4626(_vault).deposit(_amount, address(this));
        emit Wrap(_vault, _amount, shares);
    }

    /**
     * @notice Unwraps shares into underlying tokens via the vault provided.
     * @param _amount       The amount of cofi tokens to redeem (target 1:1 correlation to vault assets).
     * @param _vault        The ERC4626 vault.
     * @param _recipient    The account receiving underlying tokens.
     */
    function _unwrap(
        uint256 _amount,
        address _vault,
        address _recipient
    )   internal
        returns (uint256 assets)
    {
        // Retrieve the corresponding number of shares for the amount of cofi tokens provided.
        uint256 shares = IERC4626(_vault).previewDeposit(_amount);

        assets = IERC4626(_vault).redeem(shares, _recipient, address(this));
        emit Unwrap(_vault, shares, assets);
    }

    /**
     * @notice Executes a harvest operation in the vault contract.
     * @param _vault The vault to harvest (must contain harvest function).
     */
    function _harvest(
        address _vault
    )   internal
    {
        uint256 assets = IERC4626(_vault).harvest();
        if (assets == 0) return;
        emit Harvest(_vault, assets);
    }

    /*//////////////////////////////////////////////////////////////
                                Getters
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the number of assets from shares of a given vault.
    function _getAssets(
        uint256 _shares,
        address _vault
    )   internal view
        returns (uint256 assets)
    {
        return IERC4626(_vault).previewRedeem(_shares);
    }

    /// @notice Returns the number of shares from assets for a given vault.
    function _getShares(
        uint256 _assets,
        address _vault
    )   internal view
        returns (uint256 shares)
    {
        return IERC4626(_vault).previewDeposit(_assets);
    }

    /// @notice Gets total value of this contract's holding of shares from the relevant vault.
    function _totalValue(
        address _vault
    )   internal view
        returns (uint256 assets)
    {
        return IERC4626(_vault).maxWithdraw(address(this));
    }

    // function _getAllocations(
    //     address _cofi
    // )   internal view
    //     returns (uint256[] memory)
    // {
    //     AppStorage storage s = LibAppStorage.diamondStorage();

    //     // Determine allocation of underlying assets.
    //     address[] memory assets = new address[](s.vaults[_cofi].length);

    // }

    // function _getDeficit(
    //     address _cofi
    // )   internal view
    //     returns (address target)
    // {
    //     AppStorage storage s = LibAppStorage.diamondStorage();

    //     uint256[] memory assets = new uint256[](s.vaults[_cofi].length);
    //     uint256 assetsTotal;

    //     for(uint i = 0; i < s.vaults[_cofi].length; i++) {
    //         assets[i] = LibToken._toCofiDecimals(
    //             IERC4626(s.vaults[_cofi][i].vault).asset(),
    //             _totalValue(s.vaults[_cofi][i].vault)
    //         );
    //         assetsTotal += assets[i];
    //     }

    //     uint256[] memory allocations = new uint256[](assets.length);
    //     uint256 allocation;
    //     uint256 targetAllocation;
    //     target = s.vaults[_cofi][0].vault;

    //     // Return whichever is the smallest relative to target allocation.
    //     for(uint i = 1; i < assets.length; i++) {
    //         allocation = assets[i].divPrecisely(assetsTotal);
    //         targetAllocation = assets[i].percentMul(s.vaults[_cofi][i].allocation);
    //     }
    // }
}