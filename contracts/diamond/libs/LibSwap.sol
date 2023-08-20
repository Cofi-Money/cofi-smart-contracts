// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AppStorage, LibAppStorage } from "./LibAppStorage.sol";
import { IRouter } from "../interfaces/IRouter.sol";
import { PercentageMath } from "./external/PercentageMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library LibSwap {
    using PercentageMath for uint256;

    event Swap(address indexed from, address indexed to, uint256 amountIn, uint256 amountOut);

    IRouter constant VELODROME_V2_ROUTER =
        IRouter(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);

    address constant VELODROME_V2_FACTORY =
        0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;

    function _velodromeV2SwapStable(
        address _from,
        address _to,
        uint256 _amountIn
    ) internal returns (uint256[] memory amounts) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        IRouter.Route memory route = IRouter.Route({
            from: _from,
            to: _to,
            stable: true,
            factory: VELODROME_V2_FACTORY
        });
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = route;

        SafeERC20.safeApprove(
            IERC20(_from),
            address(VELODROME_V2_ROUTER),
            _amountIn
        );

        amounts = VELODROME_V2_ROUTER.swapExactTokensForTokens(
            _amountIn,
            _amountIn.percentMul(1e4 - s.swapParams[_from][_to].slippage), // amountOutMin
            routes,
            address(this), // to
            block.timestamp + s.swapParams[_from][_to].wait // deadline
        );
        emit Swap(_from, _to, _amountIn, amounts[0]);
    }
}