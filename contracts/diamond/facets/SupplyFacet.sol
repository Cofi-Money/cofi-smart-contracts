// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers } from '../libs/LibAppStorage.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibReward } from '../libs/LibReward.sol';
import { LibVault } from '../libs/LibVault.sol';
import { IERC4626 } from '.././interfaces/IERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Supply Facet
    @notice User-operated functions for minting/redeeming cofi tokens.
            Backing assets are deployed to the respective vault as per schema.
 */

contract SupplyFacet is Modifiers {

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT & WITHDRAW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Converts a supported underlying token into a cofi token (e.g., USDC to coUSD).
    ///
    /// @param  _underlyingIn   The amount of underlying tokens to deposit.
    /// @param  _cofiOutMin     The minimum amount of cofi tokens received (before fees).
    /// @param  _cofi           The cofi token to mint.
    /// @param  _depositFrom    The account to deposit underlying tokens from.
    /// @param  _recipient      The recipient of the cofi tokens.
    /// @param  _referral       The referral account (address(0) if none provided).
    function underlyingToCofi(
        uint256 _underlyingIn,
        uint256 _cofiOutMin,
        address _cofi,
        address _depositFrom,
        address _recipient,
        address _referral
    )   external
        nonReentrant isWhitelisted mintEnabled(_cofi) minDeposit(_underlyingIn, _cofi)
        returns (uint256 mintAfterFee)
    {
        // Preemptively rebases if enabled.
        if (s.rebasePublic[_cofi] == 1) LibToken._poke(_cofi);

        // Transfer underlying to this contract first to prevent user having to 
        // approve 1+ vaults (if/when the vault used changes, upon revisiting platform).
        LibToken._transferFrom(
            s.underlying[_cofi],
            _underlyingIn,
            _depositFrom,
            address(this)
        );
        
        SafeERC20.safeApprove(
            IERC20(IERC4626(s.vault[_cofi]).asset()),
            s.vault[_cofi],
            _underlyingIn
        );

        uint256 assets = LibToken._toCofiDecimals(
            _cofi,
            LibVault._getAssets(
                LibVault._wrap(
                    _underlyingIn,
                    s.vault[_cofi],
                    _depositFrom // Purely for Event emission. Wraps from Diamond.
                ),
                s.vault[_cofi]
            )
        );

        require(assets >= _cofiOutMin, 'SupplyFacet: Slippage exceeded');

        uint256 fee = LibToken._getMintFee(_cofi, assets);
        mintAfterFee = assets - fee;

        // Capture mint fee in cofi tokens.
        if (fee > 0) {
            LibToken._mint(_cofi, s.feeCollector, fee);
        }

        LibToken._mintOptIn(_cofi, _recipient, mintAfterFee);

        // Distribute rewards.
        LibReward._initReward();
        if (_referral != address(0)) {
            LibReward._referReward(_referral);
        }

        emit LibToken.Deposit(s.underlying[_cofi], _underlyingIn, _depositFrom, fee);
    }

    /// @notice Converts a cofi token to its collateral underlying token (e.g., coUSD to USDC).
    ///
    /// @notice Can be used to make payments in the underlying token in one tx (e.g., transfer
    ///         USDC directly from coUSD).
    ///
    /// @param  _cofiIn             The amount of cofi tokens to redeem.
    /// @param  _underlyingOutMin   The minimum amount of underlying tokens received (AFTER fees).
    /// @param  _cofi               The cofi token to redeem (e.g., coUSD).
    /// @param  _depositFrom        The account to deposit cofi tokens from.
    /// @param  _recipient          The recipient of the underlying tokens.
    function cofiToUnderlying(
        uint256 _cofiIn,
        uint256 _underlyingOutMin,
        address _cofi,
        address _depositFrom,
        address _recipient
    )   external
        nonReentrant isWhitelisted redeemEnabled(_cofi) minWithdraw(_cofiIn, _cofi)
        returns (uint256 burnAfterFee)
    {
        LibToken._transferFrom(_cofi, _cofiIn, _depositFrom, s.feeCollector);

        uint256 fee = LibToken._getRedeemFee(_cofi, _cofiIn);
        burnAfterFee = _cofiIn - fee;

        // Redemption fee is captured by retaining 'fee' amount.
        LibToken._burn(_cofi, s.feeCollector, burnAfterFee);

        // Redeems assets directly to recipient (does not traverse through Diamond).
        uint256 assets = LibVault._unwrap(
            LibToken._toUnderlyingDecimals(_cofi, burnAfterFee),
            s.vault[_cofi],
            _recipient
        );

        require(assets >= _underlyingOutMin, 'SupplyFacet: Slippage exceeded');

        emit LibToken.Withdraw(s.underlying[_cofi], _cofiIn, _depositFrom, fee);

        // If enabled, rebase after to avoid dust residing at depositFrom.
        if (s.rebasePublic[_cofi] == 1) LibToken._poke(_cofi);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN - SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Set COFI stablecoin vars first before onboarding (refer to LibAppStorage.sol).
    /// @dev Added decimals.
    function onboardAsset(
        address _cofi,
        address _underlying,
        address _vault,
        uint8   _decimals
    )   external
        onlyAdmin
        returns (bool)
    {
        s.underlying[_cofi] = _underlying;
        s.decimals[_cofi] = _decimals;
        s.vault[_cofi] = _vault;
        return true;
    }

    /// @notice "minDeposit" applies to the amount of underlying tokens required for deposit.
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

    /// @notice "minWithdraw" applies to the amount of underlying tokens redeemed.
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

    /*//////////////////////////////////////////////////////////////
                            ADMIN - GETTERS
    //////////////////////////////////////////////////////////////*/

    function getMinDeposit(
        address _cofi
    )   external
        view
        returns (uint256)
    {
        return s.minDeposit[_cofi];
    }

    function getMinWithdraw(
        address _cofi
    )   external
        view
        returns (uint256)
    {
        return s.minWithdraw[_cofi];
    }

    function getMintFee(
        address _cofi
    )   external
        view
        returns (uint256)
    {
        return s.mintFee[_cofi];
    }

    function getMintEnabled(
        address _cofi
    )   external
        view
        returns (uint8)
    {
        return s.mintEnabled[_cofi];
    }

    function getRedeemFee(
        address _cofi
    )   external
        view
        returns (uint256)
    {
        return s.redeemFee[_cofi];
    }

    function getRedeemEnabled(
        address _cofi
    )   external
        view
        returns (uint8)
    {
        return s.redeemEnabled[_cofi];
    }

    function getServiceFee(
        address _cofi
    )   external
        view
        returns (uint256)
    {
        return s.serviceFee[_cofi];
    }

    /// @notice Returns the underlying token for a given cofi token.
    function getUnderlying(
        address _cofi
    )   external
        view
        returns (address)
    {
        return IERC4626(s.vault[_cofi]).asset();
    }

    /// @notice Returns the vault for a given cofi token.
    function getVault(
        address _cofi
    )   external
        view
        returns (address)
    {
        return s.vault[_cofi];
    }
}