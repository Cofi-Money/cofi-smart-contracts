// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SwapProtocol, Route, Modifiers } from '../libs/LibAppStorage.sol';
import { LibSwap } from '../libs/LibSwap.sol';

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Swap Manager Facet
    @notice Admin functions for managing swap params.
 */

contract SwapManagerFacet is Modifiers {

    /*//////////////////////////////////////////////////////////////
                            Admin - Setters
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Sets the swap protocol used to execute a swap between two tokens.
     * @dev Sets forward and reverse order.
     * @dev Need to ensure that either 'route' has been set if setting to
     * VelodromeV2 (+ UniswapV2) or 'path' has been set if setting to UniswapV3.
     */
    function setSwapProtocol(
        address _tokenA,
        address _tokenB,
        SwapProtocol _swapProtocol
    )   external
        onlyAdmin
        returns (bool)
    {
        require(
            s.swapProtocol[_tokenA][_tokenB] != _swapProtocol,
            'SwapManagerFacet: Requested swap protocol already set'
        );
        if (s.swapProtocol[_tokenA][_tokenB] == SwapProtocol(0)) {
            s.supportedSwaps[_tokenA].push(_tokenB);
            // As setting reverse route.
            s.supportedSwaps[_tokenB].push(_tokenA);
            // If revoking swaps for token pair entirely.
        } else if (_swapProtocol == SwapProtocol(0)) {
            for (uint i = 0; i < s.supportedSwaps[_tokenA].length; i++) {
                if (s.supportedSwaps[_tokenA][i] == _tokenB) {
                    s.supportedSwaps[_tokenA][i] =
                        s.supportedSwaps[_tokenA][s.supportedSwaps[_tokenA].length - 1];
                    s.supportedSwaps[_tokenA].pop();
                }
            }
            for (uint i = 0; i < s.supportedSwaps[_tokenB].length; i++) {
                if (s.supportedSwaps[_tokenB][i] == _tokenA) {
                    s.supportedSwaps[_tokenB][i] =
                        s.supportedSwaps[_tokenB][s.supportedSwaps[_tokenB].length - 1];
                    s.supportedSwaps[_tokenB].pop();
                }
            }
        }
        s.swapProtocol[_tokenA][_tokenB] = _swapProtocol;
        s.swapProtocol[_tokenB][_tokenA] = _swapProtocol;
        return true;
    }

    /**
     * @dev Sets VelodromeV2 (+ UniswapV2) "routes".
     * @dev Sets forward and reverse order.
     */
    function setRoute(
        address _tokenA,
        address _tokenMid,
        address _tokenB,
        bool[2] calldata _stable
    )   external
        onlyAdmin
        returns (bool)
    {
        s.route[_tokenA][_tokenB].mid = _tokenMid;
        s.route[_tokenB][_tokenA].mid = _tokenMid;
        s.route[_tokenA][_tokenB].stable = _stable;
        s.route[_tokenB][_tokenA].stable = _stable;
        // Only care about/want to reverse stable order if using a mid.
        if (s.route[_tokenA][_tokenB].mid != address(0)) {
            // E.g. wETH (=> USDC) => DAI: [false, true]
            // Therefore, DAI (=> USDC) => wETH: [!false, !true] = [true, false]
            s.route[_tokenB][_tokenA].stable[0] = !_stable[0];
            s.route[_tokenB][_tokenA].stable[1] = !_stable[1];
        }
        return true;
    }

    /**
     * @dev Sets UniswapV3 "paths".
     * @dev Sets forward and reverse order.
     */
    function setPath(
        address _tokenA,
        uint24  _poolFee1,
        address _tokenMid,
        uint24  _poolFee2,
        address _tokenB
    )   external
        returns (bool)
    {
        if (_poolFee2 == 0 || _tokenMid == address(0)) {
            s.path[_tokenA][_tokenB] = abi.encodePacked(_tokenA, _poolFee1, _tokenB);
            s.path[_tokenB][_tokenA] = abi.encodePacked(_tokenB, _poolFee1, _tokenA);
        }
        else {
            s.path[_tokenA][_tokenB] = abi.encodePacked(
                _tokenA,
                _poolFee1,
                _tokenMid, // Usually wETH.
                _poolFee2,
                _tokenB
            );
            s.path[_tokenB][_tokenA] = abi.encodePacked(
                _tokenB,
                _poolFee2,
                _tokenMid, // Usually wETH.
                _poolFee1,
                _tokenA
            );
        }
        return true;
    }

    /**
     * @dev Overrides default slippage. To revert to default, set to 0.
     * @dev Sets slippage for forward and reverse order.
     */
    function setSlippage(
        uint256 _slippage,
        address _tokenA,
        address _tokenB
    )   external
        onlyAdmin
        returns (bool)
    {
        s.swapInfo[_tokenA][_tokenB].slippage = _slippage;
        s.swapInfo[_tokenB][_tokenA].slippage = _slippage;
        return true;
    }

    /**
     * @dev Overrides default wait. To revert to default, set to 0.
     * @dev Sets wait for forward and reverse order.
     */
    function setWait(
        uint256 _wait,
        address _tokenA,
        address _tokenB
    )   external
        onlyAdmin
        returns (bool)
    {
        s.swapInfo[_tokenA][_tokenB].wait = _wait;
        s.swapInfo[_tokenB][_tokenA].wait = _wait;
        return true;
    }

    function setDefaultSlippage(
        uint256 _slippage
    )   external
        onlyAdmin
    {
        s.defaultSlippage = _slippage;
    }

    function setDefaultWait(
        uint256 _wait
    )   external
        onlyAdmin
    {
        s.defaultSlippage = _wait;
    }

    /// @notice Sets Chainlink price oracle used to retrieve prices for swaps.
    function setPriceFeed(
        address _token,
        address _priceFeed
    )   external
        onlyAdmin
        returns (bool)
    {
        s.priceFeed[_token] = _priceFeed;
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                                Getters
    //////////////////////////////////////////////////////////////*/

    function getSwapProtocol(
        address _tokenA,
        address _tokenB
    )   external view
        returns (SwapProtocol)
    {
        return s.swapProtocol[_tokenA][_tokenB];
    }

    function getSupportedSwaps(
        address _token
    )   external view
        returns (address[] memory)
    {
        return s.supportedSwaps[_token];
    }

    function getRoute(
        address _tokenA,
        address _tokenB
    )   external view
        returns (Route memory)
    {
        return s.route[_tokenA][_tokenB];
    }

    function getPath(
        address _tokenA,
        address _tokenB
    )   external view
        returns (bytes memory)
    {
        return s.path[_tokenA][_tokenB];
    }

    function getSlippage(
        address _tokenA,
        address _tokenB
    )   external view
        returns (uint256)
    {
        return s.swapInfo[_tokenA][_tokenB].slippage;
    }

    function getWait(
        address _tokenA,
        address _tokenB
    )   external view
        returns (uint256)
    {
        return s.swapInfo[_tokenA][_tokenB].wait;
    }

    function getDefaultSlippage(
    )   external view
        returns (uint256)
    {
        return s.defaultSlippage;
    }

    function getDefaultWait(
    )   external view
        returns (uint256)
    {
        return s.defaultWait;
    }

    function getPriceFeed(
        address _token
    )   external view
        returns (address)
    {
        return s.priceFeed[_token];
    }

    /// @notice Returns the minimum amount received from a swap operation.
    function getAmountOutMin(
        uint256 _amountIn,
        address _from,
        address _to
    )   external view
        returns (uint256 amountOutMin)
    {
        return LibSwap._getAmountOutMin(_amountIn, _from, _to);
    }

    /**
     * @notice Returns the price of amount '_from' denominated in '_to'.
     * @param _amount   The amount of from asset to convert from.
     * @param _fee      A custom deduction amount in basis points applied to amount.
     * @param _from     The asset to convert from.
     * @param _to       The asset to convert to.
     */
    function getConversion(
        uint256 _amount,
        uint256 _fee,
        address _from,
        address _to
    )   external view
        returns (uint256 fromTo)
    {
        return LibSwap._getConversion(_amount, _fee, _from, _to);
    }
}