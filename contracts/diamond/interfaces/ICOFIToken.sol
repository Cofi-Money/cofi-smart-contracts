// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author The Stoa Corporation Ltd.
/// @title  COFI Token Interface
/// @notice Interface for executing functions on cofi rebasing tokens.
interface ICOFIToken {

    function mint(address _account, uint256 _amount) external;

    function mintOptIn(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;

    function redeem(address _from, address _to, uint256 _value) external returns (bool);

    function lock(address _account, uint256 _amount) external returns (bool);

    function unlock(address _account, uint256 _amount) external returns (bool);

    function changeSupply(uint256 _newTotalSupply) external;

    function freeBalanceOf(address _account) external view returns (uint256);

    function getYieldEarned(address _account) external view returns (uint256);

    function rebasingCreditsPerTokenHighres() external view returns (uint256);

    function creditsToBal(uint256 _amount) external view returns (uint256);

    function rebaseOptIn() external;

    function rebaseOptOut() external;
}