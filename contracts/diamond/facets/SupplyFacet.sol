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
                Swap-enabled Deposit & Withdraw Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enables user to enter app directly with native Ether.
     * @param _cofi         The cofi token to receive.
     * @param _recipient    The account receiving cofi tokens.
     * @param _referral     The referral account (address(0) if none given).
     */
    function ETHToCofi(
        address _cofi,
        address _recipient,
        address _referral
    )   external payable
        nonReentrant isWhitelisted mintEnabled(_cofi)
        returns (uint256 mintAfterFee, uint256 underlyingOut)
    {
        // Swaps directly from msg.sender's account.
        underlyingOut = LibSwap._swapETHForERC20(s.underlying[_cofi]);

        uint256 fee;
        // Underling tokens reside at this contract from swap operation.
        (mintAfterFee, fee) = _underlyingToCofi(
            underlyingOut,
            _cofi,
            _recipient,
            _referral
        );
        emit LibToken.Deposit(s.underlying[_cofi], underlyingOut, msg.sender, fee);
    }

    /**
     * @notice Enables user to enter app directly with supported tokens.
     * @dev Swap parameters must be set for token.
     * @param _tokensIn     The amount of tokens to swap.
     * @param _token        The ERC20 token to swap.
     * @param _cofi         The cofi token to receive.
     * @param _depositFrom  The account to transfer tokens from.
     * @param _recipient    The account receiving cofi tokens.
     * @param _referral     The referral account (address(0) if none given).
     */
    function tokensToCofi(
        uint256 _tokensIn,
        address _token,
        address _cofi,
        address _depositFrom,
        address _recipient,
        address _referral
    )   external
        nonReentrant
        returns (uint256 mintAfterFee, uint256 underlyingOut)
    {
        // Transfer tokens to this contract first for swap op.
        LibToken._transferFrom(
            _token,
            _tokensIn,
            _depositFrom,
            address(this)
        );

        if (_token != s.underlying[_cofi]) {
            underlyingOut = LibSwap._swapERC20ForERC20(
                _tokensIn,
                _token,
                s.underlying[_cofi],
                address(this)
            );
        } else {
            underlyingOut = _tokensIn;
        }

        uint256 fee;
        // Underling tokens reside at this contract from swap operation.
        (mintAfterFee, fee) = _underlyingToCofi(
            underlyingOut,
            _cofi,
            _recipient,
            _referral
        );
        emit LibToken.Deposit(s.underlying[_cofi], underlyingOut, _depositFrom, fee);
    }

    // function tokensToCofi(
    //     uint256 _tokensIn,
    //     address _token,
    //     address _cofi,
    //     address _depositFrom,
    //     address _recipient,
    //     address _referral
    // )   external
    //     nonReentrant
    //     returns (uint256 mintAfterFee)
    // {
    //     // Transfer tokens to this contract first for swap op.
    //     LibToken._transferFrom(
    //         _token,
    //         _tokensIn,
    //         _depositFrom,
    //         address(this)
    //     );

    //     address underlying = IERC4626(s.vaults[_cofi][0].vault).asset();
    //     uint256 underlyingOut;
    //     // Convert to underlying of asset used by first vault.
    //     if (_token != underlying) {
    //         underlyingOut = LibSwap._swapERC20ForERC20(
    //             _tokensIn,
    //             _token,
    //             s.underlying[_cofi],
    //             address(this)
    //         );
    //     }

    //     uint256 assets = LibToken._toCofiDecimals(
    //         underlying,
    //         LibVault._getAssets(
    //             LibVault._wrap(
    //                 LibToken._applyPercent(underlyingOut, s.vaults[_cofi][0].allocation),
    //                 s.vaults[_cofi][0].vault
    //             ),
    //             s.vaults[_cofi][0].vault
    //         )
    //     );
    //     uint256 round;
    //     uint256 spent = LibToken._applyPercent(underlyingOut, s.vaults[_cofi][0].allocation);
    //     uint256 spentAllocation = s.vaults[_cofi][0].allocation;

    //     for (uint i = 1; i < s.vaults[_cofi].length; i++) {
    //         if (spentAllocation < 10_000) {
    //             if (underlying == IERC4626(s.vaults[_cofi][i].vault).asset()) {
    //                 assets += LibToken._toCofiDecimals(
    //                     underlying,
    //                     LibVault._getAssets(
    //                         LibVault._wrap(
    //                             LibToken._applyPercent(underlyingOut, s.vaults[_cofi][i].allocation),
    //                             s.vaults[_cofi][i].vault
    //                         ),
    //                         s.vaults[_cofi][i].vault
    //                     )
    //                 );
    //             } else {
    //                 // Swap first underlying for second underlying.
    //                 underlyingOut = LibSwap._swapERC20ForERC20(
    //                     _tokensIn,
    //                     _token,
    //                     s.underlying[_cofi],
    //                     address(this)
    //                 );
    //                 /// @dev Important that 10,000 is a fatcor of vault's allocation.
    //                 uint256 allocationScaled = 10_000 / s.vaults[_cofi][i].allocation * 10_000;
    //                 // Wrap
    //                 assets += LibToken._toCofiDecimals(
    //                     underlying,
    //                     LibVault._getAssets(
    //                         LibVault._wrap(
    //                             LibToken._applyPercent(underlyingOut, s.vaults[_cofi][i].allocation),
    //                             s.vaults[_cofi][i].vault
    //                         ),
    //                         s.vaults[_cofi][i].vault
    //                     )
    //                 );
    //             }
    //             spentAllocation += s.vaults[_cofi][i].allocation;
    //         } else {
    //             break;
    //         }
    //     }

    //     /**
    //      * Vaults[] storage requirements:
    //      * - Ensure all vaults that use the same asset are next to each other.
    //      * - Ensure allocation across all vaults adds up to 10,000 (100%).
    //      * E.g., [wsoUSDC, 2,500], [wyvUSDC, 2,500], [wsoDAI, 2,500], [wsoUSDC, 2,500].
    //      */

    // }

    /**
     * @notice Enables user to exit app and receive native Ether.
     * @param _cofiIn       The amount of cofi tokens to redeem.
     * @param _cofi         The cofi token to redeem.
     * @param _depositFrom  The account to transfer cofi tokens from.
     * @param _recipient    The account receiving native Ether.
     */
    function cofiToETH(
        uint256 _cofiIn,
        address _cofi,
        address _depositFrom,
        address _recipient
    )   external
        returns (uint256 burnAfterFee, uint256 ETHOut)
    {
        burnAfterFee = cofiToUnderlying(
            _cofiIn,
            _cofi,
            _depositFrom,
            _recipient
        );

        ETHOut = LibSwap._swapERC20ForETH(burnAfterFee, s.underlying[_cofi], _recipient);
    }

    /**
     * @notice Enables user to exit app and receive supported tokens.
     * @param _cofiIn       The amount of cofi tokens to redeem.
     * @param _token        The ERC20 token to receive.
     * @param _cofi         The cofi token to redeem.
     * @param _depositFrom  The account to transfer cofi tokens from.
     * @param _recipient    The account receiving tokens.
     */
    function cofiToTokens(
        uint256 _cofiIn,
        address _token,
        address _cofi,
        address _depositFrom,
        address _recipient
    )   external
        returns (uint256 burnAfterFee, uint256 tokensOut)
    {
        burnAfterFee = cofiToUnderlying(
            _cofiIn,
            _cofi,
            _depositFrom,
            _recipient
        );

        if (_token != s.underlying[_cofi]) {
            return (
                burnAfterFee,
                LibSwap._swapERC20ForERC20(burnAfterFee, s.underlying[_cofi], _token, _recipient)
            );
        } else {
            LibToken._transfer(_token, burnAfterFee, _recipient);
            return (burnAfterFee, burnAfterFee);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    Direct Deposit & Withdraw Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts a supported underlying token into a cofi token (e.g., USDC to coUSD).
     * @param _underlyingIn The amount of underlying tokens to deposit.
     * @param _cofi         The cofi token to receive.
     * @param _depositFrom  The account to transfer underlying tokens from.
     * @param _recipient    The account receiving cofi tokens.
     * @param _referral     The referral account (address(0) if none given).
     */
    function underlyingToCofi(
        uint256 _underlyingIn,
        address _cofi,
        address _depositFrom,
        address _recipient,
        address _referral
    )   public
        nonReentrant isWhitelisted mintEnabled(_cofi)
        returns (uint256 mintAfterFee)
    {
        // Transfer tokens to this contract first to prevent user having to approve 1+ contracts.
        LibToken._transferFrom(
            s.underlying[_cofi],
            _underlyingIn,
            _depositFrom,
            address(this)
        );

        uint256 fee;
        (mintAfterFee, fee) = _underlyingToCofi(
            _underlyingIn,
            _cofi,
            _recipient,
            _referral
        );

        emit LibToken.Deposit(s.underlying[_cofi], _underlyingIn, _depositFrom, fee);
    }

    function _underlyingToCofi(
        uint256 _underlyingIn,
        address _cofi,
        address _recipient,
        address _referral
    )   internal
        minDeposit(_underlyingIn, _cofi)
        returns (uint256 mintAfterFee, uint256 fee)
    {
        // Preemptively rebases if enabled.
        if (s.rebasePublic[_cofi] == 1) LibToken._poke(_cofi);

        SafeERC20.safeApprove(
            IERC20(IERC4626(s.vault[_cofi]).asset()),
            s.vault[_cofi],
            _underlyingIn
        );
        
        uint256 assets = LibToken._toCofiDecimals(
            s.underlying[_cofi],
            LibVault._getAssets(
                LibVault._wrap(
                    _underlyingIn,
                    s.vault[_cofi]
                ),
                s.vault[_cofi]
            )
        );

        require(
            assets >= LibToken._applySlippage(_underlyingIn),
            'SupplyFacet: Slippage exceeded'
        );

        fee = LibToken._getMintFee(_cofi, assets);
        mintAfterFee = assets - fee;
        console.log('mintAfterFee: %s', mintAfterFee);

        // Capture mint fee in co tokens.
        if (fee > 0) LibToken._mint(_cofi, s.feeCollector, fee);

        LibToken._mintOptIn(_cofi, _recipient, mintAfterFee);

        // Distribute rewards.
        LibReward._initReward();
        if (_referral != address(0)) {
            LibReward._referReward(_referral);
        }
    }

    /**
     * @notice Converts a cofi token to its collateral underlying token (e.g., coUSD to USDC).
     * @param _cofiIn       The amount of cofi tokens to redeem.
     * @param _cofi         The cofi token to redeem.
     * @param _depositFrom  The account to deposit cofi tokens from.
     * @param _recipient    The account receiving underlying tokens.
     */
    function cofiToUnderlying(
        uint256 _cofiIn,
        address _cofi,
        address _depositFrom,
        address _recipient
    )   public
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

        require(
            assets >= LibToken._applySlippage(burnAfterFee),
            'SupplyFacet: Slippage exceeded'
        );

        emit LibToken.Withdraw(s.underlying[_cofi], _cofiIn, _depositFrom, fee);

        // If enabled, rebase after to avoid dust residing at depositFrom.
        if (s.rebasePublic[_cofi] == 1) LibToken._poke(_cofi);
    }
}