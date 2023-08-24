// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AppStorage, LibAppStorage } from './LibAppStorage.sol';
import { IRouter } from '../interfaces/IRouter.sol';
import { PercentageMath } from './external/PercentageMath.sol';
import { FixedPointMath } from './external/FixedPointMath.sol';
import { StableMath } from './external/StableMath.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

library LibVelodromeV2 {

    event VelodromeV2Swap(address indexed from, address indexed to, uint256 amountIn, uint256 amountOut);

    IRouter constant VELODROME_V2_ROUTER =
        IRouter(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);

    address constant VELODROME_V2_FACTORY =
        0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;

    address constant WETH = 0x4200000000000000000000000000000000000006;

    function _swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _from,
        address _to,
        address _recipient
    )   internal
        returns (uint256[] memory amounts)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        IRouter.Route[] memory routes = _getRoutes(_from, _to);

        SafeERC20.safeApprove(IERC20(_from), address(VELODROME_V2_ROUTER), _amountIn);

        return VELODROME_V2_ROUTER.swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            routes,
            _recipient,
            block.timestamp + s.swapInfo[_from][_to].wait == 0 ? s.defaultWait : s.swapInfo[_from][_to].wait
        );
    }

    function _swapExactETHForTokens(
        uint256 _amountOutMin,
        address _to
    )   internal
        returns (uint256[] memory amounts)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        IRouter.Route[] memory routes = _getRoutes(WETH, _to);

        return VELODROME_V2_ROUTER.swapExactETHForTokens{value: msg.value}(
            _amountOutMin,
            routes,
            address(this),
            block.timestamp + s.swapInfo[WETH][_to].wait == 0 ? s.defaultWait : s.swapInfo[WETH][_to].wait
        );
    }

    function _swapExactTokensForETH(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _from,
        address _recipient
    )   internal
        returns (uint256[] memory amounts)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        /// @dev If redeeming, tokens should reside at this address after being pulled from vault.
        IRouter.Route[] memory routes = _getRoutes(_from, WETH);

        SafeERC20.safeApprove(IERC20(_from), address(VELODROME_V2_ROUTER), _amountIn);

        return VELODROME_V2_ROUTER.swapExactTokensForETH(
            _amountIn,
            _amountOutMin,
            routes,
            _recipient, // For some reason, fails if set to this address.
            block.timestamp + s.swapInfo[_from][WETH].wait == 0 ? s.defaultWait : s.swapInfo[_from][WETH].wait
        );
    }

    function _getRoutes(
        address _from,
        address _to
    )   internal view
        returns (IRouter.Route[] memory routes)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        routes = new IRouter.Route[](s.veloRoute[_from][_to].mid == address(0) ? 1 : 2);
        routes[0] = IRouter.Route({
            from: _from,
            to: s.veloRoute[_from][_to].mid == address(0) ? _to : s.veloRoute[_from][_to].mid,
            stable: s.veloRoute[_from][_to].stable[0],
            factory: VELODROME_V2_FACTORY
        });

        if (s.veloRoute[_from][_to].mid != address(0)) {
            routes[1] = IRouter.Route({
                from: s.veloRoute[_from][_to].mid,
                to: _to,
                stable: s.veloRoute[_from][_to].stable[1],
                factory: VELODROME_V2_FACTORY
            });
        }
    }
}