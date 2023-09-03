// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStakingRewards {

    function balanceOf(address account) external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function withdraw(uint256 amount) external;
    function getReward() external;
    function exit() external;
}