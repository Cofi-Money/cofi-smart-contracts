// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AppStorage, LibAppStorage } from './LibAppStorage.sol';
import { ISwapRouter } from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import 'hardhat/console.sol';

library LibUniswapV3 {

    ISwapRouter constant UNISWAP_V3_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    address constant WETH = 0x4200000000000000000000000000000000000006;

    function _exactInput(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _from,
        address _to,
        address _recipient
    )   internal
        returns (uint256 amountOut)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        /// @dev Ensure '_from' token resides at this contract beforehand.
        SafeERC20.safeApprove(IERC20(_from), address(UNISWAP_V3_ROUTER), _amountIn);

        return UNISWAP_V3_ROUTER.exactInput(ISwapRouter.ExactInputParams({
            path: s.swapRouteV3[_from][_to],
            recipient: _recipient,
            deadline: block.timestamp + (s.swapInfo[_from][_to].wait == 0 ?
                s.defaultWait :
                s.swapInfo[_from][_to].wait),
            amountIn: _amountIn,
            amountOutMinimum: _amountOutMin
        }));
    }

    function _exactInputETH(
        uint256 _amountOutMin,
        address _to
    )   internal
        returns (uint256 amountOut)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return UNISWAP_V3_ROUTER.exactInput{value: msg.value}(ISwapRouter.ExactInputParams({
            path: s.swapRouteV3[address(WETH)][_to],
            /// @dev As ETH is for entering only, recipient will only ever be this contract.
            recipient: address(this),
            deadline: block.timestamp + (s.swapInfo[WETH][_to].wait == 0 ?
                s.defaultWait :
                s.swapInfo[WETH][_to].wait),
            amountIn: msg.value,
            amountOutMinimum: _amountOutMin
        }));
    }
}