// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BridgedToken is ERC20 {

    address public unbridge;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 decimals_
    ) ERC20(_name, _symbol) {
        _decimals = decimals_;
        unbridge = msg.sender;
    }

    uint8 private _decimals;

    modifier onlyUnbridge() {
        require(msg.sender == unbridge, "BridgedToken: Caller not Unbridge contract");
        _;
    }

    /// @notice Grants minting and burning capabilities only to unbridge contract.
    function setUnbridge(address _unbridge) external onlyUnbridge {
        unbridge = _unbridge;
    }

    function mint(address _to, uint _amount) external onlyUnbridge {
        _mint(_to, _amount);
    }

    function burn(address _from, uint _amount) external onlyUnbridge {
        _burn(_from, _amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}