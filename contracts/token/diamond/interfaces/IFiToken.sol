// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author The Stoa Corporation Ltd.
/// @title  Fi Token Interface
/// @notice Interface for executing functions on Fi tokens.
interface IFiToken {

    function mint(address to, uint amount) external;

    function mintOptIn(address to, uint amount) external;

    function burn(address from, uint amount) external;

    function redeem(address from, address to, uint256 amount) external;

    function changeSupply(uint newTotalSupply) external;

    function getYieldEarned(address account) external view returns (uint256);

    function rebasingCreditsPerTokenHighres() external view returns (uint256);

    function creditsToBal(uint256 amount) external view returns (uint256);

    function rebaseOptIn() external;

    function rebaseOptOut() external;
}