// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Modifiers } from '../libs/LibAppStorage.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibReward } from '../libs/LibReward.sol';
import { PercentageMath } from '../libs/external/PercentageMath.sol';
import { IERC4626 } from '../interfaces/IERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Point Facet
    @notice Provides logic for managing and distributing points.
 */

contract PointFacet is Modifiers {
    using PercentageMath for uint256;

    /*//////////////////////////////////////////////////////////////
                            Rewards Management
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  This function must be called after the last rebase of a 'pointsRate' and before
     *          the application of a new 'pointsRate' for a given cofi token, for every account
     *          that is eliigble for yield/points. If not, the new 'pointsRate' will apply to
     *          yield earned during the previous, different pointsRate epoch - which we want to avoid.
     *
     * @dev This function may be required to be called multiple times, as per the size limit for
     *      passing addresses, in order for all relevant accounts to be updated. Rebasing for the
     *      relevant cofi token should be paused beforehand so as to not interupt this process.
     * @param _accounts The array of accounts to capture points for.
     * @param _cofi     The cofi token to capture points for.
     */
    function captureYieldPoints(
        address[] memory    _accounts,
        address             _cofi
    )   external
        nonReentrant
        returns (bool)
    {
        /**
         * @dev Points capture:
         *      1.  Get current yield earned of accounts.
         *      2.  If greater than previous yield earned, apply points for difference.
         *      3.  Update yield earned internally.
         *
         * @dev Determine which accounts to pass for (1):
         *      1.  Take a snapshot of all holders immediately after each rebase for the
         *          current points epoch.
         *      2.  If a new address is dectected, add to array, otherwise skip.
         *      3.  Start with empty array for next points epoch.
         */
        uint256 yield;
        for(uint i = 0; i < _accounts.length; ++i) {
        yield = LibToken._getYieldEarned(_accounts[i], _cofi);
            // If the account has earned yield since the last yield capture event.
            if (s.YPC[_accounts[i]][_cofi].yield < yield) {
                s.YPC[_accounts[i]][_cofi].points +=
                    (yield - s.YPC[_accounts[i]][_cofi].yield)
                        .percentMul(s.pointsRate[_cofi]);
                s.YPC[_accounts[i]][_cofi].yield = yield;
            }
        }
        return true;
    }

    /**
     * @notice Distributed points not intrinsically linked to yield.
     * @param _accounts The array of accounts to distribute points for.
     * @param _amount   The amount of points to distribute to each account.
     */
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
                            Admin - Setters
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Yield points must be captured beforehand to ensure update correctness.
     * @param _cofi         The cofi token to update 'pointsRate' for.
     * @param _pointsRate   The new 'pointsRate' in basis points.
     */
    function setPointsRate(
        address _cofi,
        uint256 _pointsRate
    )   external
        onlyAdmin
        returns (bool)
    {
        s.pointsRate[_cofi] = _pointsRate;
        return true;
    }

    /// @dev Setting to 0 deactivates.
    function setInitReward(
        uint256 _reward
    )   external
        onlyAdmin
        returns (bool)
    {
        s.initReward = _reward;
        return true;
    }

    /// @dev Setting to 0 deactivates.
    function setReferReward(
        uint256 _reward
    )   external
        onlyAdmin
        returns (bool)
    {
        s.referReward = _reward;
        return true;
    }

    /// @dev Used to manually configure reward status of account.
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
                                Getters
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  Returns the total number of points accrued for a given account (accrued through
     *          yield earnings and external means) for a given number of cofi tokens.
     * @param _account  The account to enquire for.
     * @param _cofi     An array of cofi tokens to retrieve points for.
     */
    function getPoints(
        address             _account,
        address[] memory    _cofi
    )   public view
        returns (uint256 pointsTotal)
    {
        pointsTotal = getYieldPoints(_account, _cofi) + s.XPC[_account];
    }

    /**
     * @notice  Returns the number of points accrued, through yield earnings only, across
     *          a given number of cofi tokens (e.g., [coUSD, coETH, coBTC]).
     * @param _account  The account to enquire for.
     * @param _cofi     An array of cofi tokens to retrieve yield points for.
     */
    function getYieldPoints(
        address             _account,
        address[] memory    _cofi
    )   public view
        returns (uint256 pointsTotal)
    {
        uint256 yield;
        uint256 pointsCaptured;
        uint256 pointsPending;

        for(uint i = 0; i < _cofi.length; ++i) {
            yield           += LibToken._getYieldEarned(_account, _cofi[i]);
            pointsCaptured  += s.YPC[_account][_cofi[i]].points;
            pointsPending   += (yield - s.YPC[_account][_cofi[i]].yield)
                .percentMul(s.pointsRate[_cofi[i]]);
            pointsTotal     += pointsCaptured + pointsPending;
        }
    }

    /**
     * @notice Gets external points for an account, earned through means not tied to yield.
     * @param _account The account to enquire for.
     */
    function getExternalPoints(
        address _account
    )   public view
        returns (uint256)
    {
        return s.XPC[_account];
    }

    /// @return The 'pointsRate' denominated in basis points.
    function getPointsRate(
        address _cofi
    )   external view
        returns (uint256)
    {
        return s.pointsRate[_cofi];
    }

    function getInitReward(
    )   external view
        returns (uint256)
    {
        return s.initReward;
    }

    function getReferReward(
    )   external view
        returns (uint256)
    {
        return s.referReward;
    }

    function getRewardStatus(
        address _account
    )   external view
        returns (uint8, uint8, uint8)
    {
        return (
            s.rewardStatus[_account].initClaimed,
            s.rewardStatus[_account].referClaimed,
            s.rewardStatus[_account].referDisabled
        );
    }
}