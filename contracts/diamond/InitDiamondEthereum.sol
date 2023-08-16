// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDiamond } from './core/libs/LibDiamond.sol';
import { IERC165 } from './core/interfaces/IERC165.sol';
import { IDiamondCut } from './core/interfaces/IDiamondCut.sol';
import { IDiamondLoupe } from './core/interfaces/IDiamondLoupe.sol';
import { IERC173 } from './core/interfaces/IERC173.sol';
import { AppStorage } from './libs/LibAppStorage.sol';
import { LibToken } from './libs/LibToken.sol';

contract InitDiamondEthereum {
    AppStorage internal s;

    struct Args {
        address     coUSD;  // cofi token [USD]
        address     vDAI;   // vault share token [USD]
        address     DAI;    // underlying token [USD]
        // msg.sender is Admin + Whiteslited by default, so do not need to include.
        address[]   roles;
    }
    
    function init(Args memory _args) external {

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // Adding ERC165 data.
        ds.supportedInterfaces[type(IERC165).interfaceId]       = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId]   = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId]       = true;

        s.underlying[_args.coUSD] = _args.DAI;

        // Set min deposit/withdraw values (target $20).
        s.minDeposit[_args.coUSD]   = 1e6 - 1; // 1 DAI [6 digits].
        s.minWithdraw[_args.coUSD]  = 1e6 - 1; // 1 DAI.

        s.vault[_args.coUSD] = _args.vDAI;

        // Set mint enabled.
        s.mintEnabled[_args.coUSD] = 1;

        // Set mint fee.
        s.mintFee[_args.coUSD] = 10;

        // Set redeem enabled.
        s.redeemEnabled[_args.coUSD] = 1;

        // Set redeem fee.
        s.redeemFee[_args.coUSD] = 10;

        // Set service fee.
        s.serviceFee[_args.coUSD] = 125;

        // Set points rate.
        s.pointsRate[_args.coUSD]   = 1e6;  // 100 points/1.0 coUSD earned.

        s.owner         = msg.sender;
        s.backupOwner   = _args.roles[1];
        s.feeCollector  = _args.roles[2];

        s.initReward    = 100*10**18;   // 100 Points for initial deposit.
        s.referReward   = 10*10**18;    // 10 Points each for each referral.

        s.decimals[_args.DAI] = 18;

        // 10 DAI buffer for migrations.
        s.buffer[_args.coUSD] = 10*10**uint256(s.decimals[_args.DAI]);

        s.isAdmin[msg.sender] = 1;
        s.isWhitelisted[msg.sender] = 1;

        // Set admins.
        for(uint i = 1; i < _args.roles.length; ++i) {
            s.isAdmin[_args.roles[i]] = 1;
            s.isWhitelisted[_args.roles[i]] = 1;
        }

        // Set accounts that can whitelist
        // First account can whitelist but is not admin
        for(uint i = 0; i < _args.roles.length; ++i) {
            s.isWhitelister[_args.roles[i]] = 1;
        }
    }
}