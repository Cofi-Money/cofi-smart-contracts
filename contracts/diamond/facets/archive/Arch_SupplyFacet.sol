// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { Modifiers } from '../libs/LibAppStorage.sol';
// import { LibToken } from '../libs/LibToken.sol';
// import { LibReward } from '../libs/LibReward.sol';
// import { LibVault } from '../libs/LibVault.sol';
// import { IERC4626 } from '.././interfaces/IERC4626.sol';
// import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
// import 'hardhat/console.sol';

// /**

//     █▀▀ █▀█ █▀▀ █
//     █▄▄ █▄█ █▀░ █

//     @author Sam Goodenough, The Stoa Corporation Ltd.
//     @title  Supply Facet
//     @notice User-operated functions for minting/redeeming fi tokens.
//             Backing assets are deployed to the respective vault as per schema.
//  */

// contract SupplyFacet is Modifiers {

//     /*//////////////////////////////////////////////////////////////
//                             DEPOSIT FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     /// @notice Deposit entry point that routes according to if a derivative asset
//     ///         e.g., USDC-LP needs to be acquired for the vault.
//     ///
//     /// @param  _underlyingIn   The amount of underlying tokens to deposit.
//     /// @param  _fiOutMin       The minimum amount of fi tokens received (before fees).
//     /// @param  _fi             The fi token to mint.
//     /// @param  _depositFrom    The account to deposit underlying tokens from.
//     /// @param  _recipient      The recipient of the fi tokens.
//     /// @param  _referral       The referral account (address(0) if none provided).
//     function underlyingToFi(
//         uint256 _underlyingIn,
//         uint256 _fiOutMin, // E.g., 1,000 * 0.9975 = 997.50. Auto-set to 0.25%.
//         address _fi,
//         address _depositFrom,
//         address _recipient,
//         address _referral
//     )   external
//         nonReentrant isWhitelisted mintEnabled(_fi) minDeposit(_underlyingIn, _fi)
//         returns (uint256 mintAfterFee)
//     {
//         // Preemptively rebases if enabled.
//         if (s.rebasePublic[_fi] == 1) LibToken._poke(_fi);

//         mintAfterFee = IERC4626(s.vault[_fi]).asset() == s.underlying[_fi] ?
//             underlyingToFiMutual(
//                 _underlyingIn,
//                 _fiOutMin,
//                 _fi,
//                 _depositFrom,
//                 _recipient,
//                 _referral
//             ) :
//             underlyingToFiDeriv(
//                 _underlyingIn,
//                 _fiOutMin,
//                 _fi,
//                 _depositFrom,
//                 _recipient,
//                 _referral
//             );
//     }

//     /// @notice Converts a supported underlying token into a fi token (e.g., USDC to fiUSD)
//     ///         where the vault takes said underlying as its productive asset.
//     ///
//     /// @param  _underlyingIn   The amount of underlying tokens to deposit.
//     /// @param  _fiOutMin       The minimum amount of fi tokens received (before fees).
//     /// @param  _fi             The fi token to mint.
//     /// @param  _depositFrom    The account to deposit underlying tokens from.
//     /// @param  _recipient      The recipient of the fi tokens.
//     /// @param  _referral       The referral account (address(0) if none provided).
//     function underlyingToFiMutual(
//         uint256 _underlyingIn,
//         uint256 _fiOutMin,
//         address _fi,
//         address _depositFrom,
//         address _recipient,
//         address _referral
//     )   internal
//         returns (uint256 mintAfterFee)
//     {
//         // Transfer underlying to this contract first to prevent user having to 
//         // approve 1+ vaults (if/when the vault used changes, upon revisiting platform).
//         LibToken._transferFrom(
//             s.underlying[_fi],
//             _underlyingIn,
//             _depositFrom,
//             address(this)
//         );
        
//         SafeERC20.safeApprove(
//             IERC20(IERC4626(s.vault[_fi]).asset()),
//             s.vault[_fi],
//             _underlyingIn
//         );

//         uint256 assets = LibToken._toFiDecimals(
//             _fi,
//             LibVault._getAssets(
//                 LibVault._wrap(
//                     _underlyingIn,
//                     s.vault[_fi],
//                     _depositFrom // Purely for Event emission. Wraps from Diamond.
//                 ),
//                 s.vault[_fi]
//             )
//         );

//         require(assets >= _fiOutMin, 'SupplyFacet: Slippage exceeded');

//         uint256 fee = LibToken._getMintFee(_fi, assets);
//         mintAfterFee = assets - fee;

//         // Capture mint fee in fi tokens.
//         if (fee > 0) {
//             LibToken._mint(_fi, s.feeCollector, fee);
//         }
//         LibToken._mintOptIn(_fi, _recipient, mintAfterFee);

//         // Distribute rewards.
//         LibReward._initReward();
//         if (_referral != address(0)) {
//             LibReward._referReward(_referral);
//         }

//         emit LibToken.Deposit(s.underlying[_fi], _underlyingIn, _depositFrom, fee);
//     }

//     /// @notice Converts a supported underlying token into a fi token (e.g., USDC to fiUSD)
//     ///         via a derivative asset (e.g., USDC-LP).
//     ///
//     /// @param  _underlyingIn   The amount of underlying tokens to deposit.
//     /// @param  _fiOutMin       The minimum amount of fi tokens received (before fees).
//     /// @param  _fi             The fi token to mint.
//     /// @param  _depositFrom    The account to deposit underlying tokens from.
//     /// @param  _recipient      The recipient of the fi tokens.
//     /// @param  _referral       The referral account (address(0) if none provided).
//     function underlyingToFiDeriv(
//         uint256 _underlyingIn,
//         uint256 _fiOutMin,
//         address _fi,
//         address _depositFrom,
//         address _recipient,
//         address _referral
//     )   internal
//         extGuardOn
//         returns (uint256 mintAfterFee)
//     {
//         // Transfer underlying to this contract first to prevent user having to 
//         // approve 1+ vaults (if/when the vault used changes, upon revisiting platform).
//         LibToken._transferFrom(
//             s.underlying[_fi],
//             _underlyingIn,
//             _depositFrom,
//             address(this)
//         );

//         // Wind from underlying to derivative hook.
//         (bool success, ) = address(this).call(abi.encodeWithSelector(
//             s.derivParams[s.vault[_fi]].toDeriv,
//             _fi,
//             _underlyingIn
//         )); // Will fail here if set vault is not using a derivative.
//         require(success, 'SupplyFacet: Underlying to derivative operation failed');
//         require(s.RETURN_ASSETS > 0, 'SupplyFacet: Zero return assets received');

//         SafeERC20.safeApprove(
//             IERC20(IERC4626(s.vault[_fi]).asset()),
//             s.vault[_fi],
//             s.RETURN_ASSETS
//         );

//         (success, ) = address(this).call(abi.encodeWithSelector(
//             s.derivParams[s.vault[_fi]].convertToUnderlying,
//             _fi,
//             LibVault._getAssets(
//                 LibVault._wrap(
//                     s.RETURN_ASSETS,
//                     s.vault[_fi],
//                     _depositFrom
//                 ),
//                 s.vault[_fi]
//             )
//         ));
//         require(success, 'SupplyFacet: Convert to underlying operation failed');

//         uint256 assets = LibToken._toFiDecimals(_fi, s.RETURN_ASSETS);
//         require(assets >= _fiOutMin, 'SupplyFacet: Slippage exceeded');

//         uint256 fee = LibToken._getMintFee(_fi, assets);
//         mintAfterFee = assets - fee;

//         // Capture mint fee in fi tokens.
//         if (fee > 0) {
//             LibToken._mint(_fi, s.feeCollector, fee);
//         }
//         LibToken._mintOptIn(_fi, _recipient, mintAfterFee);

//         // Distribute rewards
//         LibReward._initReward();
//         if (_referral != address(0)) LibReward._referReward(_referral);

//         emit LibToken.Deposit(s.underlying[_fi], _underlyingIn, _depositFrom, fee);
//     }

//     /*//////////////////////////////////////////////////////////////
//                             WITHDRAW FUNCTIONS
//     //////////////////////////////////////////////////////////////*/

//     /// @notice Withdraw entry point that routes according to if a derivative asset
//     ///         e.g., USDC-LP is used and needs to be unwind for its underlying.
//     ///
//     /// @param  _fiIn               The amount of fi tokens to redeem.
//     /// @param  _underlyingOutMin   The minimum amount of underlying tokens received (AFTER fees).
//     /// @param  _fi                 The fi token to redeem.
//     /// @param  _depositFrom        The account to deposit fi tokens from.
//     /// @param  _recipient          The recipient of the underlying tokens.
//     function fiToUnderlying(
//         uint256 _fiIn,
//         uint256 _underlyingOutMin,
//         address _fi,
//         address _depositFrom,
//         address _recipient
//     )   external
//         nonReentrant isWhitelisted redeemEnabled(_fi) minWithdraw(_fiIn, _fi)
//         returns (uint256 burnAfterFee)
//     {
//         burnAfterFee = IERC4626(s.vault[_fi]).asset() == s.underlying[_fi] ?
//             fiToUnderlyingMutual(
//                 _fiIn,
//                 _underlyingOutMin,
//                 _fi,
//                 _depositFrom,
//                 _recipient
//             ) :
//             fiToUnderlyingDeriv(
//                 _fiIn,
//                 _underlyingOutMin,
//                 _fi,
//                 _depositFrom,
//                 _recipient
//             );

//         if (s.rebasePublic[_fi] == 1) LibToken._poke(_fi);
//     }

//     /// @notice Converts a fi token to its collateral underlying token (e.g., fiUSD to USDC).
//     ///
//     /// @notice Can be used to make payments in the underlying token in one tx (e.g., transfer
//     ///         USDC directly from fiUSD).
//     ///
//     /// @param  _fiIn               The amount of fi tokens to redeem.
//     /// @param  _underlyingOutMin   The minimum amount of underlying tokens received (AFTER fees).
//     /// @param  _fi                 The fi token to redeem (e.g., fiUSD).
//     /// @param  _depositFrom        The account to deposit fi tokens from.
//     /// @param  _recipient          The recipient of the underlying tokens.
//     function fiToUnderlyingMutual(
//         uint256 _fiIn,
//         uint256 _underlyingOutMin,
//         address _fi,
//         address _depositFrom,
//         address _recipient
//     )   internal
//         returns (uint256 burnAfterFee)
//     {
//         LibToken._transferFrom(_fi, _fiIn, _depositFrom, s.feeCollector);

//         uint256 fee = LibToken._getRedeemFee(_fi, _fiIn);
//         burnAfterFee = _fiIn - fee;

//         // Redemption fee is captured by retaining 'fee' amount.
//         LibToken._burn(_fi, s.feeCollector, burnAfterFee);

//         // Redeems assets directly to recipient (does not traverse through Diamond).
//         uint256 assets = LibVault._unwrap(
//             LibToken._toUnderlyingDecimals(_fi, burnAfterFee),
//             s.vault[_fi],
//             _recipient
//         );

//         require(assets >= _underlyingOutMin, 'SupplyFacet: Slippage exceeded');

//         emit LibToken.Withdraw(s.underlying[_fi], _fiIn, _depositFrom, fee);
//     }

//     /// @notice Converts a fi token to its collateral underlying token (e.g., fiUSD to USDC)
//     ///         via a derivative asset (if used), e.g., USDC-LP.
//     ///
//     /// @notice Likewise, can be used to make payments in the underlying token in one tx
//     ///         (e.g., transfer USDC directly from fiUSD).
//     ///
//     /// @param  _fiIn               The amount of fi tokens to redeem.
//     /// @param  _underlyingOutMin   The minimum amount of underlying tokens received (AFTER fees).
//     /// @param  _fi                 The fi token to redeem (e.g., fiUSD).
//     /// @param  _depositFrom        The account to deposit fi tokens from.
//     /// @param  _recipient          The recipient of the underlying tokens.
//     function fiToUnderlyingDeriv(
//         uint256 _fiIn,
//         uint256 _underlyingOutMin,
//         address _fi,
//         address _depositFrom,
//         address _recipient
//     )   internal
//         extGuardOn
//         returns (uint256 burnAfterFee)
//     {
//         LibToken._transferFrom(_fi, _fiIn, _depositFrom, s.feeCollector);

//         uint256 fee = LibToken._getRedeemFee(_fi, _fiIn);
//         burnAfterFee = _fiIn - fee;

//         // Redemption fee is captured by retaining 'fee' amount.
//         LibToken._burn(_fi, s.feeCollector, burnAfterFee);

//         // Determine equivalent number of derivative assets to redeem.
//         (bool success, ) = address(this).call(abi.encodeWithSelector(
//             s.derivParams[s.vault[_fi]].convertToDeriv,
//             _fi,
//             burnAfterFee
//         )); 
//         require(success, 'SupplyFacet: Convert to derivative operation failed');

//         // Unwind from derivative asset to underlying hook.
//         (success, ) = address(this).call(abi.encodeWithSelector(
//             s.derivParams[s.vault[_fi]].toUnderlying,
//             _fi,
//             LibVault._unwrap(s.RETURN_ASSETS, s.vault[_fi], address(this))
//         ));
//         require(success, 'SupplyFacet: Derivative to underlying operation failed');
//         require(s.RETURN_ASSETS > _underlyingOutMin, 'SupplyFacet: Slippage exceeded');

//         LibToken._transfer(s.underlying[_fi], s.RETURN_ASSETS, _recipient);

//         emit LibToken.Withdraw(s.underlying[_fi], _fiIn, _depositFrom, fee);
//     }
// }