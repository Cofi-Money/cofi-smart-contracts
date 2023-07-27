// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20Storage } from "./libs/LibERC20Storage.sol";
// Can borrow core files from app
import { LibDiamond } from "../../diamond/core/libs/LibDiamond.sol";
import { IERC165 } from "../../diamond/core/interfaces/IERC165.sol";
import { IDiamondCut } from "../../diamond/core/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "../../diamond/core/interfaces/IDiamondLoupe.sol";
import { IERC173 } from "../../diamond/core/interfaces/IERC173.sol";

contract ERC20InitDiamond {
    ERC20Storage internal s;

    struct Args {
        string name;
        string symbol;
        address app;
        // msg.sender is Admin + Whiteslited by default, so do not need to include.
        address[] roles;
    }
    
    function init(Args memory _args) external {

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // Adding ERC165 data.
        ds.supportedInterfaces[type(IERC165).interfaceId]       = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId]   = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId]       = true;

        s.name      = _args.name;
        s.symbol    = _args.symbol;
        s.decimals  = 18;

        s.app = _args.app;

        s._rebasingCreditsPerToken = 1e18;

        s.owner = _args.roles[0];
        s.backupOwner = _args.roles[1];
        s.admin[_args.roles[0]] = 1;
        s.admin[_args.roles[1]] = 1;
    }
}