// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

interface ICOFIMoney {

    function getPoints(address account, address[] memory fiAssets) external view returns (uint256 pointsTotal);
}

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author The Stoa Corporation Ltd.
    @title  Point Token Facet
    @notice Merely provides ERC20 representation and therefore ensures Points are viewable in browser wallet.
            Transfer methods are effectively renounced.
 */

contract PointToken is ERC20 {

    constructor(
        string memory       _name,
        string memory       _symbol,
        address             _diamond,
        address[] memory    _fiAssets
    ) ERC20(_name, _symbol) { 
        diamond = _diamond;
        fiAssets = _fiAssets;
        admin[msg.sender] = true;
    }

    address     diamond;
    address[]   fiAssets;

    mapping(address => bool) admin;

    /**
     * NOTE This contract does not include 'mint'/'burn' functions as does not have a token supply.
            By extension, 'transfer' and 'transferFrom' will not execute.
     */

    function balanceOf(address _account)
        public
        view
        override
        returns (uint256)
    {
        return ICOFIMoney(diamond).getPoints(_account, fiAssets);
    }

    function setFiAssets(address[] memory _fiAssets) external isAdmin {
        fiAssets = _fiAssets;
    }

    function setDiamond(address _diamond) external isAdmin {
        diamond = _diamond;
    }

    function toggleAdmin(address _account) external isAdmin {
        admin[_account] = !admin[_account];
    }

    modifier isAdmin() {
        require(admin[msg.sender] == true, 'PointToken: Caller not admin');
        _;
    }
}