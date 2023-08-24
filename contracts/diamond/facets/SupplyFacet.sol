// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers } from '../libs/LibAppStorage.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibReward } from '../libs/LibReward.sol';
import { LibVault } from '../libs/LibVault.sol';
import { LibSwap } from '../libs/LibSwap.sol';
import { IERC4626 } from '.././interfaces/IERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import 'hardhat/console.sol';

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
                SWAP & DEPOSIT + WITHDRAW & SWAP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function ETHToCo(
        address _co,
        address _recipient,
        address _referral
    )   external payable
        isSupportedSwap(LibSwap.WETH, s.underlying[_co])
        returns (uint256 mintAfterFee, uint256 underlyingOut)
    {
        // Swaps directly from msg.sender's account.
        underlyingOut = LibSwap._swapETHForERC20(s.underlying[_co]);

        uint256 fee;
        // Underling tokens reside at this contract from swap operation.
        (mintAfterFee, fee) = _underlyingToCo(
            underlyingOut,
            _co,
            _recipient,
            _referral
        );
        emit LibToken.Deposit(s.underlying[_co], underlyingOut, msg.sender, fee);
    }

    function tokensToCo(
        uint256 _tokensIn,
        address _token,
        address _co,
        address _depositFrom,
        address _recipient,
        address _referral
    )   external
        isSupportedSwap(_token, s.underlying[_co])
        returns (uint256 mintAfterFee, uint256 underlyingOut)
    {
        // Transfer tokens to this contract first to prevent user having to approve 1+ contracts.
        LibToken._transferFrom(
            _token,
            _tokensIn,
            _depositFrom,
            address(this)
        );

        if (_token != s.underlying[_co]) {
            underlyingOut = LibSwap._swapERC20ForERC20(
                _tokensIn,
                _token,
                s.underlying[_co],
                address(this)
            );
        } else {
            underlyingOut = _tokensIn;
        }

        uint256 fee;
        // Underling tokens reside at this contract from swap operation.
        (mintAfterFee, fee) = _underlyingToCo(
            underlyingOut,
            _co,
            _recipient,
            _referral
        );
        emit LibToken.Deposit(s.underlying[_co], underlyingOut, _depositFrom, fee);
    }

    function coToETH(
        uint256 _coIn,
        address _co,
        address _depositFrom,
        address _recipient
    )   external
        isSupportedSwap(s.underlying[_co], LibSwap.WETH)
        returns (uint256 burnAfterFee, uint256 ETHOut)
    {
        burnAfterFee = coToUnderlying(
            _coIn,
            _co,
            _depositFrom,
            _recipient
        );

        ETHOut = LibSwap._swapERC20ForETH(burnAfterFee, s.underlying[_co], _recipient);
    }

    function coToTokens(
        uint256 _coIn,
        address _token,
        address _co,
        address _depositFrom,
        address _recipient
    )   external
        isSupportedSwap(s.underlying[_co], _token)
        returns (uint256 burnAfterFee, uint256 tokensOut)
    {
        burnAfterFee = coToUnderlying(
            _coIn,
            _co,
            _depositFrom,
            _recipient
        );

        if (_token != s.underlying[_co]) {
            return (
                burnAfterFee,
                LibSwap._swapERC20ForERC20(burnAfterFee, s.underlying[_co], _token, _recipient)
            );
        } else {
            LibToken._transfer(_token, burnAfterFee, _recipient);
            return (burnAfterFee, burnAfterFee);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    DIRECT DEPOSIT + WITHDRAW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function underlyingToCo(
        uint256 _underlyingIn,
        address _co,
        address _depositFrom,
        address _recipient,
        address _referral
    )   public
        nonReentrant isWhitelisted mintEnabled(_co) minDeposit(_underlyingIn, _co)
        returns (uint256 mintAfterFee)
    {
        // Transfer underlying to this contract first to prevent user having to 
        // approve 1+ vaults (if/when the vault used changes, upon revisiting platform).
        LibToken._transferFrom(
            s.underlying[_co],
            _underlyingIn,
            _depositFrom,
            address(this)
        );

        uint256 fee;
        (mintAfterFee, fee) = _underlyingToCo(
            _underlyingIn,
            _co,
            _recipient,
            _referral
        );

        emit LibToken.Deposit(s.underlying[_co], _underlyingIn, _depositFrom, fee);
    }

    /// @notice Converts a supported underlying token into a co token (e.g., USDC to coUSD).
    ///
    /// @param  _underlyingIn   The amount of underlying tokens to deposit.
    /// @param  _co             The co token to mint.
    /// @param  _recipient      The recipient of the co tokens.
    /// @param  _referral       The referral account (address(0) if none provided).
    function _underlyingToCo(
        uint256 _underlyingIn,
        address _co,
        address _recipient,
        address _referral
    )   internal
        returns (uint256 mintAfterFee, uint256 fee)
    {
        // Preemptively rebases if enabled.
        if (s.rebasePublic[_co] == 1) LibToken._poke(_co);

        SafeERC20.safeApprove(
            IERC20(IERC4626(s.vault[_co]).asset()),
            s.vault[_co],
            _underlyingIn
        );

        uint256 assets = LibToken._toCofiDecimals(
            _co,
            LibVault._getAssets(
                LibVault._wrap(
                    _underlyingIn,
                    s.vault[_co]
                ),
                s.vault[_co]
            )
        );

        require(
            assets >= LibToken._applySlippage(_underlyingIn),
            'SupplyFacet: Slippage exceeded'
        );

        fee = LibToken._getMintFee(_co, assets);
        mintAfterFee = assets - fee;

        // Capture mint fee in co tokens.
        if (fee > 0) LibToken._mint(_co, s.feeCollector, fee);

        LibToken._mintOptIn(_co, _recipient, mintAfterFee);

        // Distribute rewards.
        LibReward._initReward();
        if (_referral != address(0)) {
            LibReward._referReward(_referral);
        }
    }

    /// @notice Converts a co token to its collateral underlying token (e.g., coUSD to USDC).
    ///
    /// @notice Can be used to make payments in the underlying token in one tx (e.g., transfer
    ///         USDC directly from coUSD).
    ///
    /// @param  _coIn           The amount of co tokens to redeem.
    /// @param  _co             The co token to redeem (e.g., coUSD).
    /// @param  _depositFrom    The account to deposit co tokens from.
    /// @param  _recipient      The recipient of the underlying tokens.
    function coToUnderlying(
        uint256 _coIn,
        address _co,
        address _depositFrom,
        address _recipient
    )   public
        nonReentrant isWhitelisted redeemEnabled(_co) minWithdraw(_coIn, _co)
        returns (uint256 burnAfterFee)
    {
        LibToken._transferFrom(_co, _coIn, _depositFrom, s.feeCollector);

        uint256 fee = LibToken._getRedeemFee(_co, _coIn);
        burnAfterFee = _coIn - fee;

        // Redemption fee is captured by retaining 'fee' amount.
        LibToken._burn(_co, s.feeCollector, burnAfterFee);

        // Redeems assets directly to recipient (does not traverse through Diamond).
        uint256 assets = LibVault._unwrap(
            LibToken._toUnderlyingDecimals(_co, burnAfterFee),
            s.vault[_co],
            _recipient
        );

        require(
            assets >= LibToken._applySlippage(burnAfterFee),
            'SupplyFacet: Slippage exceeded'
        );

        emit LibToken.Withdraw(s.underlying[_co], _coIn, _depositFrom, fee);

        // If enabled, rebase after to avoid dust residing at depositFrom.
        if (s.rebasePublic[_co] == 1) LibToken._poke(_co);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN - SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Set COFI stablecoin vars first BEFORE onboarding (refer to LibAppStorage.sol).
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