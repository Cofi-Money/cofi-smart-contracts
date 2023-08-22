// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IRouter } from "../diamond/interfaces/IRouter.sol";
import { PercentageMath } from "../diamond/libs/external/PercentageMath.sol";
import { StableMath } from "../diamond/libs/external/StableMath.sol";
import { FixedPointMath } from "../diamond/libs/external/FixedPointMath.sol";
import { ERC20 } from 'solmate/src/tokens/ERC20.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import 'hardhat/console.sol';

contract VelodromeSwap {
    using PercentageMath for uint256;
    using StableMath for uint256;
    using FixedPointMath for uint256;
    using StableMath for int256;

    IRouter constant VELODROME_V2_ROUTER =
        IRouter(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);

    address constant VELODROME_V2_FACTORY =
        0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;

    address constant WETH = 0x4200000000000000000000000000000000000006;

    /// @dev Leave for reference.
    AggregatorV3Interface constant ETH_PRICE_FEED =
        AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
    uint8 constant WETH_DECIMALS = 18;

    struct Route {
        address mid; // E.g., wETH => DAI: [USDC].
        /// @dev If mid = address(0): [false, false] => [false, X] (i.e., 2nd arg does not matter).
        bool[2] stable;
    }

    struct TokenInfo {
        AggregatorV3Interface priceFeed;
        uint8 decimals;
    }

    // E.g., wETH => DAI => [USDC]; wETH => USDC => [].
    mapping(address => mapping(address => Route)) route;
    mapping(address => TokenInfo) tokenInfo;
    /// @dev Can later move to Route struct.
    uint256 wait;
    uint256 slippage;

    constructor(
        uint256 _wait,
        uint256 _slippage
    ) {
        wait = _wait;
        slippage = _slippage;
        tokenInfo[WETH].priceFeed = AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
        tokenInfo[WETH].decimals = 18;
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
            console.log('stable[1]: %s', routes[1].stable);
        }
        console.log('stable[0]: %s', routes[0].stable);

        ERC20(_from).approve(address(VELODROME_V2_ROUTER), _amountIn);

        uint256[] memory amountsOut = getAmountsOut(_amountIn, _from, _to);
        console.log('amountsOut: %s', amountsOut[amountsOut.length - 1]);

        return VELODROME_V2_ROUTER.swapExactTokensForTokens(
            _amountIn,
            // Not reliable as just relays amount out.
            getAmountOutMin(_amountIn, _from, _to), // amountOutMin (insert Chainlink price).
            routes,
            address(this), // to (requires tokens to reside at this contract beforehand).
            block.timestamp + wait // deadline
        );
    }

    function setDecimals(
        address _token,
        uint8 _decimals
    ) external returns (bool) {

        tokenInfo[_token].decimals = _decimals;
        return true;
    }

    function setPriceFeed(
        address _token,
        AggregatorV3Interface _priceFeed
    ) external returns (bool) {

        tokenInfo[_token].priceFeed = _priceFeed;
        return true;
    }

    /// @dev Assumes reverse route.
    function setRoute(
        address _tokenA,
        address _mid,
        address _tokenB,
        bool[2] calldata _stable
    ) external returns (bool) {

        route[_tokenA][_tokenB].mid = _mid;
        route[_tokenB][_tokenA].mid = _mid;
        route[_tokenA][_tokenB].stable = _stable;
        route[_tokenB][_tokenA].stable = _stable;
        // Only care about/want to reverse stable order if using a mid.
        if (route[_tokenA][_tokenB].mid != address(0)) {
            // E.g. wETH (=> USDC) => DAI: [false, true]
            // Therefore, DAI (=> USDC) => wETH: [!false, !true] = [true, false]
            route[_tokenB][_tokenA].stable[0] = !_stable[0];
            route[_tokenB][_tokenA].stable[1] = !_stable[1];
        }
        return true;
    }

    function getRoute(
        address _from,
        address _to
    ) external view returns (Route memory) {

        return route[_from][_to];
    }

    /// @return fromUSD adjusted to 8 decimals (e.g., $1 = 100_000_000)
    function getLatestPrice(
        address _from,
        address _to
    ) public view returns (uint256 fromUSD, uint256 toUSD, uint256 fromTo) {

        (uint80 _roundID, int256 _answer, , uint256 _timestamp, uint80 _answeredInRound)
            = tokenInfo[_from].priceFeed.latestRoundData();

        require(_answeredInRound >= _roundID, 'Stale price');
        require(_timestamp != 0,'Round not complete');
        require(_answer > 0,'Chainlink answer reporting 0');

        fromUSD = _answer.abs();
        console.log('from answer: %s', fromUSD);

        // If _to not set, assume USD.
        if (address(tokenInfo[_to].priceFeed) == address(0)) {
            return (fromUSD, 1e8, fromUSD);
        }

        (, _answer, , , ) = tokenInfo[_to].priceFeed.latestRoundData();
        toUSD = _answer.abs();
        console.log('to answer: %s', toUSD);

        // Scales to 18 but need to return answer in 8 decimals.
        fromTo = fromUSD.divPrecisely(toUSD).scaleBy(8, 18);
        console.log('fromTo: %s', fromTo);
    }

    function getAmountOutMin(
        uint256 _amountIn,
        address _from,
        address _to
    ) public view returns (uint256 amountOutMin) {

        (, , uint256 fromTo) = getLatestPrice(_from, _to);

        // Need to divide by Chainlink answer 8 decimals after multiplying.
        amountOutMin = (_amountIn.mulDivUp(fromTo, 1e8))
            .scaleBy(tokenInfo[_to].decimals, tokenInfo[_from].decimals)
            .percentMul(1e4 - slippage);

        console.log('amountOutMin: %s', amountOutMin);
    }
    // .99_999_914
    // 24,999,978.50_000_000

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

        uint256[] memory amountsOut = getAmountsOut(msg.value, WETH, _to);
        console.log('amountsOut: %s', amountsOut[amountsOut.length - 1]);

        return VELODROME_V2_ROUTER.swapExactETHForTokens{value: msg.value}(
            getAmountOutMin(msg.value, WETH, _to), // amountOutMin
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
        console.log('amountsOut: %s', amountsOut[amountsOut.length - 1]);

        return VELODROME_V2_ROUTER.swapExactTokensForETH(
            _amountIn,
            getAmountOutMin(_amountIn, _from, WETH), // amountOutMin
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