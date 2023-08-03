// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers } from '../libs/LibAppStorage.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibReward } from '../libs/LibReward.sol';
import { LibVault } from '../libs/LibVault.sol';
import { IERC4626 } from '.././interfaces/IERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import 'hardhat/console.sol';

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Supply Facet
    @notice User-operated functions for minting/redeeming fi tokens.
            Backing assets are deployed to the respective vault as per schema.
 */

contract SupplyFacet is Modifiers {

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT & WITHDRAW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Converts a supported underlying token into a fi token (e.g., USDC to fiUSD).
    ///
    /// @param  _underlyingIn   The amount of underlying tokens to deposit.
    /// @param  _fiOutMin       The minimum amount of fi tokens received (before fees).
    /// @param  _fi             The fi token to mint.
    /// @param  _depositFrom    The account to deposit underlying tokens from.
    /// @param  _recipient      The recipient of the fi tokens.
    /// @param  _referral       The referral account (address(0) if none provided).
    function underlyingToFi(
        uint256 _underlyingIn,
        uint256 _fiOutMin,
        address _fi,
        address _depositFrom,
        address _recipient,
        address _referral
    )   external
        nonReentrant isWhitelisted mintEnabled(_fi) minDeposit(_underlyingIn, _fi)
        returns (uint256 mintAfterFee)
    {
        // Preemptively rebases if enabled.
        if (s.rebasePublic[_fi] == 1) LibToken._poke(_fi);

        // Transfer underlying to this contract first to prevent user having to 
        // approve 1+ vaults (if/when the vault used changes, upon revisiting platform).
        LibToken._transferFrom(
            s.underlying[_fi],
            _underlyingIn,
            _depositFrom,
            address(this)
        );
        
        SafeERC20.safeApprove(
            IERC20(IERC4626(s.vault[_fi]).asset()),
            s.vault[_fi],
            _underlyingIn
        );

        uint256 assets = LibToken._toFiDecimals(
            _fi,
            LibVault._getAssets(
                LibVault._wrap(
                    _underlyingIn,
                    s.vault[_fi],
                    _depositFrom // Purely for Event emission. Wraps from Diamond.
                ),
                s.vault[_fi]
            )
        );

        require(assets >= _fiOutMin, 'SupplyFacet: Slippage exceeded');

        uint256 fee = LibToken._getMintFee(_fi, assets);
        mintAfterFee = assets - fee;

        // Capture mint fee in fi tokens.
        if (fee > 0) {
            LibToken._mint(_fi, s.feeCollector, fee);
        }
        LibToken._mintOptIn(_fi, _recipient, mintAfterFee);

        // Distribute rewards.
        LibReward._initReward();
        if (_referral != address(0)) {
            LibReward._referReward(_referral);
        }

        emit LibToken.Deposit(s.underlying[_fi], _underlyingIn, _depositFrom, fee);
    }

    /// @notice Converts a fi token to its collateral underlying token (e.g., fiUSD to USDC).
    ///
    /// @notice Can be used to make payments in the underlying token in one tx (e.g., transfer
    ///         USDC directly from fiUSD).
    ///
    /// @param  _fiIn               The amount of fi tokens to redeem.
    /// @param  _underlyingOutMin   The minimum amount of underlying tokens received (AFTER fees).
    /// @param  _fi                 The fi token to redeem (e.g., fiUSD).
    /// @param  _depositFrom        The account to deposit fi tokens from.
    /// @param  _recipient          The recipient of the underlying tokens.
    function fiToUnderlying(
        uint256 _fiIn,
        uint256 _underlyingOutMin,
        address _fi,
        address _depositFrom,
        address _recipient
    )   external
        nonReentrant isWhitelisted redeemEnabled(_fi) minWithdraw(_fiIn, _fi)
        returns (uint256 burnAfterFee)
    {
        LibToken._transferFrom(_fi, _fiIn, _depositFrom, s.feeCollector);

        uint256 fee = LibToken._getRedeemFee(_fi, _fiIn);
        burnAfterFee = _fiIn - fee;

        // Redemption fee is captured by retaining 'fee' amount.
        LibToken._burn(_fi, s.feeCollector, burnAfterFee);

        // Redeems assets directly to recipient (does not traverse through Diamond).
        uint256 assets = LibVault._unwrap(
            LibToken._toUnderlyingDecimals(_fi, burnAfterFee),
            s.vault[_fi],
            _recipient
        );

        require(assets >= _underlyingOutMin, 'SupplyFacet: Slippage exceeded');

        emit LibToken.Withdraw(s.underlying[_fi], _fiIn, _depositFrom, fee);

        // If enabled, rebase after to avoid dust residing at depositFrom.
        if (s.rebasePublic[_fi] == 1) LibToken._poke(_fi);
    }

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