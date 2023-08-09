// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './diamond/interfaces/IERC4626.sol';

interface ICOFIMoney {

    function migrate(address _cofi, address _newVault) external returns (bool);
}

contract YieldOptimizer {

    // E.g., coUSD => [yvUSDC, wsoUSDC, etc.].
    mapping(address => address[]) vaults;

    // E.g., yvUSDC => VaultInfo.
    mapping(address => VaultInfo) vaultInfo;

    mapping(address => uint8) authorized;

    struct VaultInfo {
        uint256[] assets;
        uint256 initSharesRef;
    }

    error VAULT_NOT_FOUND();

    constructor() {
        authorized[msg.sender] = 1;
    }

    /**
     * @notice Captures assets from the shares ref point across all vaults.
     * @dev Need to ensure captures are triggered over equal time intervals.
     */
    function capture(address _cofi) external onlyAuthorized returns (bool) {

        for (uint i = 0; i < vaults[_cofi].length; i++) {
            vaultInfo[vaults[_cofi][i]].assets.push(
                IERC4626(vaults[_cofi][i]).previewRedeem(
                    vaultInfo[vaults[_cofi][i]].initSharesRef
                )
            );
        }
        return true;
    }

    /**
     */
    // function retrieve(address _vault, uint16 _period) public view returns (uint[] memory list) {

    //     list = new uint[](_period);

    //     for (uint i = )
    // }

    /**
     * @notice 
     */
    function evaluate(address _cofi) external view returns (address target) {


    }

    function addVault(address _cofi, address _vault) external onlyAuthorized returns (bool) {

        vaults[_cofi].push(_vault);
        // Need to initialise a ref point for shares to track yield over time.
        // Initialise using all existing shares for max granularity.
        vaultInfo[_vault].initSharesRef = IERC20(_vault).totalSupply();
        return true;
    }

    /**
     * @notice Removes the given vault from the array of available vaults.
     * @dev Does not remove data relating to VaultInfo (use 'resetVault()' for this).
     * @dev If the same vault has been added twice, only removes the prior vault in the array.
     */
    function removeVault(address _cofi, address _vault) external onlyAuthorized returns (bool) {

        for (uint i = 0; i < vaults[_cofi].length; i++) {
            if (vaults[_cofi][i] == _vault) {
                // Move the last element into the index to be deleted.
                vaults[_cofi][i] = vaults[_cofi][vaults[_cofi].length - 1];
                // Remove the last element.
                vaults[_cofi].pop();
                return true;
            }
        }
        revert VAULT_NOT_FOUND();
    }

    function resetVault(address _vault) external onlyAuthorized returns (bool) {

        vaultInfo[_vault].assets = [0];
        vaultInfo[_vault].initSharesRef = 0;
        return true;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender] == 1, 'Caller not authorized');
        _;
    }
}