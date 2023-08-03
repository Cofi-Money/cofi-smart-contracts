// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { Modifiers } from '../libs/LibERC20Storage.sol';
// import { LibERC20Token } from '../libs/LibERC20Token.sol';

// contract TokenRebaseFacet is Modifiers {

//     /**
//      * @return Low resolution rebasingCreditsPerToken
//      */
//     function rebasingCreditsPerToken() public view returns (uint256) {
//         return s._rebasingCreditsPerToken / LibERC20Token.RESOLUTION_INCREASE;
//     }

//     /**
//      * @return Low resolution total number of rebasing credits
//      */
//     function rebasingCredits() public view returns (uint256) {
//         return s._rebasingCredits / LibERC20Token.RESOLUTION_INCREASE;
//     }

//     /**
//      * @return High resolution rebasingCreditsPerToken
//      */
//     function rebasingCreditsPerTokenHighres() public view returns (uint256) {
//         return s._rebasingCreditsPerToken;
//     }

//     /**
//      * @return High resolution total number of rebasing credits
//      */
//     function rebasingCreditsHighres() public view returns (uint256) {
//         return s._rebasingCredits;
//     }

//     /**
//      * @notice Returns the number of tokens from an amount of credits.
//      * @param _amount The amount of credits to convert to tokens.
//      */
//     function creditsToBal(uint256 _amount) external view returns (uint256) {
//         return LibERC20Token._creditsToBal(_amount);
//     }

//     /**
//      * @dev Gets the credits balance of the specified address.
//      * @dev Backwards compatible with old low res credits per token.
//      * @param _account  The address to query the balance of.
//      * @return          (uint256, uint256) Credit balance and credits per token of the
//      *                  address
//      */
//     function creditsBalanceOf(address _account) public view returns (uint256, uint256) {
//         uint256 cpt = LibERC20Token._creditsPerToken(_account);
//         if (cpt == 1e27) {
//             // For a period before the resolution upgrade, we created all new
//             // contract accounts at high resolution. Since they are not changing
//             // as a result of this upgrade, we will return their true values
//             return (s._creditBalances[_account], cpt);
//         } else {
//             return (
//                 s._creditBalances[_account] / LibERC20Token.RESOLUTION_INCREASE,
//                 cpt / LibERC20Token.RESOLUTION_INCREASE
//             );
//         }
//     }

//     /**
//      * @dev Gets the credits balance of the specified address.
//      * @param _account  The address to query the balance of.
//      * @return          (uint256, uint256, bool) Credit balance, credits per token of the
//      *                  address, and isUpgraded
//      */
//     function creditsBalanceOfHighres(
//         address _account
//     ) public view returns (uint256, uint256, bool) {
//         return (
//             s._creditBalances[_account],
//             LibERC20Token._creditsPerToken(_account),
//             s.isUpgraded[_account] == 1
//         );
//     }

//     /**
//      * @dev Add a contract address to the non-rebasing exception list. The
//      * address's balance will be part of rebases and the account will be exposed
//      * to upside and downside.
//      */
//     function rebaseOptIn() public returns (bool) {
//         LibERC20Token._rebaseOptIn();

//         return true;
//     }

//     /**
//      * @dev Add a contract address to the non-rebasing exception list. The
//      * address's balance will be part of rebases and the account will be exposed
//      * to upside and downside.
//      */
//     function rebaseOptInExternal(address _account) public onlyAuthorized returns (bool) {
//         LibERC20Token._rebaseOptInExternal(_account);

//         return true;
//     }

//     /**
//      * @dev Explicitly mark that an address is non-rebasing.
//      */
//     function rebaseOptOut() public returns (bool) {
//         LibERC20Token._rebaseOptOut();

//         return true;
//     }

//     /**
//      * @dev Explicitly mark that an address is non-rebasing.
//      */
//     function rebaseOptOutExternal(address _account) public onlyAuthorized returns (bool) {
//         LibERC20Token._rebaseOptOutExternal(_account);

//         return true;
//     }

//     /**
//      * @dev Modify the supply without minting new tokens. This uses a change in
//      *      the exchange rate between "credits" and USDSTa tokens to change balances.
//      * @param _newTotalSupply New total supply of USDSTa.
//      */
//     function changeSupply(uint256 _newTotalSupply) external onlyApp returns (bool) {
//         LibERC20Token._changeSupply(_newTotalSupply);

//         return true;
//     }

//     function getYieldEarned(address _account) external view returns (uint256) {
//         return LibERC20Token._getYieldEarned(_account);
//     }

//     /**
//      * @dev     Helper function to convert credit balance to token balance.
//      * @param   _creditBalance The credit balance to convert.
//      * @return  assets The amount converted to token balance.
//      */
//     function convertToAssets(uint _creditBalance) public view returns (uint assets) {
//         return LibERC20Token._convertToAssets(_creditBalance);
//     }

//     /**
//      * @dev     Helper function to convert token balance to credit balance.
//      * @param   _tokenBalance The token balance to convert.
//      * @return  credits The amount converted to credit balance.
//      */
//     function convertToCredits(uint _tokenBalance) public view returns (uint credits) {
//         return LibERC20Token._convertToCredits(_tokenBalance);
//     }
// }