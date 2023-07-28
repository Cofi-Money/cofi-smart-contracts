// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers } from '../libs/LibERC20Storage.sol';
import { LibERC20Token } from '../libs/LibERC20Token.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
// import { ERC20Permit } from '../../utils/draft-ERC20Permit.sol';

/// @dev To-do: Add permit, reentrancy guard, and relevant testing.

contract TokenERC20Facet is IERC20, Modifiers {

    /**
     * @dev Mints new tokens, increasing totalSupply.
     */
    function mint(address _account, uint256 _amount) external onlyApp returns (bool) {
        // Ignore 'paused' check, as this is covered by 'mintEnabled' in Diamond.
        require(s.frozen[_account] < 1, 'TokenERC20Facet: Recipient account is frozen');
        LibERC20Token._mint(_account, _amount);

        emit Transfer(address(0), _account, _amount);
        return true;
    }

    /**
     * @dev Additional function for opting the account in after minting.
     */
    function mintOptIn(address _account, uint256 _amount) external onlyApp returns (bool) {
        // Ignore 'paused' check, as this is covered by 'mintEnabled' in Diamond.
        require(s.frozen[_account] < 1, 'TokenERC20Facet: Recipient account is frozen');
        LibERC20Token._mint(_account, _amount);

        if (LibERC20Token._isNonRebasingAccount(_account)) {
            LibERC20Token._rebaseOptInExternal(_account);
        }

        emit Transfer(address(0), _account, _amount);
        return true;
    }

    /**
     * @notice  Redeem function, only callable from Diamond, to return fiAssets.
     * @dev     Skips approval check.
     * @param _from     The address to redeem fiAssets from.
     * @param _to       The 'feeCollector' address to receive fiAssets.
     * @param _value    The amount of fiAssets to redeem.
     * @return          True on success.
     */
    function redeem(
        address _from,
        address _to,
        uint256 _value
    ) external onlyApp returns (bool) {
        // Ignore 'paused' check, as this is covered by 'redeemEnabled' in Diamond.

        LibERC20Token._executeTransfer(_from, _to, _value);

        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @dev Burns tokens, decreasing totalSupply.
     *      When an account burns tokens without redeeming, the amount burned is
     *      essentially redistributed to the remaining holders upon the next rebase.
     */
    function burn(address _account, uint256 _amount) external returns (bool) {
        if (msg.sender != s.app)
            require(_account == msg.sender, 'ERC20Facet: Caller not owner');
        require(s.paused < 1, 'ERC20Facet: Token paused');
        LibERC20Token._burn(_account, _amount);

        emit Transfer(_account, address(0), _amount);
        return true;
    }

    /**
     * @dev Transfer tokens to a specified address.
     * @param _to       The address to transfer to.
     * @param _value    The amount to be transferred.
     * @return          True on success.
     */
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0), 'TokenERC20Facet: Transfer to zero address');
        require(s.paused < 1, 'TokenERC20Facet: Token paused');
        require(_value <= balanceOf(msg.sender), 'TokenERC20Facet: Transfer greater than balance');
        require(s.frozen[msg.sender] < 1, 'TokenERC20Facet: Caller is frozen');
        require(s.frozen[_to] < 1, 'TokenERC20Facet: Recipient account is frozen');

        LibERC20Token._executeTransfer(msg.sender, _to, _value);

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * @param _from     The address you want to send tokens from.
     * @param _to       The address you want to transfer to.
     * @param _value    The amount of tokens to be transferred.
     * @return          True on success.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool) {
        LibERC20Token._transferFrom(_from, _to, _value);

        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens
     *      on behalf of msg.sender. This method is included for ERC20
     *      compatibility. `increaseAllowance` and `decreaseAllowance` should be
     *      used instead.
     *
     *      Changing an allowance with this method brings the risk that someone
     *      may transfer both the old and the new allowance - if they are both
     *      greater than zero - if a transfer transaction is mined before the
     *      later approve() call is mined.
     * @param _spender  The address which will spend the funds.
     * @param _value    The amount of tokens to be spent.
     */
    function approve(address _spender, uint256 _value) public returns (bool) {
        s._allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner has allowed to
     *      `_spender`.
     *      This method should be used instead of approve() to avoid the double
     *      approval vulnerability described above.
     * @param _spender      The address which will spend the funds.
     * @param _addedValue   The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(
        address _spender,
        uint256 _addedValue
    ) public returns (bool) {
        LibERC20Token._increaseAllowance(_spender, _addedValue);

        emit Approval(msg.sender, _spender, s._allowances[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner has allowed to
            `_spender`.
     * @param _spender          The address which will spend the funds.
     * @param _subtractedValue  The amount of tokens to decrease the allowance
     *                          by.
     */
    function decreaseAllowance(
        address _spender,
        uint256 _subtractedValue
    ) public returns (bool) {
        LibERC20Token._decreaseAllowance(_spender, _subtractedValue);

        emit Approval(msg.sender, _spender, s._allowances[msg.sender][_spender]);
        return true;
    }

    function name() public view returns (string memory) {
        return s.name;
    }

    function symbol() public view returns (string memory) {
        return s.symbol;
    }

    function decimals() public view returns (uint8) {
        return s.decimals;
    }

    /**
     * @return The total supply of OUSD.
     */
    function totalSupply() public view returns (uint256) {
        return s._totalSupply;
    }

    /**
     * @dev     Gets the balance of the specified address.
     * @param   _account Address to query the balance of.
     * @return  A uint256 representing the amount of base units owned by the
     *          specified address.
     */
    function balanceOf(address _account) public view returns (uint256) {
        return LibERC20Token._balanceOf(_account);
    }

    /**
     * @dev Function to check the amount of tokens that _owner has allowed to
     *      `_spender`.
     * @param   _owner The address which owns the funds.
     * @param   _spender The address which will spend the funds.
     * @return  The number of tokens still available for the _spender.
     */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return s._allowances[_owner][_spender];
    }
}