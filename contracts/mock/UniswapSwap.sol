// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ISwapRouter } from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import { IWETH } from '../diamond/interfaces/IWETH.sol';
import { PercentageMath } from "../diamond/libs/external/PercentageMath.sol";
import { StableMath } from "../diamond/libs/external/StableMath.sol";
import { FixedPointMath } from "../diamond/libs/external/FixedPointMath.sol";
import { ERC20 } from 'solmate/src/tokens/ERC20.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import 'hardhat/console.sol';

contract UniswapSwap {
    using PercentageMath for uint256;
    using StableMath for uint256;
    using FixedPointMath for uint256;
    using StableMath for int256;

    ISwapRouter constant UNISWAP_V3_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    IWETH constant WETH = IWETH(0x4200000000000000000000000000000000000006);

    /// @dev Leave for reference.
    AggregatorV3Interface constant ETH_PRICE_FEED =
        AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5);

    uint8 constant WETH_DECIMALS = 18;

    struct TokenInfo {
        AggregatorV3Interface priceFeed;
        uint8 decimals;
    }

    mapping(address => mapping(address => bytes)) path;
    mapping(address => TokenInfo) tokenInfo;
    uint256 wait;
    uint256 slippage;

    constructor(
        uint256 _wait,
        uint256 _slippage
    ) {
        wait = _wait;
        slippage = _slippage;
        tokenInfo[address(WETH)].priceFeed = AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
        tokenInfo[address(WETH)].decimals = 18;
    }
    
    function exactInput(
        uint256 _amountIn, // To send ETH, ensure _amountIn == msg.value.
        address _from,
        address _to
    ) external payable returns (uint256 amountOut) {

        ERC20(_from).transferFrom(msg.sender, address(this), _amountIn);

        ERC20(_from).approve(address(UNISWAP_V3_ROUTER), _amountIn);

        return UNISWAP_V3_ROUTER.exactInput(ISwapRouter.ExactInputParams({
            path: path[_from][_to],
            recipient: address(this),
            deadline: block.timestamp + wait,
            amountIn: _amountIn,
            amountOutMinimum: getAmountOutMin(_amountIn, _from, _to)
        }));
    }

    // Diamond has this already.
    fallback() external payable {}

    function unwrap(
        // uint256 _amountIn        
    ) external
    //  returns (uint256 ETHOut) 
     {

        // ERC20(address(WETH)).approve(address(WETH), _amountIn);
        console.log('bal: ', WETH.balanceOf(address(this)));
        WETH.withdraw(WETH.balanceOf(address(this)));

        // return address(this).balance;
    }

    function setPath(
        address _tokenA,
        uint24  _poolFee1,
        address _mid,
        uint24  _poolFee2,
        address _tokenB
    ) external returns (bool) {

        if (_poolFee2 == 0 || _mid == address(0)) {
            path[_tokenA][_tokenB] = abi.encodePacked(_tokenA, _poolFee1, _tokenB);
            path[_tokenB][_tokenA] = abi.encodePacked(_tokenB, _poolFee1, _tokenA);
        }
        else {
            path[_tokenA][_tokenB] = abi.encodePacked(
                _tokenA,
                _poolFee1,
                _mid, // Usually wETH.
                _poolFee2,
                _tokenB
            );
            path[_tokenB][_tokenA] = abi.encodePacked(
                _tokenB,
                _poolFee2,
                _mid, // Usually wETH.
                _poolFee1,
                _tokenA
            );
        }
        return true;
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
}