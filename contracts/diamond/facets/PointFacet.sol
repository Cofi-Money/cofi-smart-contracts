// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author The Stoa Corporation Ltd.
    @title  Point Facet
    @notice Provides logic for managing points.
 */

import { Modifiers } from '../libs/LibAppStorage.sol';
import { LibToken } from '../libs/LibToken.sol';
import { LibReward } from '../libs/LibReward.sol';
import { PercentageMath } from '../libs/external/PercentageMath.sol';
import { IERC4626 } from '../interfaces/IERC4626.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PointFacet is Modifiers {
    using PercentageMath for uint256;

    /*//////////////////////////////////////////////////////////////
                            STATE CHANGE
    //////////////////////////////////////////////////////////////*/

    /// @notice This function must be called after the last rebase of a pointsRate
    ///         and before the application of a new pointsRate for a given fiAsset,
    ///         for every account that is eliigble for yield/points. If not, the new
    ///         pointsRate will apply to yield earned during the previous, different
    ///         pointsRate epoch - which we want to avoid.
    ///
    /// @dev    This function may be required to be called multiple times, as per the
    ///         size limit for passing addresses, in order for all relevant accounts
    ///         to be updated.
    ///
    /// @dev    Rebasing for the relevant fiAsset should be paused beforehand so as to
    ///         not interupt this process.
    ///
    /// @param  accounts    The array of accounts to capture points for.
    /// @param  fiAsset     The fiAsset to capture points for.
    function captureYieldPoints(
        address[] memory    accounts,
        address             fiAsset
    )   external
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
        for(uint i = 0; i < accounts.length; ++i) {
        yield = LibToken._getYieldEarned(accounts[i], fiAsset);
            // If the account has earned yield since the last yield capture event.
            if (s.YPC[accounts[i]][fiAsset].yield < yield) {
                s.YPC[accounts[i]][fiAsset].points +=
                    (yield - s.YPC[accounts[i]][fiAsset].yield)
                        .percentMul(s.pointsRate[fiAsset]);
                s.YPC[accounts[i]][fiAsset].yield = yield;
            }
        }
        return true;
    }

    /// @notice Function for distributing points not intrinsically linked to yield.
    ///
    /// @param  accounts    The array of accounts to distribute points for.
    /// @param  points      The amount of points to distribute to each account.
    function reward(
        address[] memory    accounts,
        uint256             points
    )   external
        onlyAdmin
        returns (bool)
    {
        for(uint i = 0; i < accounts.length; ++i) {
            LibReward._reward(accounts[i], points);
        }
        return true;
    }

    /// @dev    Yield points must be captured beforehand to ensure they
    ///         have updated correctly prior to a pointsRate change.
    function setPointsRate(
        address fiAsset,
        uint256 amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.pointsRate[fiAsset] = amount;
        return true;
    }

    /// @dev Setting to 0 deactivates.
    function setInitReward(
        uint256 amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.initReward = amount;
        return true;
    }

    /// @dev Setting to 0 deactivates.
    function setReferReward(
        uint256 amount
    )   external
        onlyAdmin
        returns (bool)
    {
        s.referReward = amount;
        return true;
    }

    function setRewardStatus(
        address account,
        uint8   initClaimed,
        uint8   referClaimed,
        uint8   referDisabled
    )   external
        onlyAdmin
        returns (bool)
    {
        s.rewardStatus[account].initClaimed     = initClaimed;
        s.rewardStatus[account].referClaimed    = referClaimed;
        s.rewardStatus[account].referDisabled   = referDisabled;
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the total number of points accrued for a given account
    ///         (accrued through yield earnings and other means).
    ///
    /// @param  account     The address to enquire for.
    /// @param  fiAssets    An array of fiAssets to retrieve data for.
    function getPoints(
        address             account,
        address[] memory    fiAssets
    )   public
        view
        returns (uint256 pointsTotal)
    {
        pointsTotal = getYieldPoints(account, fiAssets) + s.XPC[account];
    }

    /// @notice Returns the number of points accrued, through yield earnings, across
    ///         a given number of fiAssets (e.g., [COFI, COFIE]).
    ///
    /// @param  account     The address to enquire for.
    /// @param  fiAssets    An array of fiAssets to retrieve data for.
    function getYieldPoints(
        address             account,
        address[] memory    fiAssets
    )   public
        view
        returns (uint256 pointsTotal)
    {
        uint256 yield;
        uint256 pointsCaptured;
        uint256 pointsPending;

        for(uint i = 0; i < fiAssets.length; ++i) {
            yield           += LibToken._getYieldEarned(account, fiAssets[i]);
            pointsCaptured  += s.YPC[account][fiAssets[i]].points;
            pointsPending   += (yield - s.YPC[account][fiAssets[i]].yield)
                .percentMul(s.pointsRate[fiAssets[i]]);
            pointsTotal     += pointsCaptured + pointsPending;
        }
    }

    function getExternalPoints(
        address account
    )   public
        view
        returns (uint256)
    {
        return s.XPC[account];
    }

    /// @return The pointsRate denominated in basis points.
    function getPointsRate(
        address fiAsset
    )   external
        view
        returns (uint256)
    {
        return s.pointsRate[fiAsset];
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
        address account
    )   external
        view
        returns (uint8, uint8, uint8)
    {
        return (
            s.rewardStatus[account].initClaimed,
            s.rewardStatus[account].referClaimed,
            s.rewardStatus[account].referDisabled
        );
    }
}