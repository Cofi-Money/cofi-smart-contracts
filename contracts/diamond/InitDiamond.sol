// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDiamond } from './core/libs/LibDiamond.sol';
import { IERC165 } from './core/interfaces/IERC165.sol';
import { IDiamondCut } from './core/interfaces/IDiamondCut.sol';
import { IDiamondLoupe } from './core/interfaces/IDiamondLoupe.sol';
import { IERC173 } from './core/interfaces/IERC173.sol';
import { SwapProtocol, AppStorage } from './libs/LibAppStorage.sol';
import { LibToken } from './libs/LibToken.sol';

contract InitDiamond {
    AppStorage internal s;

    struct Args {
        address coUSD;  // cofi token [USD]
        address coETH;  // cofi token [ETH]
        address coBTC;  // cofi token [BTC]
        address coOP;   // cofi token [OP]
        address vUSD;  // vault [USD]
        address vETH;   // vault [ETH]
        address vBTC;   // vault [BTC]
        address vOP;    // vault [OP] 
        // msg.sender is Admin + whiteslited by default, so do not need to include.
        address[] roles;
    }
    
    function init(Args memory _args) external {

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        // Adding ERC165 data.
        ds.supportedInterfaces[type(IERC165).interfaceId]       = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId]   = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId]       = true;

        address USDC    = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
        address DAI     = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
        address WETH    = 0x4200000000000000000000000000000000000006;
        address WBTC    = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
        address OP      = 0x4200000000000000000000000000000000000042;

        // Set min deposit/withdraw values (target $1).
        s.minDeposit[_args.coUSD]   = 1e6 - 1; // 1 USDC [6 digits].
        s.minDeposit[_args.coETH]   = 1e15 - 1; // 0.001 wETH [18 digits].
        s.minDeposit[_args.coBTC]   = 1e4 - 1;  // 0.0001 wBTC [8 digits].
        s.minDeposit[_args.coOP]    = 1e18 - 1;
        s.minWithdraw[_args.coUSD]  = 1e6 - 1; // 1 USDC.
        s.minWithdraw[_args.coETH]  = 1e15 - 1; // 0.001 wETH.
        s.minWithdraw[_args.coBTC]  = 1e4 - 1;  // 0.0001 wBTC.
        s.minWithdraw[_args.coOP]   = 1e18 - 1;

        s.vault[_args.coUSD]    = _args.vUSD;
        s.vault[_args.coETH]    = _args.vETH;
        s.vault[_args.coBTC]    = _args.vBTC;
        s.vault[_args.coOP]     = _args.vOP;

        // Only YearnV2 and CompoundV2 (Sonne) harvestable to begin with.
        s.harvestable[_args.vUSD]   = 1;
        s.harvestable[_args.vETH]   = 1;
        s.harvestable[_args.vBTC]   = 1;
        s.harvestable[_args.vOP]    = 1;

        // Set mint enabled.
        s.mintEnabled[_args.coUSD]  = 1;
        s.mintEnabled[_args.coETH]  = 1;
        s.mintEnabled[_args.coBTC]  = 1;
        s.mintEnabled[_args.coOP]   = 1;

        // Set mint fee.
        s.mintFee[_args.coUSD]  = 10;
        s.mintFee[_args.coETH]  = 10;
        s.mintFee[_args.coBTC]  = 10;
        s.mintFee[_args.coOP]   = 10;

        // Set redeem enabled.
        s.redeemEnabled[_args.coUSD]    = 1;
        s.redeemEnabled[_args.coETH]    = 1;
        s.redeemEnabled[_args.coBTC]    = 1;
        s.redeemEnabled[_args.coOP]     = 1;

        // Set redeem fee.
        s.redeemFee[_args.coUSD]    = 10;
        s.redeemFee[_args.coETH]    = 10;
        s.redeemFee[_args.coBTC]    = 10;
        s.redeemFee[_args.coOP]     = 10;

        // Set service fee.
        s.serviceFee[_args.coUSD]   = 1e3;
        s.serviceFee[_args.coETH]   = 1e3;
        s.serviceFee[_args.coBTC]   = 1e3;
        s.serviceFee[_args.coOP]    = 1e3;

        // Set points rate.
        s.pointsRate[_args.coUSD]   = 1e6;  // 100 points/1.0 coUSD earned.
        s.pointsRate[_args.coETH]   = 1e9;  // 100 points/0.001 coETH earned.
        s.pointsRate[_args.coBTC]   = 1e10; // 100 points/0.0001 coBTC earned.
        s.pointsRate[_args.coOP]    = 1e6;  // 100 points/1.0 coOP earned.

        s.owner         = msg.sender;
        s.backupOwner   = _args.roles[1];
        s.feeCollector  = _args.roles[2];

        s.initReward    = 100*10**18;   // 100 Points for initial deposit.
        s.referReward   = 10*10**18;    // 10 Points each for each referral.

        s.decimals[USDC]    = 6;
        s.decimals[DAI]     = 18;
        s.decimals[WETH]    = 18;
        s.decimals[WBTC]    = 8;
        s.decimals[OP]      = 18;

        // 10 USDC buffer for migrations.
        s.buffer[USDC]  = 10*10**uint256(s.decimals[USDC]);
        // 10 DAI buffer for migrations.
        s.buffer[DAI]   = 10*10**uint256(s.decimals[USDC]);
        // 0.01 wETH buffer for migrations.
        s.buffer[WETH]  = 1*10**uint256((s.decimals[WETH] - 2));
        // 0.001 wBTC buffer for migrations.
        s.buffer[WBTC]  = 1*10**uint256((s.decimals[WBTC] - 3));
        // 10 OP buffer for migrations.
        s.buffer[OP]    = 10*10**uint256(s.decimals[USDC]);

        // Set swap params (UniswapV3 is preferred option for all swaps currently).
        s.defaultSlippage = 200; // 2%
        s.defaultWait = 12; // 12 seconds

        // Best practice to decrease limits as TVL increases.
        s.supplyLimit[_args.coUSD]  = 200; // 2%
        s.supplyLimit[_args.coBTC]  = 200; // 2%
        s.supplyLimit[_args.coETH]  = 200; // 2%
        s.supplyLimit[_args.coOP]   = 200; // 2%
        s.rateLimit[_args.coUSD]    = 20000; // 20%
        s.rateLimit[_args.coETH]    = 20000; // 20%
        s.rateLimit[_args.coBTC]    = 20000; // 20%
        s.rateLimit[_args.coOP]     = 20000; // 20%

        // ETH (=> wETH) => USDC and back.
        s.swapRouteV3[WETH][USDC] = abi.encodePacked(
            WETH,
            uint24(500),
            USDC
        );
        s.swapRouteV3[USDC][WETH] = abi.encodePacked(
            USDC,
            uint24(500),
            WETH
        );
        // SwapProtocol(2) = UniswapV3.
        s.swapProtocol[WETH][USDC] = SwapProtocol(2);
        s.swapProtocol[USDC][WETH] = SwapProtocol(2);
        s.supportedSwaps[WETH].push(USDC);
        s.supportedSwaps[USDC].push(WETH);

        // ETH (=> wETH => USDC) => DAI and back.
        s.swapRouteV3[WETH][DAI] = abi.encodePacked(
            WETH,
            uint24(500),
            USDC,
            uint24(100),
            DAI
        );
        s.swapRouteV3[DAI][WETH] = abi.encodePacked(
            DAI,
            uint24(100),
            USDC,
            uint24(500),
            WETH
        );
        s.swapProtocol[WETH][DAI] = SwapProtocol(2);
        s.swapProtocol[DAI][WETH] = SwapProtocol(2);
        s.supportedSwaps[WETH].push(DAI);
        s.supportedSwaps[DAI].push(WETH);

        // DAI => USDC and back.
        s.swapRouteV3[DAI][USDC] = abi.encodePacked(
            DAI,
            uint24(100),
            USDC
        );
        s.swapRouteV3[USDC][DAI] = abi.encodePacked(
            USDC,
            uint24(100),
            DAI
        );
        s.swapProtocol[DAI][USDC] = SwapProtocol(2);
        s.swapProtocol[USDC][DAI] = SwapProtocol(2);
        s.supportedSwaps[DAI].push(USDC);
        s.supportedSwaps[USDC].push(DAI);

        // ETH (=> wETH) => wBTC and back.
        s.swapRouteV3[WETH][WBTC] = abi.encodePacked(
            WETH,
            uint24(500),
            WBTC
        );
        s.swapRouteV3[WBTC][WETH] = abi.encodePacked(
            WBTC,
            uint24(500),
            WETH
        );
        s.swapProtocol[WETH][WBTC] = SwapProtocol(2);
        s.swapProtocol[WBTC][WETH] = SwapProtocol(2);
        s.supportedSwaps[WETH].push(WBTC);
        s.supportedSwaps[WBTC].push(WETH);

        // ETH (=> wETH) => wBTC and back.
        s.swapRouteV3[WETH][OP] = abi.encodePacked(
            WETH,
            uint24(500),
            OP
        );
        s.swapRouteV3[OP][WETH] = abi.encodePacked(
            OP,
            uint24(500),
            WETH
        );
        s.swapProtocol[WETH][OP] = SwapProtocol(2);
        s.swapProtocol[OP][WETH] = SwapProtocol(2);
        s.supportedSwaps[WETH].push(OP);
        s.supportedSwaps[OP].push(WETH);

        s.priceFeed[USDC]   = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3;
        s.priceFeed[DAI]    = 0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6;
        s.priceFeed[WETH]   = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;
        s.priceFeed[WBTC]   = 0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593;
        s.priceFeed[OP]     = 0x0D276FC14719f9292D5C1eA2198673d1f4269246;

        s.isAdmin[msg.sender] = 1;
        s.isWhitelisted[msg.sender] = 1;

        // Set admins.
        for(uint i = 1; i < _args.roles.length; ++i) {
            s.isAdmin[_args.roles[i]] = 1;
            s.isWhitelisted[_args.roles[i]] = 1;
        }

        // Set accounts that can whitelist.
        // First account can whitelist but is not admin.
        for(uint i = 0; i < _args.roles.length; ++i) {
            s.isWhitelister[_args.roles[i]] = 1;
        }
    }
}