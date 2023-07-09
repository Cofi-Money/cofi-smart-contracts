// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStakingRewardsZap {

    function zapIn(address _targetVault, uint256 _underlyingAmount) external returns (uint256);
}