// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { RebaseOptions, ERC20Storage, LibERC20Storage } from "./LibERC20Storage.sol";
// import { Address } from '@openzeppelin/contracts/utils/Address.sol';
// import { IFiToken } from ".././interfaces/IFiToken.sol";
// import '../../utils/StableMath.sol';

// library LibERC20Token {
//     using StableMath for uint256;
//     using StableMath for int256;
//     using SafeMath for uint256;

//     uint256 constant MAX_SUPPLY = ~uint128(0); // (2^128) - 1
//     uint256 constant RESOLUTION_INCREASE = 1e9;

//     event TotalSupplyUpdatedHighres(
//         uint256 totalSupply,
//         uint256 rebasingCredits,
//         uint256 rebasingCreditsPerToken
//     );

//     /**
//      * @dev Get the credits per token for an account. Returns a fixed amount
//      *      if the account is non-rebasing.
//      * @param _account Address of the account.
//      */
//     function _creditsPerToken(address _account) internal view returns (uint256) {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         if (s.nonRebasingCreditsPerToken[_account] != 0) {
//             return s.nonRebasingCreditsPerToken[_account];
//         } else {
//             return s._rebasingCreditsPerToken;
//         }
//     }

//     /**
//      * @param _from     The address you want to send tokens from.
//      * @param _to       The address you want to transfer to.
//      * @param _value    Amount of fiAssets to transfer
//      */
//     function _executeTransfer(
//         address _from,
//         address _to,
//         uint256 _value
//     ) internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         bool isNonRebasingTo = _isNonRebasingAccount(_to);
//         bool isNonRebasingFrom = _isNonRebasingAccount(_from);
//         // Added this to track yield.
//         s.yieldExcl[_from] += int256(_value);
//         s.yieldExcl[_to] -= int256(_value);

//         // Credits deducted and credited might be different due to the
//         // differing creditsPerToken used by each account
//         uint256 creditsCredited = _value.mulTruncate(_creditsPerToken(_to));
//         uint256 creditsDeducted = _value.mulTruncate(_creditsPerToken(_from));

//         s._creditBalances[_from] = s._creditBalances[_from].sub(
//             creditsDeducted,
//             'LibERC20Token: Transfer amount exceeds balance'
//         );
//         s._creditBalances[_to] = s._creditBalances[_to].add(creditsCredited);

//         if (isNonRebasingTo && !isNonRebasingFrom) {
//             // Transfer to non-rebasing account from rebasing account, credits
//             // are removed from the non rebasing tally
//             s.nonRebasingSupply = s.nonRebasingSupply.add(_value);
//             // Update rebasingCredits by subtracting the deducted amount
//             s._rebasingCredits = s._rebasingCredits.sub(creditsDeducted);
//         } else if (!isNonRebasingTo && isNonRebasingFrom) {
//             // Transfer to rebasing account from non-rebasing account
//             // Decreasing non-rebasing credits by the amount that was sent
//             s.nonRebasingSupply = s.nonRebasingSupply.sub(_value);
//             // Update rebasingCredits by adding the credited amount
//             s._rebasingCredits = s._rebasingCredits.add(creditsCredited);
//         }
//     }

//     /**
//      * @dev Transfer tokens from one address to another.
//      * @param _from     The address you want to send tokens from.
//      * @param _to       The address you want to transfer to.
//      * @param _value    The amount of tokens to be transferred.
//      */
//     function _transferFrom(
//         address _from,
//         address _to,
//         uint256 _value
//     ) internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         require(_to != address(0), 'LibERC20Token: Transfer to zero address');
//         require(s.paused < 1, 'LibERC20Token: Token paused');
//         require(_value <= _balanceOf(_from), 'LibERC20Token: Transfer greater than balance');
//         require(s.frozen[_from] < 1, 'LibERC20Token: Sender account is frozen');
//         require(s.frozen[_to] < 1, 'LibERC20Token: Recipient account is frozen');

//         if (_from != msg.sender || s._allowances[_from][msg.sender] != type(uint256).max) {
//             s._allowances[_from][msg.sender] = s._allowances[_from][msg.sender].sub(_value);
//         }
//     }

//     /**
//      * @dev Is an account using rebasing accounting or non-rebasing accounting?
//      *      Also, ensure contracts are non-rebasing if they have not opted in.
//      * @param _account Address of the account.
//      */
//     function _isNonRebasingAccount(address _account) internal returns (bool) {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         bool isContract = Address.isContract(_account);
//         if (isContract && s.rebaseState[_account] == RebaseOptions.NotSet) {
//             _ensureRebasingMigration(_account);
//         }
//         return s.nonRebasingCreditsPerToken[_account] > 0;
//     }

//     /**
//      * @dev Ensures internal account for rebasing and non-rebasing credits and
//      *      supply is updated following deployment of frozen yield change.
//      */
//     function _ensureRebasingMigration(address _account) internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         if (s.nonRebasingCreditsPerToken[_account] == 0) {
//             if (s._creditBalances[_account] == 0) {
//                 // Since there is no existing balance, we can directly set to
//                 // high resolution, and do not have to do any other bookkeeping
//                 s.nonRebasingCreditsPerToken[_account] = 1e27;
//             } else {
//                 // Migrate an existing account:

//                 // Set fixed credits per token for this account
//                 s.nonRebasingCreditsPerToken[_account] = s._rebasingCreditsPerToken;
//                 // Update non rebasing supply
//                 s.nonRebasingSupply = s.nonRebasingSupply.add(_balanceOf(_account));
//                 // Update credit tallies
//                 s._rebasingCredits = s._rebasingCredits.sub(
//                     s._creditBalances[_account]
//                 );
//             }
//         }
//     }

//     function _balanceOf(address _account) internal view returns (uint256) {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         if (s._creditBalances[_account] == 0) return 0;
//         return
//             s._creditBalances[_account].divPrecisely(_creditsPerToken(_account));
//     }

//     /**
//      * @notice Returns the number of tokens from an amount of credits.
//      * @param _amount The amount of credits to convert to tokens.
//      */
//     function _creditsToBal(uint256 _amount) internal view returns (uint256) {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         return _amount.divPrecisely(s._rebasingCreditsPerToken);
//     }

//     /**
//      * @dev Increase the amount of tokens that an owner has allowed to
//      *      `_spender`.
//      *      This method should be used instead of approve() to avoid the double
//      *      approval vulnerability described above.
//      * @param _spender      The address which will spend the funds.
//      * @param _addedValue   The amount of tokens to increase the allowance by.
//      */
//     function _increaseAllowance(
//         address _spender,
//         uint256 _addedValue
//     ) internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         s._allowances[msg.sender][_spender] = s._allowances[msg.sender][_spender]
//             .add(_addedValue);
//     }

//     /**
//      * @dev Decrease the amount of tokens that an owner has allowed to
//             `_spender`.
//      * @param _spender          The address which will spend the funds.
//      * @param _subtractedValue  The amount of tokens to decrease the allowance
//      *                          by.
//      */
//     function _decreaseAllowance(
//         address _spender,
//         uint256 _subtractedValue
//     ) internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         uint256 oldValue = s._allowances[msg.sender][_spender];
//         if (_subtractedValue >= oldValue) {
//             s._allowances[msg.sender][_spender] = 0;
//         } else {
//             s._allowances[msg.sender][_spender] = oldValue.sub(_subtractedValue);
//         }
//     }

//     /**
//      * @dev Creates `_amount` tokens and assigns them to `_account`, increasing
//      * the total supply.
//      *
//      * Emits a {Transfer} event with `from` set to the zero address.
//      *
//      * Requirements
//      *
//      * - `to` cannot be the zero address.
//      */
//     function _mint(address _account, uint256 _amount) internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         require(_account != address(0), 'LibERC20Token: Mint to the zero address');

//         bool isNonRebasingAccount = _isNonRebasingAccount(_account);

//         uint256 creditAmount = _amount.mulTruncate(_creditsPerToken(_account));
//         s._creditBalances[_account] = s._creditBalances[_account].add(creditAmount);

//         s.yieldExcl[_account] -= int256(_amount); 

//         // If the account is non rebasing and doesn't have a set creditsPerToken
//         // then set it i.e. this is a mint from a fresh contract
//         if (isNonRebasingAccount) {
//             s.nonRebasingSupply = s.nonRebasingSupply.add(_amount);
//         } else {
//             s._rebasingCredits = s._rebasingCredits.add(creditAmount);
//         }

//         s._totalSupply = s._totalSupply.add(_amount);

//         require(s._totalSupply < MAX_SUPPLY, 'LibERC20Token: Max supply');
//     }

//     /**
//      * @dev Add a contract address to the non-rebasing exception list. The
//      * address's balance will be part of rebases and the account will be exposed
//      * to upside and downside.
//      */
//     function _rebaseOptIn() internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         require(s.rebaseLock[msg.sender] < 1, 'LibERC20Token: Account locked out of rebases');
//         require(_isNonRebasingAccount(msg.sender), 'LibERC20Token: Account has not opted out');

//         // Convert balance into the same amount at the current exchange rate
//         uint256 newCreditBalance = s._creditBalances[msg.sender]
//             .mul(s._rebasingCreditsPerToken)
//             .div(_creditsPerToken(msg.sender));

//         // Decreasing non rebasing supply
//         s.nonRebasingSupply = s.nonRebasingSupply.sub(_balanceOf(msg.sender));

//         s._creditBalances[msg.sender] = newCreditBalance;

//         // Increase rebasing credits, totalSupply remains unchanged so no
//         // adjustment necessary
//         s._rebasingCredits = s._rebasingCredits.add(s._creditBalances[msg.sender]);

//         s.rebaseState[msg.sender] = RebaseOptions.OptIn;

//         // Delete any fixed credits per token
//         delete s.nonRebasingCreditsPerToken[msg.sender];
//     }

//     /**
//      * @dev Add a contract address to the non-rebasing exception list. The
//      * address's balance will be part of rebases and the account will be exposed
//      * to upside and downside.
//      */
//     function _rebaseOptInExternal(address _account) internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         require(_isNonRebasingAccount(_account), 'LibERC20Token: Account has not opted out');

//         // Convert balance into the same amount at the current exchange rate
//         uint256 newCreditBalance = s._creditBalances[_account]
//             .mul(s._rebasingCreditsPerToken)
//             .div(_creditsPerToken(_account));

//         // Decreasing non rebasing supply
//         s.nonRebasingSupply = s.nonRebasingSupply.sub(_balanceOf(_account));

//         s._creditBalances[_account] = newCreditBalance;

//         // Increase rebasing credits, totalSupply remains unchanged so no
//         // adjustment necessary
//         s._rebasingCredits = s._rebasingCredits.add(s._creditBalances[_account]);

//         s.rebaseState[_account] = RebaseOptions.OptIn;

//         // Delete any fixed credits per token
//         delete s.nonRebasingCreditsPerToken[_account];
//     }

//     /**
//      * @dev Destroys `_amount` tokens from `_account`, reducing the
//      * total supply.
//      *
//      * Emits a {Transfer} event with `to` set to the zero address.
//      *
//      * Requirements
//      *
//      * - `_account` cannot be the zero address.
//      * - `_account` must have at least `_amount` tokens.
//      */
//     function _burn(address _account, uint256 _amount) internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         require(_account != address(0), 'LibERC20Token: Burn from the zero address');
//         if (_amount == 0) {
//             return;
//         }

//         bool isNonRebasingAccount = _isNonRebasingAccount(_account);
//         uint256 creditAmount = _amount.mulTruncate(_creditsPerToken(_account));
//         uint256 currentCredits = s._creditBalances[_account];

//         s.yieldExcl[_account] += int256(_amount);

//         // Remove the credits, burning rounding errors
//         if (currentCredits == creditAmount || currentCredits - 1 == creditAmount)
//             // Handle dust from rounding
//             s._creditBalances[_account] = 0;
//         else if (currentCredits > creditAmount)
//             s._creditBalances[_account] = s._creditBalances[_account].sub(
//                 creditAmount
//             );
//         else revert('LibERC20Token: Remove exceeds balance');

//         // Remove from the credit tallies and non-rebasing supply
//         if (isNonRebasingAccount)
//             s.nonRebasingSupply = s.nonRebasingSupply.sub(_amount);
//         else s._rebasingCredits = s._rebasingCredits.sub(creditAmount);

//         s._totalSupply = s._totalSupply.sub(_amount);
//     }

//     /**
//      * @dev Explicitly mark that an address is non-rebasing.
//      */
//     function _rebaseOptOut() internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         require(!_isNonRebasingAccount(msg.sender), 'LibERC20Token: Account has not opted in');

//         // Increase non rebasing supply
//         s.nonRebasingSupply = s.nonRebasingSupply.add(_balanceOf(msg.sender));
//         // Set fixed credits per token
//         s.nonRebasingCreditsPerToken[msg.sender] = s._rebasingCreditsPerToken;

//         // Decrease rebasing credits, total supply remains unchanged so no
//         // adjustment necessary
//         s._rebasingCredits = s._rebasingCredits.sub(s._creditBalances[msg.sender]);

//         // Mark explicitly opted out of rebasing
//         s.rebaseState[msg.sender] = RebaseOptions.OptOut;
//     }

//     /**
//      * @dev Explicitly mark that an address is non-rebasing.
//      */
//     function _rebaseOptOutExternal(address _account) internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         require(!_isNonRebasingAccount(_account), 'LibERC20Token: Account has not opted in');

//         // Increase non rebasing supply
//         s.nonRebasingSupply = s.nonRebasingSupply.add(_balanceOf(_account));
//         // Set fixed credits per token
//         s.nonRebasingCreditsPerToken[_account] = s._rebasingCreditsPerToken;

//         // Decrease rebasing credits, total supply remains unchanged so no
//         // adjustment necessary
//         s._rebasingCredits = s._rebasingCredits.sub(s._creditBalances[_account]);

//         // Mark explicitly opted out of rebasing
//         s.rebaseState[_account] = RebaseOptions.OptOut;
//     }

//     /**
//      * @dev Modify the supply without minting new tokens. This uses a change in
//      *      the exchange rate between "credits" and USDSTa tokens to change balances.
//      * @param _newTotalSupply New total supply of USDSTa.
//      */
//     function _changeSupply(uint256 _newTotalSupply) internal {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         require(s._totalSupply > 0, 'LibERC20Token: Cannot increase 0 supply');

//         if (s._totalSupply == _newTotalSupply) {
//             emit TotalSupplyUpdatedHighres(
//                 s._totalSupply,
//                 s._rebasingCredits,
//                 s._rebasingCreditsPerToken
//             );
//         }

//         s._totalSupply = _newTotalSupply > MAX_SUPPLY
//             ? MAX_SUPPLY
//             : _newTotalSupply;

//         s._rebasingCreditsPerToken = s._rebasingCredits.divPrecisely(
//             s._totalSupply.sub(s.nonRebasingSupply)
//         );

//         require(s._rebasingCreditsPerToken > 0, 'LibERC20Token: Invalid change in supply');

//         s._totalSupply = s._rebasingCredits
//             .divPrecisely(s._rebasingCreditsPerToken)
//             .add(s.nonRebasingSupply);

//         emit TotalSupplyUpdatedHighres(
//             s._totalSupply,
//             s._rebasingCredits,
//             s._rebasingCreditsPerToken
//         );
//     }

//     /**
//      * @dev     Helper function to convert credit balance to token balance.
//      * @param   _creditBalance The credit balance to convert.
//      * @return  assets The amount converted to token balance.
//      */
//     function _convertToAssets(uint _creditBalance) internal view returns (uint assets) {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         assets = _creditBalance == 0
//             ? 0
//             : _creditBalance.divPrecisely(s._rebasingCreditsPerToken);
//     }

//     /**
//      * @dev     Helper function to convert token balance to credit balance.
//      * @param   _tokenBalance The token balance to convert.
//      * @return  credits The amount converted to credit balance.
//      */
//     function _convertToCredits(uint _tokenBalance) internal view returns (uint credits) {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         credits = _tokenBalance == 0
//             ? 0
//             : _tokenBalance.mulTruncate(s._rebasingCreditsPerToken);
//     }

//     function _getYieldEarned(address _account) internal view returns (uint256) {
//         ERC20Storage storage s = LibERC20Storage.diamondStorage();

//         if (s.yieldExcl[_account] == 0) {
//             return 0;
//         }
//         else if (s.yieldExcl[_account] > 0) {
//             return LibERC20Token._balanceOf(_account) + s.yieldExcl[_account].abs();
//         } else {
//             return LibERC20Token._balanceOf(_account) - s.yieldExcl[_account].abs();
//         }
//     }
// }