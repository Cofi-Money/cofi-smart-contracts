// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers } from '../libs/LibAppStorage.sol';
import { IERC4626 } from '../interfaces/IERC4626.sol';

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Supply Manager Facet
    @notice Admin functions for managing asset params.
 */

contract SupplyManagerFacet is Modifiers {

    /*//////////////////////////////////////////////////////////////
                            Admin - Setters
    //////////////////////////////////////////////////////////////*/

    /// @dev Set cofi token vars first BEFORE onboarding (refer to LibAppStorage.sol).
    function onboardAsset(
        address _cofi,
        address _vault
    )   external
        onlyAdmin
        returns (bool)
    {
        s.vault[_cofi] = _vault;
        s.decimals[_cofi] = 18;
        /// @dev Ensure decimals of underlying is already set.
        s.decimals[_vault] = s.decimals[IERC4626(s.vault[_cofi]).asset()];
        return true;
    }

    function setDecimals(
        address _asset,
        uint8   _decimals
    )   external
        returns (bool)
    {
        s.decimals[_asset] = _decimals;
        return true;
    }

    /// @notice 'minDeposit' applies to the amount of underlying tokens required for deposit.
    function setMinDeposit(
        address _cofi,
        uint256 _underlyingInMin
    )   external
        onlyAdmin
        returns (bool)
    {
        s.minDeposit[_cofi] = _underlyingInMin;
        return true;
    }

    /// @notice 'minWithdraw' applies to the amount of underlying tokens redeemed.
    function setMinWithdraw(
        address _cofi,
        uint256 _underlyingOutMin
    )   external
        onlyAdmin
        returns (bool)
    {
        s.minWithdraw[_cofi] = _underlyingOutMin;
        return true;
    }

    function setMintFee(
        address _cofi,
        uint256 _amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.mintFee[_cofi] = _amount;
        return true;
    }

    function setMintEnabled(
        address _cofi,
        uint8   _enabled
    )   external
        onlyAdmin
        returns (bool)
    {
        s.mintEnabled[_cofi] = _enabled;
        return true;
    }

    function setRedeemFee(
        address _cofi,
        uint256 _amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.redeemFee[_cofi] = _amount;
        return true;
    }

    function setRedeemEnabled(
        address _cofi,
        uint8   _enabled
    )   external
        onlyAdmin
        returns (bool)
    {
        s.redeemEnabled[_cofi] = _enabled;
        return true;
    }

    function setServiceFee(
        address _cofi,
        uint256 _amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.serviceFee[_cofi] = _amount;
        return true;
    }

    function setSupplyLimit(
        address _cofi,
        uint256 _supplyLimit
    )   external
        onlyAdmin
        returns (bool)
    {
        s.supplyLimit[_cofi] = _supplyLimit;
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                                Getters
    //////////////////////////////////////////////////////////////*/
    
    function getDecimals(
        address _asset
    )   external view
        returns (uint8)
    {
        return s.decimals[_asset];
    }

    function getMinDeposit(
        address _cofi
    )   external view
        returns (uint256)
    {
        return s.minDeposit[_cofi];
    }

    function getMinWithdraw(
        address _cofi
    )   external view
        returns (uint256)
    {
        return s.minWithdraw[_cofi];
    }

    function getMintFee(
        address _cofi
    )   external view
        returns (uint256)
    {
        return s.mintFee[_cofi];
    }

    function getMintEnabled(
        address _cofi
    )   external view
        returns (uint8)
    {
        return s.mintEnabled[_cofi];
    }

    function getRedeemFee(
        address _cofi
    )   external view
        returns (uint256)
    {
        return s.redeemFee[_cofi];
    }

    function getRedeemEnabled(
        address _cofi
    )   external view
        returns (uint8)
    {
        return s.redeemEnabled[_cofi];
    }

    function getServiceFee(
        address _cofi
    )   external view
        returns (uint256)
    {
        return s.serviceFee[_cofi];
    }

    function getSupplyLimit(
        address _cofi
    )   external view
        returns (uint256)
    {
        return s.supplyLimit[_cofi];
    }

    function getUnderlying(
        address _cofi
    )   external view
        returns (address)
    {
        return IERC4626(s.vault[_cofi]).asset();
    }
}