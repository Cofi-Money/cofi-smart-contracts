// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IRouter } from "../diamond/interfaces/IRouter.sol";
import { ERC20 } from 'solmate/src/tokens/ERC20.sol';

contract VelodromeSwap {

    IRouter constant VELODROME_V2_ROUTER =
        IRouter(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);

    address constant VELODROME_V2_FACTORY =
        0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;

    address constant WETH = 0x4200000000000000000000000000000000000006;

    struct Route {
        address mid; // E.g., wETH => DAI: [USDC]
        /// @dev if mid = address(0): [false, false] => [false, X].
        bool[2] stable;
    }

    // E.g., wETH => DAI => [USDC]; wETH => USDC => [].
    mapping(address => mapping(address => Route)) route;
    uint256 wait;

    constructor(
        uint256 _wait
    ) {
        wait = _wait;
    }
    
    /// @dev Repeat for obtaining DAI.
    function swapExactTokensForTokens(
        uint256 _amountIn,
        address _from,
        address _to
    ) external returns (uint256[] memory amounts) {

        ERC20(_from).transferFrom(msg.sender, address(this), _amountIn);

        // Push first route.
        IRouter.Route[] memory routes = new IRouter.Route[](route[_from][_to].mid == address(0) ? 1 : 2);
        routes[0] = IRouter.Route({
            from: _from,
            to: route[_from][_to].mid == address(0) ? _to : route[_from][_to].mid,
            stable: route[_from][_to].stable[0],
            factory: VELODROME_V2_FACTORY
        });

        if (route[_from][_to].mid != address(0)) {
            routes[1] = IRouter.Route({
                from: route[_from][_to].mid,
                to: _to,
                stable: route[_from][_to].stable[1],
                factory: VELODROME_V2_FACTORY
            });
        }

        ERC20(_from).approve(address(VELODROME_V2_ROUTER), _amountIn);

        return VELODROME_V2_ROUTER.swapExactTokensForTokens(
            _amountIn,
            0, // amountOutMin
            routes,
            address(this), // to (requires tokens to reside at this contract beforehand).
            block.timestamp + wait // deadline
        );
    }

    function setRoute(
        address _from,
        address _to,
        address _mid,
        bool[2] calldata _stable 
    ) external returns (bool) {

        route[_from][_to].mid = _mid;
        route[_from][_to].stable = _stable;
        return true;
    }

    function getRoute(
        address _from,
        address _to
    ) external view returns (Route memory) {

        return route[_from][_to];
    }

    /// @dev Repeat for obtaining DAI.
    function swapExactETHForTokens(
        uint256 _amountOutMin,
        address _to
    ) public payable returns (uint256[] memory amounts) {
        
        // Push first route.
        IRouter.Route[] memory routes = new IRouter.Route[](route[WETH][_to].mid == address(0) ? 1 : 2);
        routes[0] = IRouter.Route({
            from: WETH,
            to: route[WETH][_to].mid == address(0) ? _to : route[WETH][_to].mid,
            stable: route[WETH][_to].stable[0],
            factory: VELODROME_V2_FACTORY
        });

        if (route[WETH][_to].mid != address(0)) {
            routes[1] = IRouter.Route({
                from: route[WETH][_to].mid,
                to: _to,
                stable: route[WETH][_to].stable[1],
                factory: VELODROME_V2_FACTORY
            });
        }

        amounts = VELODROME_V2_ROUTER.swapExactETHForTokens{value: msg.value}(
            _amountOutMin, // amountOutMin
            routes,
            address(this), // to (requires ETH to reside at this contract beforehand).
            block.timestamp + wait // deadline
        );
        require(amounts[amounts.length - 1] >= _amountOutMin, "Slippage exceeded");
    }

    function getAmountsOut(
        uint256 _amountIn,
        address _from,
        address _to
    ) public view returns (uint256[] memory amounts) {

        // Push first route.
        IRouter.Route[] memory routes = new IRouter.Route[](route[_from][_to].mid == address(0) ? 1 : 2);
        routes[0] = IRouter.Route({
            from: _from,
            to: route[_from][_to].mid == address(0) ? _to : route[_from][_to].mid,
            stable: route[_from][_to].stable[0],
            factory: VELODROME_V2_FACTORY
        });

        if (route[_from][_to].mid != address(0)) {
            routes[1] = IRouter.Route({
                from: route[_from][_to].mid,
                to: _to,
                stable: route[_from][_to].stable[1],
                factory: VELODROME_V2_FACTORY
            });
        }

        return VELODROME_V2_ROUTER.getAmountsOut(
            _amountIn,
            routes
        );
    }
}