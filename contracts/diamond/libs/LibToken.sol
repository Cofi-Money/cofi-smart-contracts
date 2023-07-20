// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AppStorage, LibAppStorage } from "./LibAppStorage.sol";
import { PercentageMath } from "./external/PercentageMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IFiToken } from ".././interfaces/IFiToken.sol";
import 'contracts/token/utils/StableMath.sol';

library LibToken {
    using PercentageMath for uint256;
    using StableMath for uint256;

    /// @notice Emitted when a transfer is executed.
    ///
    /// @param  asset           The asset transferred (underlying, share, or fi token).
    /// @param  amount          The amount transferred.
    /// @param  transferFrom    The account the asset was transferred from.
    /// @param  recipient       The recipient of the transfer.
    event Transfer(address indexed asset, uint256 amount, address indexed transferFrom, address indexed recipient);

    /// @notice Emitted when a fi is minted.
    ///
    /// @param  fi      The address of the minted fi token.
    /// @param  amount  The amount of fis minted.
    /// @param  to      The recipient of the minted fis.
    event Mint(address indexed fi, uint256 amount, address indexed to);

    /// @notice Emitted when a fi is burned.
    ///
    /// @param  fi      The address of the burned fi.
    /// @param  amount  The amount of fis burned.
    /// @param  from    The account burned from.
    event Burn(address indexed fi, uint256 amount, address indexed from);

    /// @notice Emitted when a fi supply update is executed.
    ///
    /// @param  fi      The fi token with updated supply.
    /// @param  assets  The new total supply.
    /// @param  yield   The amount of yield added.
    /// @param  rCPT    Rebasing credits per token of FiToken.sol contract (used to calc interest rate).
    /// @param  fee     The service fee captured, which is a share of the yield generated.
    event TotalSupplyUpdated(address indexed fi, uint256 assets, uint256 yield, uint256 rCPT, uint256 fee);

    /// @notice Emitted when a deposit action is executed.
    ///
    /// @param  asset       The asset deposited (e.g., USDC).
    /// @param  amount      The amount deposited.
    /// @param  depositFrom The account assets were transferred from.
    /// @param  fee         The mint fee captured.
    event Deposit(address indexed asset, uint256 amount, address indexed depositFrom, uint256 fee);

    /// @notice Emitted when a withdrawal action is executed.
    ///
    /// @param  asset       The asset being withdrawn (e.g., USDC).
    /// @param  amount      The amount withdrawn.
    /// @param  depositFrom The account fi tokens were transferred from.
    /// @param  fee         The redeem fee captured.
    event Withdraw(address indexed asset, uint256 amount, address indexed depositFrom, uint256 fee);

    /// @notice Executes a transferFrom operation in the context of COFI.
    ///
    /// @param  _asset      The asset to transfer.
    /// @param  _amount     The amount to transfer.
    /// @param  _sender     The account to transfer from, must have approved spender.
    /// @param  _recipient  The recipient of the transfer.
    function _transferFrom(
        address _asset,
        uint256 _amount,
        address _sender,
        address _recipient
    )   internal {

        SafeERC20.safeTransferFrom(
            IERC20(_asset),
            _sender,
            _recipient,
            _amount
        );
        emit Transfer(_asset, _amount, _sender, _recipient);
    }

    /// @notice Executes a transfer operation in the context of Stoa.
    ///
    /// @param  _asset      The asset to transfer.
    /// @param  _amount     The amount to transfer.
    /// @param  _recipient  The recipient of the transfer.
    function _transfer(
        address _asset,
        uint256 _amount,
        address _recipient
    ) internal {

        SafeERC20.safeTransfer(
            IERC20(_asset),
            _recipient,
            _amount
        );
        emit Transfer(_asset, _amount, address(this), _recipient);
    }

    /// @notice Executes a mint operation in the context of COFI.
    ///
    /// @param  _fi     The fi token to mint.
    /// @param  _to     The account to mint to.
    /// @param  _amount The amount of fi tokens to mint.
    function _mint(
        address _fi,
        address _to,
        uint256 _amount
    ) internal {

        IFiToken(_fi).mint(_to, _amount);
        emit Mint(_fi, _amount, _to);
    }


    /// @notice Executes a mint operation and opts the receiver into rebases.
    ///
    /// @param  _fi     The fi token to mint.
    /// @param  _to     The account to mint to.
    /// @param  _amount The amount of fi tokens to mint.
    function _mintOptIn(
        address _fi,
        address _to,
        uint256 _amount
    ) internal {

        IFiToken(_fi).mintOptIn(_to, _amount);
        emit Mint(_fi, _amount, _to);
    }

    /// @notice Executes a burn operation in the context of COFI.
    ///
    /// @param  _fi     The fi token to burn.
    /// @param  _from   The account to burn from.
    /// @param  _amount The amount of fis to burn.
    function _burn(
        address _fi,
        address _from,
        uint256 _amount
    ) internal {

        IFiToken(_fi).burn(_from, _amount);
        emit Burn(_fi, _amount, _from);
    }

    /// @notice Calls redeem operation on FiToken contract.
    ///
    /// @dev    Skips approval check.
    ///
    /// @param _fi      The fi token to redeem.
    /// @param _from    The account to redeem from.
    /// @param _amount  The amount of fi tokens to redeem.
    function _redeem(
        address _fi,
        address _from,
        uint256 _amount
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        IFiToken(_fi).redeem(_from, s.feeCollector, _amount);
    }

    /// @notice Updates the total supply of the fi token.
    ///
    /// @dev    Will revert if the new supply < old supply.
    ///
    /// @param _fi      The fi token to change supply for.
    /// @param _amount  The new supply.
    /// @param _yield   The amount of yield accrued.
    /// @param _fee     The service fee captured.
    function _changeSupply(
        address _fi,
        uint256 _amount,
        uint256 _yield,
        uint256 _fee
    ) internal {
        
        IFiToken(_fi).changeSupply(_amount);
        emit TotalSupplyUpdated(
            _fi,
            _amount,
            _yield,
            IFiToken(_fi).rebasingCreditsPerTokenHighres(),
            _fee
        );
    }

    /// @notice Returns the rCPT for a given fi token.
    ///
    /// @param _fi  The fi token to enquire for.
    function _getRebasingCreditsPerToken(
        address _fi
    ) internal view returns (uint256) {

        return IFiToken(_fi).rebasingCreditsPerTokenHighres();
    }

    /// @notice Returns the mint fee for a given fi token.
    ///
    /// @param  _fi     The fi token to mint.
    /// @param  _amount The amount of fi tokens to mint.
    function _getMintFee(
        address _fi,
        uint256 _amount
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return _amount.percentMul(s.mintFee[_fi]);
    }

    /// @notice Returns the redeem fee for a given fi token.
    ///
    /// @param  _fi     The fi token to redeem.
    /// @param  _amount The amount of fi tokens to redeem
    function _getRedeemFee(
        address _fi,
        uint256 _amount
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return _amount.percentMul(s.redeemFee[_fi]);
    }

    /// @notice Opts contract into receiving rebases.
    ///
    /// @param  _fi The fi token to opt-in to rebases for.
    function _rebaseOptIn(
        address _fi
    ) internal {

        IFiToken(_fi).rebaseOptIn();
    }

    /// @notice Opts contract out of receiving rebases.
    ///
    /// @param  _fi The fi token to opt-out of rebases for.
    function _rebaseOptOut(
        address _fi
    ) internal {
        
        IFiToken(_fi).rebaseOptOut();
    }

    /// @notice Retrieves yield earned of fi for account.
    ///
    /// @param  _account    The account to enquire for.
    /// @param  _fi         The fi token to check account's yield for.
    function _getYieldEarned(
        address _account,
        address _fi
    ) internal view returns (uint256) {
        
        return IFiToken(_fi).getYieldEarned(_account);
    }

    /// @notice Represents an underlying token decimals in fi decimals.
    ///
    /// @param _fi      Retrieves the underlying decimals from mapping.
    /// @param _amount  The amount of underlying to translate.
    function _toFiDecimals(
        address _fi,
        uint256 _amount
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return _amount.scaleBy(18, s.decimals[s.underlying[_fi]]);
    }

    /// @notice Represents a fi token in its underlying decimals.
    ///
    /// @param _fi      Retrieves the underlying decimals from mapping.
    /// @param _amount  The amount of underlying to translate.
    function _toUnderlyingDecimals(
        address _fi,
        uint256 _amount
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return _amount.scaleBy(s.decimals[s.underlying[_fi]], 18);
    }
}