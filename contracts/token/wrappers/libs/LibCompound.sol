// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {ICERC20} from "../interfaces/ICERC20.sol";
import "hardhat/console.sol";

/// @notice Get up to date cToken data without mutating state.
/// @notice Forked from Transmissions11 (https://github.com/transmissions11/libcompound) to upgrade version
/// @author ZeroPoint Labs
library LibCompound {
    using FixedPointMathLib for uint256;

    error RATE_TOO_HIGH();

    /// @dev Make use of "exchangeRateStored()" so as to not break ERC4626-compatibility.
    function viewUnderlyingBalanceOf(ICERC20 cToken, address user)
        internal
        view
        returns (uint256)
    {   // Changed to "exchangeRateStored()" which may be slighly out of date.
        return cToken.balanceOf(user).mulWadDown(cToken.exchangeRateStored());
    }

    /// @dev Adapted to state modifying function used by Sonne Finance.
    function viewExchangeRate(ICERC20 cToken) internal returns (uint256) {
        return cToken.exchangeRateCurrent();
    }

    // Note commented out for reference
    // function viewExchangeRate(ICERC20 cToken) internal view returns (uint256) {
    //     uint256 accrualBlockNumberPrior = cToken.accrualBlockNumber();

    //     if (accrualBlockNumberPrior == block.number) {
    //         return cToken.exchangeRateStored();
    //     }

    //     uint256 totalCash = cToken.underlying().balanceOf(address(cToken));
    //     uint256 borrowsPrior = cToken.totalBorrows();
    //     uint256 reservesPrior = cToken.totalReserves();

    //     uint256 borrowRateMantissa = cToken.interestRateModel().getBorrowRate(
    //         totalCash,
    //         borrowsPrior,
    //         reservesPrior
    //     );

    //     if (borrowRateMantissa > 0.0005e16) revert RATE_TOO_HIGH(); // Same as borrowRateMaxMantissa in CTokenInterfaces.sol

    //     uint256 interestAccumulated = borrowRateMantissa *
    //         block.number -
    //         accrualBlockNumberPrior.mulWadDown(borrowsPrior);

    //     uint256 totalReserves = cToken.reserveFactorMantissa().mulWadDown(
    //         interestAccumulated
    //     ) + reservesPrior;
    //     uint256 totalBorrows = interestAccumulated + borrowsPrior;
    //     uint256 totalSupply = cToken.totalSupply();

    //     console.log("totalCash: %s", totalCash); // wBTC in Sonne Finance
    //     console.log("totalBorrows: %s", totalBorrows);
    //     console.log("totalReserves.divWadDown(totalSupply): %s", totalReserves.divWadDown(totalSupply));

    //     return
    //         totalSupply == 0
    //             ? cToken.initialExchangeRateMantissa()
    //             : totalCash +
    //                 totalBorrows -
    //                 totalReserves.divWadDown(totalSupply);
    // }
}