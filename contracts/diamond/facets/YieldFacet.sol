// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers } from '../libs/LibAppStorage.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibSwap } from '../libs/LibSwap.sol';
import { LibReward } from '../libs/LibReward.sol';
import { LibVault } from '../libs/LibVault.sol';
import { IERC4626 } from '../interfaces/IERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Yield Facet
    @notice Provides logic for distributing and managing yield.
 */

contract YieldFacet is Modifiers {

    /*//////////////////////////////////////////////////////////////
                            YIELD DISTRIBUTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Function for updating cofi token supply relative to vault earnings.
    ///
    /// @param  _cofi The cofi token to distribute yield earnings for.
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
                            ASSET MIGRATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Function for migrating to a new Vault. The new Vault must support the
    ///         same underlying token (e.g., USDC).
    ///
    /// @dev    Ensure that a buffer of the underlying token resides in the Diamond
    ///         beforehand to account for slippage.
    ///
    /// @param  _cofi       The cofi token to migrate vault backing for.
    /// @param  _newVault   The vault to migrate to (must adhere to ERC4626).
    function migrate(
        address _cofi,
        address _newVault
    )   external
        returns (bool)
    {
        // Pull funds from old vault.
        uint256 assets = IERC4626(s.vault[_cofi]).redeem(
            IERC20(s.vault[_cofi]).balanceOf(address(this)),
            address(this),
            address(this)
        );

        /**
         * @dev Upgraded logic to swap for new underlying {Upgrade 1}.
         * @dev Only support single swaps for now, hence take first/only element.
         * @dev Need to ensure that (A) SwapParams have been set for from-to mapping and;
         * @dev (B) _to asset's decimals are already set (e.g., DAI => 18) and;
         * @dev (C) 'buffer' is set for new underlying and resides at this address and;
         * @dev (D) 'harvestable' bool is indicated for new vault if required.
         */
        if (IERC4626(s.vault[_cofi]).asset() != IERC4626(_newVault).asset()) {
            assets = LibSwap._velodromeV2SwapStable(
                IERC4626(s.vault[_cofi]).asset(),
                IERC4626(_newVault).asset(),
                assets
            )[0];
            // Update underlying for cofi token.
            s.underlying[_cofi] = IERC4626(_newVault).asset();
        }

        // Approve _newVault spend for Diamond.
        SafeERC20.safeApprove(
            IERC20(IERC4626(_newVault).asset()),
            _newVault,
            assets + s.buffer[s.underlying[_cofi]] // Amended {Upgrade 1}.
        );

        // Deploy funds to new vault.
        LibVault._wrap(
            assets + s.buffer[s.underlying[_cofi]], // Amended {Upgrade 1}.
            _newVault,
            address(this)
        );

        require(
            // Vaults use same asset, therefore same decimals.
            assets <= LibVault._totalValue(_newVault),
            'YieldFacet: Vault migration slippage exceeded'
        );
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
                            ADMIN - SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @dev    The buffer is an amount of underlying that resides at this contract for the
    ///         purpose of ensuring a successful migration. This is because a rebase
    ///         must execute to "sync" balances, which can only occur if the new supply is
    ///         greater than the previous supply. Because withdrawals may incur slippage,
    ///         therefore, need to overcome this.
    function setBuffer(
        address _cofi,
        uint256 _buffer
    )   external
        onlyAdmin
        returns (bool)
    {
        s.buffer[_cofi] = _buffer;
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
        require(
            s.vault[_cofi] == address(0),
            'YieldFacet: cofi token must not already link with a vault'
        );
        s.vault[_cofi] = _vault;
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

    /// @notice Opts the diamond into receiving yield on holding of cofi tokens (which fees
    ///         are captured in). Note that the feeCollector is a separate contract.
    ///         By default, elect to not activate (thereby passing on yield to holders).
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
                            ADMIN - GETTERS
    //////////////////////////////////////////////////////////////*/

    function getBuffer(
        address _cofi
    )   external
        view
        returns (uint256)
    {
        return s.buffer[_cofi];
    }

    function getRebasePublic(
        address _cofi
    )   external
        view
        returns (uint8)
    {
        return s.rebasePublic[_cofi];
    }

    function getHarvestable(
        address _vault
    )   external
        view
        returns (uint8)
    {
        return s.harvestable[_vault];
    }

    /*//////////////////////////////////////////////////////////////
                            {Upgrade 1}
                Added logic to swap underlying for cofi token
    //////////////////////////////////////////////////////////////*/

    function setSwapParams(
        address _from,
        address _to,
        uint256 _slippage,
        uint256 _wait
    )   external
        returns (bool)
    {
        s.swapParams[_from][_to].slippage = _slippage;
        s.swapParams[_from][_to].wait = _wait;
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

    function getSwapParams(
        address _from,
        address _to
    )   external view
        returns (uint256, uint256)
    {
        return (
            s.swapParams[_from][_to].slippage,
            s.swapParams[_from][_to].wait
        );
    }

    function getDecimals(
        address _underlying
    )   external view
        returns (uint8)
    {
        return s.decimals[_underlying];
    }
}