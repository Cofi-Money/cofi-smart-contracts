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
            Mint, burn, and transfer methods are effectively renounced.
 */

contract PointToken is ERC20 {

    constructor(
        string memory       _name,
        string memory       _symbol,
        address             _app,
        address[] memory    _fi
    ) ERC20(_name, _symbol) { 
        app = _app;
        fi  = _fi;
        admin[msg.sender] = 1;
    }

    address     app;
    address[]   fi;

    mapping(address => uint8) admin;

    /**
     * NOTE This contract does not include 'mint'/'burn' functions as does not have a token supply.
            By extension, 'transfer' and 'transferFrom' will not execute.
     */

    function balanceOf(address _account) public view override returns (uint256) {
        return ICOFIMoney(app).getPoints(_account, fi);
    }

    function setFi(address[] memory _fi) external isAdmin {
        fi = _fi;
    }

    function setApp(address _app) external isAdmin {
        app = _app;
    }

    function setAdmin(address _account, uint8 _enabled) external isAdmin {
        admin[_account] = _enabled;
    }

    modifier isAdmin() {
        require(admin[msg.sender] > 0, 'PointToken: Caller not admin');
        _;
    }
}