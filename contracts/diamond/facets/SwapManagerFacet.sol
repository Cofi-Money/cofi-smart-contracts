// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SwapProtocol, SwapRouteV2, Modifiers } from '../libs/LibAppStorage.sol';
import { LibSwap } from '../libs/LibSwap.sol';
import { IERC4626 } from '../interfaces/IERC4626.sol';

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
     * @dev Need to ensure that swap route has been set beforehand.
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
     * @dev Sets UniswapV2 + VelodromeV2 swap routes.
     * @dev Sets forward and reverse order.
     */
    function setV2Route(
        address _tokenA,
        address _tokenMid,
        address _tokenB,
        bool[2] calldata _stable
    )   external
        onlyAdmin
        returns (bool)
    {
        s.swapRouteV2[_tokenA][_tokenB].mid = _tokenMid;
        s.swapRouteV2[_tokenB][_tokenA].mid = _tokenMid;
        s.swapRouteV2[_tokenA][_tokenB].stable = _stable;
        s.swapRouteV2[_tokenB][_tokenA].stable = _stable;
        // Only care about/want to reverse stable order if using a mid.
        if (s.swapRouteV2[_tokenA][_tokenB].mid != address(0)) {
            // E.g. wETH (=> USDC) => DAI: [false, true]
            // Therefore, DAI (=> USDC) => wETH: [!false, !true] = [true, false]
            s.swapRouteV2[_tokenB][_tokenA].stable[0] = !_stable[0];
            s.swapRouteV2[_tokenB][_tokenA].stable[1] = !_stable[1];
        }
        return true;
    }

    /**
     * @dev Sets UniswapV3 swap routes.
     * @dev Sets forward and reverse order.
     */
    function setV3Route(
        address _tokenA,
        uint24  _poolFee1,
        address _tokenMid,
        uint24  _poolFee2,
        address _tokenB
    )   external
        returns (bool)
    {
        if (_poolFee2 == 0 || _tokenMid == address(0)) {
            s.swapRouteV3[_tokenA][_tokenB] = abi.encodePacked(_tokenA, _poolFee1, _tokenB);
            s.swapRouteV3[_tokenB][_tokenA] = abi.encodePacked(_tokenB, _poolFee1, _tokenA);
        }
        else {
            s.swapRouteV3[_tokenA][_tokenB] = abi.encodePacked(
                _tokenA,
                _poolFee1,
                _tokenMid, // Usually wETH.
                _poolFee2,
                _tokenB
            );
            s.swapRouteV3[_tokenB][_tokenA] = abi.encodePacked(
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
        // If tokenA = coUSD, e.g., returns its underlying USDC.
        _tokenA = _getForCofi(_tokenA);
        _tokenB = _getForCofi(_tokenB);
        return s.swapProtocol[_tokenA][_tokenB];
    }

    /**
     * @notice  Returns an array of tokens that are supported for swapping between.
     *          ETH/wETH are supported for all COFI tokens by default, as well as its current
     *          underlying token, so the array excludes these.
     *          E.g., coUSD => [DAI] (+ current underlying USDC) (+ ETH/wETH) are supported
     *          when minting and burning coUSD via 'enterCofi()' and 'exitCofi()' functions, respectively.
     *          2nd e.g., coBTC => []. Therfore can only mint coBTC with its underlying (wBTC)
     *          or ETH/wETH.
     */
    function getSupportedSwaps(
        address _token
    )   external view
        returns (address[] memory)
    {
        _token = _getForCofi(_token);
        return s.supportedSwaps[_token];
    }

    function getSwapRouteV2(
        address _tokenA,
        address _tokenB
    )   external view
        returns (SwapRouteV2 memory)
    {
        _tokenA = _getForCofi(_tokenA);
        _tokenB = _getForCofi(_tokenB);
        return s.swapRouteV2[_tokenA][_tokenB];
    }

    function getSwapRouteV3(
        address _tokenA,
        address _tokenB
    )   external view
        returns (bytes memory)
    {
        _tokenA = _getForCofi(_tokenA);
        _tokenB = _getForCofi(_tokenB);
        return s.swapRouteV3[_tokenA][_tokenB];
    }

    function getSlippage(
        address _tokenA,
        address _tokenB
    )   external view
        returns (uint256)
    {
        _tokenA = _getForCofi(_tokenA);
        _tokenB = _getForCofi(_tokenB);
        return s.swapInfo[_tokenA][_tokenB].slippage;
    }

    function getWait(
        address _tokenA,
        address _tokenB
    )   external view
        returns (uint256)
    {
        _tokenA = _getForCofi(_tokenA);
        _tokenB = _getForCofi(_tokenB);
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
        /// @dev Refer to the price feed for the underlying.
        _token = _getForCofi(_token);
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
        _from = _getForCofi(_from);
        _to = _getForCofi(_to);
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
        _from = _getForCofi(_from);
        _to = _getForCofi(_to);
        return LibSwap._getConversion(_amount, _fee, _from, _to);
    }

    function _getForCofi(
        address _token
    )   internal view
        returns (address underlying)
    {
        if (s.vault[_token] != address(0)) return IERC4626(s.vault[_token]).asset();
        else return _token;
    }
}