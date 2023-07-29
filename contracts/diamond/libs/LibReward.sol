// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AppStorage, LibAppStorage } from './LibAppStorage.sol';

library LibReward {

    /// @notice Emitted when external points are distributed (not tied to yield).
    ///
    /// @param  account The recipient of the points.
    /// @param  amount  The amount of points distributed.
    event RewardDistributed(address indexed account, uint256 amount);

    /// @notice Emitted when a referral is executed.
    ///
    /// @param  referral    The account receiving the referral reward.
    /// @param  account     The account using the referral.
    /// @param  amount      The amount of points distributed to the referral account.
    event Referral(address indexed referral, address indexed account, uint256 amount);

    /// @notice Distributes rewards not tied to yield.
    ///
    /// @param  _account    The recipient.
    /// @param  _points     The amount of points distributed.
    function _reward(
        address _account,
        uint256 _points
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        s.XPC[_account] += _points;
        emit RewardDistributed(_account, _points);
    }

    /// @notice Reward distributed for each new first deposit.
    function _initReward(
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (
            // If there is a sign-up reward.
            s.initReward != 0 &&
            // If the user has not already claimed their sign-up reward.
            s.rewardStatus[msg.sender].initClaimed == 0
        ) {
            // Provide user with sign-up reward.
            s.XPC[msg.sender] += s.initReward;
            emit RewardDistributed(msg.sender, s.initReward);
            // Mark user as having claimed their sign-up reward.
            s.rewardStatus[msg.sender].initClaimed == 1;
        }
    }

    /// @notice Reward distributed for each referral.
    ///
    /// @param  _referral   The referral account.
    function _referReward(
        address _referral
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (
            // If there is a refer reward.
            s.referReward != 0 &&
            // If the user has not already claimed a refer reward.
            s.rewardStatus[msg.sender].referClaimed == 0 &&
            // If the referrer is a whitelisted account.
            s.isWhitelisted[_referral] == 1 &&
            // If referrals are enabled.
            s.rewardStatus[_referral].referDisabled != 1
        ) {
            // Apply referral to user.
            s.XPC[msg.sender] += s.referReward;
            emit RewardDistributed(msg.sender, s.referReward);
            // Provide referrer with reward.
            s.XPC[_referral] += s.referReward;
            emit RewardDistributed(_referral, s.referReward);
            // Mark user as having claimed their one-time referral.
            s.rewardStatus[msg.sender].referClaimed == 1;
        }
    }
}