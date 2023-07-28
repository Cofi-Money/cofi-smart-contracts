// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 decimals_
    ) ERC20(_name, _symbol) { _decimals = decimals_; }

    uint8 private _decimals;

    function mint(address _to, uint _amount) external {
        _mint(_to, _amount);
    }

    function burn(address _from, uint _amount) external {
        _burn(_from, _amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}