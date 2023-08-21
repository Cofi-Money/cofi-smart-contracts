// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IRouter } from "../diamond/interfaces/IRouter.sol";
import { PercentageMath } from "../diamond/libs/external/PercentageMath.sol";
import { ERC20 } from 'solmate/src/tokens/ERC20.sol';
import 'hardhat/console.sol';

contract VelodromeSwap {
    using PercentageMath for uint256;

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
    /// @dev Can later move to Route struct.
    uint256 wait;
    uint256 slippage;

    constructor(
        uint256 _wait,
        uint256 _slippage
    ) {
        wait = _wait;
        slippage = _slippage;
    }
    
    /// @dev Repeat for obtaining DAI.
    function swapExactTokensForTokens(
        uint256 _amountIn,
        address _from,
        address _to
    ) external returns (uint256[] memory amounts) {

        // Transfer to this address first to maintain consistency.
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
        console.log('stable[0]: %s', routes[0].stable);

        ERC20(_from).approve(address(VELODROME_V2_ROUTER), _amountIn);

        uint256[] memory amountsOut = getAmountsOut(_amountIn, _from, _to);
        console.log('amountsOut: %s', amountsOut[amountsOut.length - 1]);

        return VELODROME_V2_ROUTER.swapExactTokensForTokens(
            _amountIn,
            // Not reliable as just relays amount out.
            0, // amountOutMin (insert Chainlink price).
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
        route[_to][_from].mid = _mid;
        route[_from][_to].stable = _stable;
        route[_to][_from].stable = _stable;
        // Only care about/want to reverse stable order if using a mid.
        if (route[_from][_to].mid != address(0)) {
            // E.g. wETH (=> USDC) => DAI: [false, true]
            // Therefore, DAI (=> USDC) => wETH: [!false, !true] = [true, false]
            route[_to][_from].stable[0] = !_stable[0];
            route[_to][_from].stable[1] = !_stable[1];
        }
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
        address _to
    )   public
        payable
        returns (uint256[] memory amounts)
    {        
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

        return VELODROME_V2_ROUTER.swapExactETHForTokens{value: msg.value}(
            0, // amountOutMin
            routes,
            address(this), // to (requires ETH to reside at this contract beforehand).
            block.timestamp + wait // deadline
        );
    }

    function swapExactTokensForETH(
        uint256 _amountIn,
        address _from
    ) public returns (uint256[] memory amounts) {

        // In Diamond, tokens will reside at this contact (after being pulled from pool), so no transferFrom op.
        ERC20(_from).transferFrom(msg.sender, address(this), _amountIn);

        // Push first route.
        IRouter.Route[] memory routes = new IRouter.Route[](route[_from][WETH].mid == address(0) ? 1 : 2);
        routes[0] = IRouter.Route({
            from: _from,
            to: route[_from][WETH].mid == address(0) ? WETH : route[_from][WETH].mid,
            stable: route[_from][WETH].stable[0],
            factory: VELODROME_V2_FACTORY
        });

        if (route[_from][WETH].mid != address(0)) {
            routes[1] = IRouter.Route({
                from: route[_from][WETH].mid,
                to: WETH,
                stable: route[_from][WETH].stable[1],
                factory: VELODROME_V2_FACTORY
            });
            console.log('stable[1]: %s', routes[1].stable);
        }
        console.log('stable[0]: %s', routes[0].stable);

        ERC20(_from).approve(address(VELODROME_V2_ROUTER), _amountIn);

        uint256[] memory amountsOut = getAmountsOut(_amountIn, _from, WETH);
        console.log('to: %s', routes[routes.length - 1].to);
        console.log('amountOut: %s', amountsOut[amountsOut.length - 1]);

        return VELODROME_V2_ROUTER.swapExactTokensForETH(
            _amountIn,
            0, // amountOutMin
            routes,
            msg.sender, // For some reason, fails if set to this address.
            type(uint256).max // deadline
        );
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