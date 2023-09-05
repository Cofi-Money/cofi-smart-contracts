// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers } from '../libs/LibAppStorage.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibReward } from '../libs/LibReward.sol';
import { LibVault } from '../libs/LibVault.sol';
import { LibSwap } from '../libs/LibSwap.sol';
import { PercentageMath } from '../libs/external/PercentageMath.sol';
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
    using PercentageMath for uint256;

    /*//////////////////////////////////////////////////////////////
                Swap-enabled Deposit & Withdraw Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  Simplified entry point for minting COFI tokens. Refer to 'getSupportedSwaps()'
     *          in 'SwapManagerFacet.sol' to see list of supported assets for entering with.
     * @dev Swap parameters must be set for token.
     * @param _tokensIn     The amount of tokens to swap (pass instead as msg.value if native Ether).
     * @param _token        The ERC20 token to swap (irrelevant if native Ether).
     * @param _cofi         The cofi token to receive.
     * @param _depositFrom  The account to transfer tokens from (msg.sender if native Ether).
     * @param _recipient    The account receiving cofi tokens.
     * @param _referral     The referral account (address(0) if none given).
     */
    function enterCofi(
        uint256 _tokensIn,
        address _token,
        address _cofi,
        address _depositFrom,
        address _recipient,
        address _referral
    )   external payable
        nonReentrant isWhitelisted mintEnabled(_cofi)
        returns (uint256 mintAfterFee, uint256 underlyingOut)
    {
        address underlying = IERC4626(s.vault[_cofi]).asset();

        if (msg.value > 0) return _ETHToCofi(_cofi, underlying, _recipient, _referral);

        // Transfer tokens to this contract first for swap op.
        LibToken._transferFrom(
            _token,
            _tokensIn,
            _depositFrom,
            address(this)
        );

        if (_token != underlying) {
            underlyingOut = LibSwap._swapERC20ForERC20(
                _tokensIn,
                _token,
                underlying,
                address(this)
            );
        } else {
            underlyingOut = _tokensIn;
        }

        require(
            underlyingOut > s.minDeposit[_cofi],
            'SupplyFacet: Insufficient deposit amount for cofi token'
        );

        uint256 fee;
        // Underling tokens reside at this contract from swap operation.
        (mintAfterFee, fee) = _underlyingToCofi(
            underlyingOut,
            _cofi,
            underlying,
            _recipient,
            _referral
        );
        emit LibToken.Deposit(underlying, underlyingOut, _depositFrom, fee);
    }

    function _ETHToCofi(
        address _cofi,
        address _underlying,
        address _recipient,
        address _referral
    )   internal
        returns (uint256 mintAfterFee, uint256 underlyingOut)
    {
        // Swaps directly from msg.sender's account.
        underlyingOut = LibSwap._swapETHForERC20(_underlying);

        require(
            underlyingOut > s.minDeposit[_cofi],
            'SupplyFacet: Insufficient deposit amount for cofi token'
        );

        uint256 fee;
        // Underling tokens reside at this contract from swap operation.
        (mintAfterFee, fee) = _underlyingToCofi(
            underlyingOut,
            _cofi,
            _underlying,
            _recipient,
            _referral
        );

        emit LibToken.Deposit(_underlying, underlyingOut, msg.sender, fee);
    }

    /**
     * @notice  Simplified exit point for minting COFI tokens. Refer to 'getSupportedSwaps()'
     *          in 'SwapManagerFacet.sol' to see list of supported assets for exiting to.
     * @param _cofiIn       The amount of cofi tokens to redeem.
     * @param _token        The ERC20 token to receive (address(0) if requesting native Ether).
     * @param _cofi         The cofi token to redeem.
     * @param _depositFrom  The account to transfer cofi tokens from.
     * @param _recipient    The account receiving tokens.
     */
    function exitCofi(
        uint256 _cofiIn,
        address _token,
        address _cofi,
        address _depositFrom,
        address _recipient
    )   external
        nonReentrant isWhitelisted redeemEnabled(_cofi) minWithdraw(_cofiIn, _cofi)
        returns (uint256 burnAfterFee, uint256 tokensOut)
    {
        if (_token == address(0))
            return _cofiToETH(_cofiIn, _cofi, _depositFrom, _recipient);

        address underlying = IERC4626(s.vault[_cofi]).asset();

        if (_token == underlying) {
            burnAfterFee = _cofiToUnderlying(
                _cofiIn,
                _cofi,
                _depositFrom,
                _recipient
            );
            return (burnAfterFee, burnAfterFee);
        }

        burnAfterFee = _cofiToUnderlying(
            _cofiIn,
            _cofi,
            _depositFrom,
            address(this)
        );

        return (
            burnAfterFee,
            LibSwap._swapERC20ForERC20(
                LibToken._toUnderlyingDecimals(_cofi, burnAfterFee),
                underlying,
                _token,
                _recipient
            )
        );
    }

    function _cofiToETH(
        uint256 _cofiIn,
        address _cofi,
        address _depositFrom,
        address _recipient
    )   internal
        returns (uint256 burnAfterFee, uint256 ETHOut)
    {
        burnAfterFee = _cofiToUnderlying(
            _cofiIn,
            _cofi,
            _depositFrom,
            address(this)
        );

        ETHOut = LibSwap._swapERC20ForETH(
            LibToken._toUnderlyingDecimals(_cofi, burnAfterFee),
            IERC4626(s.vault[_cofi]).asset(),
            _recipient
        );
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
    )   external
        nonReentrant isWhitelisted mintEnabled(_cofi) minDeposit(_underlyingIn, _cofi)
        returns (uint256 mintAfterFee)
    {
        address underlying = IERC4626(s.vault[_cofi]).asset();

        // Transfer tokens to this contract first to prevent user having to approve 1+ contracts.
        LibToken._transferFrom(
            underlying,
            _underlyingIn,
            _depositFrom,
            address(this)
        );

        uint256 fee;
        (mintAfterFee, fee) = _underlyingToCofi(
            _underlyingIn,
            _cofi,
            underlying,
            _recipient,
            _referral
        );

        emit LibToken.Deposit(
            underlying,
            _underlyingIn,
            _depositFrom,
            fee
        );
    }

    function _underlyingToCofi(
        uint256 _underlyingIn,
        address _cofi,
        address _underlying,
        address _recipient,
        address _referral
    )   internal
        returns (uint256 mintAfterFee, uint256 fee)
    {
        // Preemptively rebases if enabled.
        if (s.rebasePublic[_cofi] == 1) LibToken._poke(_cofi);

        SafeERC20.safeApprove(
            IERC20(_underlying),
            s.vault[_cofi],
            _underlyingIn
        );

        uint256 assets = LibToken._toCofiDecimals(
            _underlying,
            LibVault._getAssets(
                LibVault._wrap(
                    _underlyingIn,
                    s.vault[_cofi]
                ),
                s.vault[_cofi]
            )
        );

        require(
            assets > _underlyingIn.percentMul(1e4 - s.defaultSlippage),
            'SupplyFacet: Slippage exceeded'
        );
        require(
            assets < _underlyingIn.percentMul(1e4 + s.upperLimit),
            'SupplyFacet: Assets value exceeds upper limit check'
        );

        fee = LibToken._getMintFee(_cofi, assets);
        mintAfterFee = assets - fee;

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
    )   external
        nonReentrant isWhitelisted redeemEnabled(_cofi) minWithdraw(_cofiIn, _cofi)
        returns (uint256 burnAfterFee)
    {
        return _cofiToUnderlying(
            _cofiIn,
            _cofi,
            _depositFrom,
            _recipient
        );
    }

    function _cofiToUnderlying(
        uint256 _cofiIn,
        address _cofi,
        address _depositFrom,
        address _recipient
    )   internal
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
            assets > LibToken._toUnderlyingDecimals(_cofi, burnAfterFee)
                .percentMul(1e4 - s.defaultSlippage),
            'SupplyFacet: Slippage exceeded'
        );
        require(
            assets < LibToken._toUnderlyingDecimals(_cofi, burnAfterFee)
                .percentMul(1e4 + s.upperLimit),
            'SupplyFacet: Assets value exceeds upper limit check'
        );

        emit LibToken.Withdraw(IERC4626(s.vault[_cofi]).asset(), _cofiIn, _depositFrom, fee);

        // If enabled, rebase after to avoid dust residing at depositFrom.
        if (s.rebasePublic[_cofi] == 1) LibToken._poke(_cofi);
    }

    /// @notice Returns the estimated cofi tokens received from the amount of entry tokens deposited.
    function getEstimatedCofiOut(
        uint256 _tokensIn,
        address _token,
        address _cofi
    )   external view
        returns (uint256 cofiOut)
    {
        return LibSwap._getConversion(_tokensIn, s.mintFee[_cofi], _token, _cofi);
    }

    /// @notice Returns the estimated tokens out (incl. ETH) from the amount of cofi tokens deposited.
    function getEstimatedTokensOut(
        uint256 _cofiIn,
        address _cofi,
        address _token
    )   external view
        returns (uint256 cofiOut)
    {
        return LibSwap._getConversion(_cofiIn, s.redeemFee[_cofi], _cofi, _token);
    }
}