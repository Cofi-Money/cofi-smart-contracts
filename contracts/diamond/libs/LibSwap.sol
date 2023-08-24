// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AppStorage, LibAppStorage, SwapProtocol } from './LibAppStorage.sol';
import { LibVelodromeV2 } from './LibVelodromeV2.sol';
import { IWETH } from '../interfaces/IWETH.sol';
import { PercentageMath } from './external/PercentageMath.sol';
import { FixedPointMath } from './external/FixedPointMath.sol';
import { StableMath } from './external/StableMath.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

library LibSwap {
    using PercentageMath for uint256;
    using FixedPointMath for uint256;
    using StableMath for uint256;
    using StableMath for int256;

    address constant WETH = 0x4200000000000000000000000000000000000006;

    /**
     * @dev Swaps from this contract (not '_depositFrom').
     * @param _amountIn The amount of '_from' token to swap.
     * @param _from     The token to swap.
     * @param _to       The token to receive.
     */
    function _swapERC20ForERC20(
        uint256 _amountIn,
        address _from,
        address _to,
        address _recipient
    )   internal
        returns (uint256 amountOut)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(s.swapProtocol[_from][_to] > SwapProtocol(0), 'LibSwap: Swap protocol not set');

        if (s.swapProtocol[_from][_to] == SwapProtocol(1)) {
            uint256[] memory amounts = LibVelodromeV2._swapExactTokensForTokens(
                _amountIn,
                _getAmountOutMin(_amountIn, _from, _to),
                _from,
                _to,
                _recipient
            );
            amountOut = amounts[amounts.length - 1];
        } else if (s.swapProtocol[_from][_to] == SwapProtocol(2)) {
            // Insert.
        }
    }

    /**
     * @dev Swaps ETH directly from msg.sender (not this contract).
     * @param _to The token to receive.
     */
    function _swapETHForERC20(
        address _to
    )   internal
        returns (uint256 amountOut)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(s.swapProtocol[WETH][_to] > SwapProtocol(0), 'LibSwap: Swap protocol not set');

        if (s.swapProtocol[WETH][_to] == SwapProtocol(1)) {
            uint256[] memory amounts = LibVelodromeV2._swapExactETHForTokens(
                _getAmountOutMin(msg.value, WETH, _to),
                _to
            );
            amountOut = amounts[amounts.length - 1];
        } else if (s.swapProtocol[WETH][_to] == SwapProtocol(2)) {
            // Insert.
        }
    }

    /**
     * @dev Token is transferred directly from DEX to recipient (does not traverse through this contract).
     * @param _amountIn     The amount of '_from' token to swap.
     * @param _from         The token to swap.
     * @param _recipient    The receiver of ETH.
     */
    function _swapERC20ForETH(
        uint256 _amountIn,
        address _from,
        address _recipient
    )   internal
        returns (uint256 amountOut)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(s.swapProtocol[_from][WETH] > SwapProtocol(0), 'LibSwap: Swap protocol not set');

        if (s.swapProtocol[_from][WETH] == SwapProtocol(1)) {
            uint256[] memory amounts = LibVelodromeV2._swapExactTokensForETH(
                _amountIn,
                _getAmountOutMin(_amountIn, _from, WETH),
                _from,
                _recipient
            );
            amountOut = amounts[amounts.length - 1];
        } else if (s.swapProtocol[_from][WETH] == SwapProtocol(2)) {
            // Insert.
            // Unwrap.
        }
    }

    /**
     * @notice Computes 'amountOutMin' by retrieving prices of '_from' and '_to' assets and applying slippage.
     * @dev If a custom value for slippage is not set for the '_from', '_to' mapping, will use default.
     * @param _amountIn The amount of '_from' tokens to swap.
     * @param _from     The asset to swap (tokens or ETH).
     * @param _to       The asset to receive (tokens or ETH).
     */
    function _getAmountOutMin(
        uint256 _amountIn,
        address _from,
        address _to
    )   internal view
        returns (uint256 amountOutMin)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        (, , uint256 fromTo) = _getLatestPrice(_from, _to);

        // Need to divide by Chainlink answer 8 decimals after multiplying.
        return (_amountIn.mulDivUp(fromTo, 1e8))
            .scaleBy(s.decimals[_to], s.decimals[_from])
            .percentMul(1e4 - s.swapInfo[_from][_to].slippage == 0 ?
                s.defaultSlippage :
                s.swapInfo[_from][_to].slippage
            );
    }

    /**
     * @notice Retrieves latest price of '_from' and '_to' assets from respective Chainlink price oracle.
     * @dev Return values adjusted to 8 decimals (e.g., $1.00 = 1(.)00_000_000).
     * @param _from The asset to enquire price for.
     * @param _to   The asset to denominate price in.
     * @return fromUSD  The USD price of the '_from' asset.
     * @return toUSD    The USD price of the '_to' asset.
     * @return fromTo   The '_from' asset price denominated in '_to' asset. 
     */
    function _getLatestPrice(
        address _from,
        address _to
    )   internal view
        returns (uint256 fromUSD, uint256 toUSD, uint256 fromTo)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        (uint80 _roundID, int256 _answer, , uint256 _timestamp, uint80 _answeredInRound)
            = AggregatorV3Interface(s.priceFeed[_from]).latestRoundData();

        require(_answeredInRound >= _roundID, 'LibSwap: Stale price');
        require(_timestamp != 0,'LibSwap: Round not complete');
        require(_answer > 0,'LibSwap: Chainlink answer reporting 0');

        fromUSD = _answer.abs();

        // If _to not set, assume USD.
        if (s.priceFeed[_to] == address(0)) {
            return (fromUSD, 1e8, fromUSD);
        }

        (, _answer, , , ) = AggregatorV3Interface(s.priceFeed[_to]).latestRoundData();
        toUSD = _answer.abs();

        // Scales to 18 but need to return answer in 8 decimals.
        fromTo = fromUSD.divPrecisely(toUSD).scaleBy(8, 18);
    }
}