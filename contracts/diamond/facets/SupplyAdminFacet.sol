// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers } from '../libs/LibAppStorage.sol';
import { IERC4626 } from '.././interfaces/IERC4626.sol';

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Supply Admin Facet
    @notice Separated admin setters and views for SupplyFacet.
 */

contract SupplyAdminFacet is Modifiers {

    /*//////////////////////////////////////////////////////////////
                            ADMIN - SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @dev    Set COFI stablecoin vars first before onboarding (refer to LibAppStorage.sol).
    function onboardAsset(
        address _fi,
        address _underlying,
        address _vault
    )   external
        onlyAdmin
        returns (bool)
    {
        s.underlying[_fi] = _underlying;
        s.vault[_fi] = _vault;
        return true;
    }

    /// @notice "minDeposit" applies to the amount of underlying tokens required for deposit.
    function setMinDeposit(
        address _fi,
        uint256 _underlyingInMin
    )   external
        onlyAdmin
        returns (bool)
    {
        s.minDeposit[_fi] = _underlyingInMin;
        return true;
    }

    /// @notice "minWithdraw" applies to the amount of underlying tokens redeemed.
    function setMinWithdraw(
        address _fi,
        uint256 _underlyingOutMin
    )   external
        onlyAdmin
        returns (bool)
    {
        s.minWithdraw[_fi] = _underlyingOutMin;
        return true;
    }

    function setMintFee(
        address _fi,
        uint256 _amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.mintFee[_fi] = _amount;
        return true;
    }

    function setMintEnabled(
        address _fi,
        uint8   _enabled
    )   external
        onlyAdmin
        returns (bool)
    {
        s.mintEnabled[_fi] = _enabled;
        return true;
    }

    function setRedeemFee(
        address _fi,
        uint256 _amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.redeemFee[_fi] = _amount;
        return true;
    }

    function setRedeemEnabled(
        address _fi,
        uint8   _enabled
    )   external
        onlyAdmin
        returns (bool)
    {
        s.redeemEnabled[_fi] = _enabled;
        return true;
    }

    function setServiceFee(
        address _fi,
        uint256 _amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.serviceFee[_fi] = _amount;
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN - GETTERS
    //////////////////////////////////////////////////////////////*/

    function getMinDeposit(
        address _fi
    )   external
        view
        returns (uint256)
    {
        return s.minDeposit[_fi];
    }

    function getMinWithdraw(
        address _fi
    )   external
        view
        returns (uint256)
    {
        return s.minWithdraw[_fi];
    }

    function getMintFee(
        address _fi
    )   external
        view
        returns (uint256)
    {
        return s.mintFee[_fi];
    }

    function getMintEnabled(
        address _fi
    )   external
        view
        returns (uint8)
    {
        return s.mintEnabled[_fi];
    }

    function getRedeemFee(
        address _fi
    )   external
        view
        returns (uint256)
    {
        return s.redeemFee[_fi];
    }

    function getRedeemEnabled(
        address _fi
    )   external
        view
        returns (uint8)
    {
        return s.redeemEnabled[_fi];
    }

    function getServiceFee(
        address _fi
    )   external
        view
        returns (uint256)
    {
        return s.serviceFee[_fi];
    }

    /// @notice Returns the underlying token for a given fi token.
    function getUnderlying(
        address _fi
    )   external
        view
        returns (address)
    {
        return IERC4626(s.vault[_fi]).asset();
    }

    /// @notice Returns the vault for a given fi token.
    function getVault(
        address _fi
    )   external
        view
        returns (address)
    {
        return s.vault[_fi];
    }
}