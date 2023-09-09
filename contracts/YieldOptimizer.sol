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
        // An array of assets for the given shares ref, stored in chronological order.
        uint256[] assets;
        // Should be a minimum number of shares that needs to be maintained.
        uint256 initSharesRef;
        // Indicates if this vault can migrated to.
        uint8 enabled;
    }

    error VAULT_NOT_FOUND();
    error INSUFFICIENT_ENTRIES();

    constructor() {
        authorized[msg.sender] = 1;
    }

    function calculateEMA(address vaultAddress, uint256[] memory prices) internal view returns (uint256) {
        require(prices.length >= 10, "Not enough price data for EMA calculation");
        
        uint256 alpha = 2 * (10 + 1); // EMA smoothing factor
        uint256 ema = prices[0]; // Initialize EMA with the first price
        
        for (uint256 i = 1; i < 10; i++) {
            ema = (prices[i] * alpha + ema * (10 - 1)) / (alpha + 1);
        }
        
        return ema;
    }
    
    function compareVaults() external view returns (address) {
        // Replace with actual price retrieval logic
        // For this example, we assume you have a function to get the last 10 prices
        uint256[] memory vault1Prices = getVaultPrices(vault1);
        uint256[] memory vault2Prices = getVaultPrices(vault2);
        
        // Calculate EMA for both vaults
        uint256 emaVault1 = calculateEMA(vault1, vault1Prices);
        uint256 emaVault2 = calculateEMA(vault2, vault2Prices);
        
        // Determine which vault has a greater EMA
        if (emaVault1 > emaVault2) {
            return vault1;
        } else {
            return vault2;
        }
    }
    
    // Replace with actual price retrieval logic
    // This is just a placeholder function
    function getVaultPrices(address vaultAddress) internal view returns (uint256[] memory) {
        // Implement your logic to fetch the last 10 prices for the vault
        // Return an array with the most recent price at index 0 and older prices in ascending order
        // Make sure you handle cases where there aren't enough prices yet
        // For this example, we assume you have such logic in place.
    }

    /**
     * @notice Captures assets from the shares ref point across all vaults.
     * @dev Need to ensure captures are triggered over equal time intervals.
     */
    function capture(
        address _cofi
    )   public
        onlyAuthorized
        returns (bool)
    {
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
     * @notice 
     */
    function retrieve(
        address _vault,
        uint256 _entries,
        uint8   _strict
    )   public view
        onlyAuthorized
        returns (uint256 yield, uint256 smoothYield)
    {
        // Get assetsDelta between entries.
        for (uint i = vaultInfo[_vault].assets.length - _entries; i < vaultInfo[_vault].assets.length; i++) {

        }

        // Order numerically and return median.

        if (vaultInfo[_vault].assets.length < _entries) {
            if (_strict > 0) {
                revert INSUFFICIENT_ENTRIES();
            }
            _entries = vaultInfo[_vault].assets.length;
        }

        yield =
            vaultInfo[_vault].assets[vaultInfo[_vault].assets.length - 1] -
            vaultInfo[_vault].assets[vaultInfo[_vault].assets.length - _entries];

        smoothYield = yield / _entries;
    }

    /**
     * @notice 
     */
    function evaluate(
        address _cofi,
        uint256 _entries,
        uint8   _strict
    )   public view
        onlyAuthorized
        returns (address target, uint256 yield)
    {
        for (uint i = 0; i < vaults[_cofi].length; i++) {
            uint256 round = retrieve(vaults[_cofi][i], _entries, _strict);
            if (yield < round) {
                yield = round;
                target = vaults[_cofi][i];
            }
        }
    }

    function optimize(
        address _cofi,
        uint256 _entries,
        uint8   _strict
    )

    function addVault(
        address _cofi,
        address _vault
    )   external onlyAuthorized returns (bool) {

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