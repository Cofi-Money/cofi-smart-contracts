// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IRouter } from "contracts/interfaces/IRouter.sol";
import { ERC20 } from 'solmate/src/tokens/ERC20.sol';

contract VelodromeSwap {

    IRouter router;
    address factory;

    constructor(
        address _factory,
        IRouter _router
    ) {
        factory = _factory;
        router = _router;
    }
    
    function swapExactTokensForTokens(
        uint256 _amountIn,
        address _from,
        address _to,
        bool _stable
    ) public returns (uint256[] memory amounts) {

        IRouter.Route memory route = IRouter.Route({
            from: _from,
            to: _to,
            stable: _stable,
            factory: factory
        });
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = route;

        ERC20(_from).approve(address(router), type(uint256).max);

        amounts = router.swapExactTokensForTokens(
            _amountIn,
            0, // amountOutMin
            routes,
            address(this), // to
            type(uint256).max // deadline
        );
    }
}