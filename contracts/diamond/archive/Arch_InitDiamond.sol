// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import { AppStorage } from './libs/LibAppStorage.sol';
// import { LibDiamond } from './core/libs/LibDiamond.sol';
// import { LibToken } from './libs/LibToken.sol';
// import { IERC165 } from './core/interfaces/IERC165.sol';
// import { IDiamondCut } from './core/interfaces/IDiamondCut.sol';
// import { IDiamondLoupe } from './core/interfaces/IDiamondLoupe.sol';
// import { IERC173 } from './core/interfaces/IERC173.sol';
// import { IERC20 } from '@openzeppelin/contracts/interfaces/IERC20.sol';

// contract InitDiamond {
//     AppStorage internal s;

//     struct Args {
//         address     fiUSD;  // fi token [USD]
//         address     fiETH;  // fi token [ETH]
//         address     fiBTC;  // fi token [BTC]
//         address     vUSDC;  // vault share token [USD]
//         address     vETH;   // vault share token [ETH]
//         address     vBTC;   // vault share token [BTC]
//         address     USDC;   // underlying token [USD]
//         address     wETH;   // underlying token [ETH]
//         address     wBTC;   // underlying token [BTC]
//         // msg.sender is Admin + Whiteslited by default, so do not need to include.
//         address[]   roles;
//     }
    
//     function init(Args memory _args) external {

//         LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

//         // Adding ERC165 data.
//         ds.supportedInterfaces[type(IERC165).interfaceId]       = true;
//         ds.supportedInterfaces[type(IDiamondCut).interfaceId]   = true;
//         ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
//         ds.supportedInterfaces[type(IERC173).interfaceId]       = true;

//         s.underlying[_args.fiUSD] = _args.USDC;
//         s.underlying[_args.fiETH] = _args.wETH;
//         s.underlying[_args.fiBTC] = _args.wBTC;

//         // Set DerivParams if used.
//         s.derivParams[_args.vUSDC].spender = 0x3c0FFAca566fCcfD9Cc95139FEF6CBA143795963;
//         s.derivParams[_args.vUSDC].toDeriv = bytes4(keccak256("toDeriv_BeefyHop(address,uint256)"));
//         s.derivParams[_args.vUSDC].toUnderlying = bytes4(keccak256("toUnderlying_BeefyHop(address, uint256)"));
//         s.derivParams[_args.vUSDC].convertToDeriv = bytes4(keccak256("convertToUnderlying_BeefyHop(uint256)"));
//         s.derivParams[_args.vUSDC].convertToUnderlying = bytes4(keccak256("convertToDeriv_BeefyHop(uint256)"));

//         // Set min deposit/withdraw values (target $20).
//         s.minDeposit[_args.fiUSD]   = 20e6 - 1; // 20 USDC [6 digits].
//         s.minDeposit[_args.fiETH]   = 1e16 - 1; // 0.01 ETH [18 digits].
//         s.minDeposit[_args.fiBTC]   = 1e5 - 1;  // 0.001 BTC [8 digits].
//         s.minWithdraw[_args.fiUSD]  = 20e6 - 1; // 20 USDC.
//         s.minWithdraw[_args.fiETH]  = 1e16 - 1; // 0.01 ETH.
//         s.minWithdraw[_args.fiBTC]  = 1e5 - 1;  // 0.001 BTC.

//         s.vault[_args.fiUSD]    = _args.vUSDC;
//         s.vault[_args.fiETH]    = _args.vETH;
//         s.vault[_args.fiBTC]    = _args.vBTC;

//         s.harvestable[s.vault[_args.fiUSD]] = 1;
//         s.harvestable[s.vault[_args.fiETH]] = 1;
//         s.harvestable[s.vault[_args.fiBTC]] = 1;

//         // Set mint enabled.
//         s.mintEnabled[_args.fiUSD]  = 1;
//         s.mintEnabled[_args.fiETH]  = 1;
//         s.mintEnabled[_args.fiBTC]  = 1;

//         // Set mint fee.
//         s.mintFee[_args.fiUSD]  = 10;
//         s.mintFee[_args.fiETH]  = 10;
//         s.mintFee[_args.fiBTC]  = 10;

//         // Set redeem enabled.
//         s.redeemEnabled[_args.fiUSD]    = 1;
//         s.redeemEnabled[_args.fiETH]    = 1;
//         s.redeemEnabled[_args.fiBTC]    = 1;

//         // Set redeem fee.
//         s.redeemFee[_args.fiUSD]    = 10;
//         s.redeemFee[_args.fiETH]    = 10;
//         s.redeemFee[_args.fiBTC]    = 10;

//         // Set service fee.
//         s.serviceFee[_args.fiUSD]   = 1e3;
//         s.serviceFee[_args.fiETH]   = 1e3;
//         s.serviceFee[_args.fiBTC]   = 1e3;

//         // Set rebases as callable by anyone.
//         // s.rebasePublic[_args.fiUSD] = 1;
//         // s.rebasePublic[_args.fiETH] = 1;
//         s.rebasePublic[_args.fiBTC] = 1;

//         // Set points rate.
//         s.pointsRate[_args.fiUSD]   = 1e6;  // 100 points/1.0 fiUSD earned.
//         s.pointsRate[_args.fiETH]   = 1e9;  // 100 points/0.001 fiETH earned.
//         s.pointsRate[_args.fiBTC]   = 1e10; // 100 points/0.0001 fiBTC earned.

//         s.owner         = msg.sender;
//         s.backupOwner   = _args.roles[1];
//         s.feeCollector  = _args.roles[2];

//         s.initReward    = 100*10**18;  // 100 Points for initial deposit.
//         s.referReward   = 10*10**18;  // 10 Points each for each referral.

//         s.decimals[_args.USDC] = 6;
//         s.decimals[_args.wETH] = 18;
//         s.decimals[_args.wBTC] = 8;

//         // 100 USDC buffer for migrations.
//         s.buffer[_args.fiUSD]   = 100*10**uint256(s.decimals[_args.USDC]);
//         // 0.1 wETH buffer for migrations.
//         s.buffer[_args.fiETH]   = 1*10**uint256((s.decimals[_args.wETH] - 1));
//         // 0.01 wBTC buffer for migrations.
//         s.buffer[_args.fiBTC]   = 1*10**uint256((s.decimals[_args.wBTC] - 2));

//         s.isAdmin[msg.sender] = 1;
//         s.isWhitelisted[msg.sender] = 1;

//         // Set admins.
//         for(uint i = 1; i < _args.roles.length; ++i) {
//             s.isAdmin[_args.roles[i]] = 1;
//             s.isWhitelisted[_args.roles[i]] = 1;
//         }

//         // Set accounts that can whitelist
//         // First account can whitelist but is not admin
//         for(uint i = 0; i < _args.roles.length; ++i) {
//             s.isWhitelister[_args.roles[i]] = 1;
//         }
//     }

//     // struct Args {
//     //     // address     fiUSD;  // fi token [USD]
//     //     address     fiETH;  // fi token [ETH]
//     //     // address     fiBTC;  // fi token [BTC]
//     //     // address     vUSDC;  // vault share token [USD]
//     //     address     vETH;   // vault share token [ETH]
//     //     // address     vBTC;   // vault share token [BTC]
//     //     // address     USDC;   // underlying token [USD]
//     //     address     wETH;   // underlying token [ETH]
//     //     // address     wBTC;   // underlying token [BTC]
//     //     // msg.sender is Admin + Whiteslited by default, so do not need to include.
//     //     address[]   roles;
//     // }
    
//     // function init(Args memory _args) external {

//     //     LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

//     //     // Adding ERC165 data.
//     //     ds.supportedInterfaces[type(IERC165).interfaceId]       = true;
//     //     ds.supportedInterfaces[type(IDiamondCut).interfaceId]   = true;
//     //     ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
//     //     ds.supportedInterfaces[type(IERC173).interfaceId]       = true;

//     //     // s.underlying[_args.fiUSD] = _args.USDC;
//     //     s.underlying[_args.fiETH] = _args.wETH;
//     //     // s.underlying[_args.fiBTC] = _args.wBTC;

//     //     // Set min deposit/withdraw values (target $20).
//     //     // s.minDeposit[_args.fiUSD]   = 20e6 - 1; // 20 USDC [6 digits].
//     //     s.minDeposit[_args.fiETH]   = 1e16 - 1; // 0.01 ETH [18 digits].
//     //     // s.minDeposit[_args.fiBTC]   = 1e5 - 1;  // 0.001 BTC [8 digits].
//     //     // s.minWithdraw[_args.fiUSD]  = 20e6 - 1; // 20 USDC.
//     //     s.minWithdraw[_args.fiETH]  = 1e16 - 1; // 0.01 ETH.
//     //     // s.minWithdraw[_args.fiBTC]  = 1e5 - 1;  // 0.001 BTC.

//     //     // s.vault[_args.fiUSD]    = _args.vUSDC;
//     //     s.vault[_args.fiETH]    = _args.vETH;
//     //     // s.vault[_args.fiBTC]    = _args.vBTC;

//     //     // fiUSD and fiETH not harvestable.
//     //     // s.harvestable[s.vault[_args.fiBTC]] = 1;

//     //     // Set mint enabled.
//     //     // s.mintEnabled[_args.fiUSD]  = 1;
//     //     s.mintEnabled[_args.fiETH]  = 1;
//     //     // s.mintEnabled[_args.fiBTC]  = 1;

//     //     // Set mint fee.
//     //     // s.mintFee[_args.fiUSD]  = 10;
//     //     s.mintFee[_args.fiETH]  = 10;
//     //     // s.mintFee[_args.fiBTC]  = 10;

//     //     // Set redeem enabled.
//     //     // s.redeemEnabled[_args.fiUSD]    = 1;
//     //     s.redeemEnabled[_args.fiETH]    = 1;
//     //     // s.redeemEnabled[_args.fiBTC]    = 1;

//     //     // Set redeem fee.
//     //     // s.redeemFee[_args.fiUSD]    = 10;
//     //     s.redeemFee[_args.fiETH]    = 10;
//     //     // s.redeemFee[_args.fiBTC]    = 10;

//     //     // Set service fee.
//     //     // s.serviceFee[_args.fiUSD]   = 1e3;
//     //     s.serviceFee[_args.fiETH]   = 1e3;
//     //     // s.serviceFee[_args.fiBTC]   = 1e3;

//     //     // s.rebasePublic[_args.fiUSD] = 1;
//     //     s.rebasePublic[_args.fiETH] = 1;
//     //     // s.rebasePublic[_args.fiBTC] = 1;

//     //     // Set points rate.
//     //     // s.pointsRate[_args.fiUSD]   = 1e6;  // 100 points/1.0 fiUSD earned.
//     //     s.pointsRate[_args.fiETH]   = 1e9;  // 100 points/0.001 fiETH earned.
//     //     // s.pointsRate[_args.fiBTC]   = 1e10; // 100 points/0.0001 fiBTC earned.

//     //     s.owner         = msg.sender;
//     //     s.backupOwner   = _args.roles[1];
//     //     s.feeCollector  = _args.roles[2];

//     //     s.initReward    = 100*10**18;  // 100 Points for initial deposit.
//     //     s.referReward   = 10*10**18;  // 10 Points each for each referral.

//     //     // s.decimals[_args.USDC] = 6;
//     //     s.decimals[_args.wETH] = 18;
//     //     // s.decimals[_args.wBTC] = 8;

//     //     // 100 USDC buffer for migrations.
//     //     // s.buffer[_args.fiUSD]   = 100*10**uint256(s.decimals[_args.USDC]);
//     //     // 0.1 wETH buffer for migrations.
//     //     s.buffer[_args.fiETH]   = 1*10**uint256((s.decimals[_args.wETH] - 1));
//     //     // 0.01 wBTC buffer for migrations.
//     //     // s.buffer[_args.fiBTC]   = 1*10**uint256((s.decimals[_args.wBTC] - 2));

//     //     s.isAdmin[msg.sender] = 1;
//     //     s.isWhitelisted[msg.sender] = 1;

//     //     // Set admins.
//     //     for(uint i = 1; i < _args.roles.length; ++i) {
//     //         s.isAdmin[_args.roles[i]] = 1;
//     //         s.isWhitelisted[_args.roles[i]] = 1;
//     //     }

//     //     // Set accounts that can whitelist
//     //     // First account can whitelist but is not admin
//     //     for(uint i = 0; i < _args.roles.length; ++i) {
//     //         s.isWhitelister[_args.roles[i]] = 1;
//     //     }
//     // }
// }