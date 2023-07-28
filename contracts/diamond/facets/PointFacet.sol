// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers } from '../libs/LibAppStorage.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibReward } from '../libs/LibReward.sol';
import { PercentageMath } from '../libs/external/PercentageMath.sol';
import { IERC4626 } from '../interfaces/IERC4626.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Point Facet
    @notice Provides logic for managing points.
 */

contract PointFacet is Modifiers {
    using PercentageMath for uint256;

    /*//////////////////////////////////////////////////////////////
                            REWARDS MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice This function must be called after the last rebase of a pointsRate
    ///         and before the application of a new pointsRate for a given fi token,
    ///         for every account that is eliigble for yield/points. If not, the new
    ///         pointsRate will apply to yield earned during the previous, different
    ///         pointsRate epoch - which we want to avoid.
    ///
    /// @dev    This function may be required to be called multiple times, as per the
    ///         size limit for passing addresses, in order for all relevant accounts
    ///         to be updated.
    ///
    /// @dev    Rebasing for the relevant fi token should be paused beforehand so as to
    ///         not interupt this process.
    ///
    /// @param  _accounts   The array of accounts to capture points for.
    /// @param  _fi         The fi token to capture points for.
    function captureYieldPoints(
        address[] memory    _accounts,
        address             _fi
    )   external
        nonReentrant
        returns (bool)
    {
        /**
            POINTS CAPTURE:

            1.  Gets current yield earned.
            2.  If greater than previous yield earned, apply points
                for difference.
            3.  Update yield earned.

            DETERMINE WHICH ACCOUNTS TO PASS:

            1.  Take a snapshot of all holders immediately after each rebase
                for the current points epoch.
            2.  If a new address is dectected, add to array, otherwise skip.
            3.  After the last rebase of the current points epoch, capture yield
                for all addresses in array.
            4.  Start with empty array for next points epoch.
         */
        uint256 yield;
        for(uint i = 0; i < _accounts.length; ++i) {
        yield = LibToken._getYieldEarned(_accounts[i], _fi);
            // If the account has earned yield since the last yield capture event.
            if (s.YPC[_accounts[i]][_fi].yield < yield) {
                s.YPC[_accounts[i]][_fi].points +=
                    (yield - s.YPC[_accounts[i]][_fi].yield)
                        .percentMul(s.pointsRate[_fi]);
                s.YPC[_accounts[i]][_fi].yield = yield;
            }
        }
        return true;
    }

    /// @notice Function for distributing points not intrinsically linked to yield.
    ///
    /// @param  _accounts   The array of accounts to distribute points for.
    /// @param  _amount     The amount of points to distribute to each account.
    function reward(
        address[] memory    _accounts,
        uint256             _amount
    )   external
        onlyAdmin
        returns (bool)
    {
        for(uint i = 0; i < _accounts.length; ++i) {
            LibReward._reward(_accounts[i], _amount);
        }
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN - SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @dev    Yield points must be captured beforehand to ensure they
    ///         have updated correctly prior to a pointsRate change.
    function setPointsRate(
        address _fi,
        uint256 _amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.pointsRate[_fi] = _amount;
        return true;
    }

    /// @dev Setting to 0 deactivates.
    function setInitReward(
        uint256 _amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.initReward = _amount;
        return true;
    }

    /// @dev Setting to 0 deactivates.
    function setReferReward(
        uint256 _amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.referReward = _amount;
        return true;
    }

    function setRewardStatus(
        address _account,
        uint8   _initClaimed,
        uint8   _referClaimed,
        uint8   _referDisabled
    )   external
        onlyAdmin
        returns (bool)
    {
        s.rewardStatus[_account].initClaimed    = _initClaimed;
        s.rewardStatus[_account].referClaimed   = _referClaimed;
        s.rewardStatus[_account].referDisabled  = _referDisabled;
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the total number of points accrued for a given account
    ///         (accrued through yield earnings and other means).
    ///
    /// @param  _account    The address to enquire for.
    /// @param  _fi         An array of fi tokens to retrieve data for.
    function getPoints(
        address             _account,
        address[] memory    _fi
    )   public
        view
        returns (uint256 pointsTotal)
    {
        pointsTotal = getYieldPoints(_account, _fi) + s.XPC[_account];
    }

    /// @notice Returns the number of points accrued, through yield earnings, across
    ///         a given number of fi tokens (e.g., [fiUSD, fiETH, fiBTC]).
    ///
    /// @param  _account    The address to enquire for.
    /// @param  _fi         An array of fi tokens to retrieve yield points for.
    function getYieldPoints(
        address             _account,
        address[] memory    _fi
    )   public
        view
        returns (uint256 pointsTotal)
    {
        uint256 yield;
        uint256 pointsCaptured;
        uint256 pointsPending;

        for(uint i = 0; i < _fi.length; ++i) {
            yield           += LibToken._getYieldEarned(_account, _fi[i]);
            pointsCaptured  += s.YPC[_account][_fi[i]].points;
            pointsPending   += (yield - s.YPC[_account][_fi[i]].yield)
                .percentMul(s.pointsRate[_fi[i]]);
            pointsTotal     += pointsCaptured + pointsPending;
        }
    }

    function getExternalPoints(
        address _account
    )   public
        view
        returns (uint256)
    {
        return s.XPC[_account];
    }

    /// @return The pointsRate denominated in basis points.
    function getPointsRate(
        address _fi
    )   external
        view
        returns (uint256)
    {
        return s.pointsRate[_fi];
    }

    function getInitReward(
    )   external
        view
        returns (uint256)
    {
        return s.initReward;
    }

    function getReferReward(
    )   external
        view
        returns (uint256)
    {
        return s.referReward;
    }

    function getRewardStatus(
        address _account
    )   external
        view
        returns (uint8, uint8, uint8)
    {
        return (
            s.rewardStatus[_account].initClaimed,
            s.rewardStatus[_account].referClaimed,
            s.rewardStatus[_account].referDisabled
        );
    }
}