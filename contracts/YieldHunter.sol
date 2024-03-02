// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'contracts/diamond/interfaces/IERC4626.sol';
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface ICOFIMoney {

    function getVault(address _cofi) external view returns (address);

    function migrate(address _cofi, address _newVault) external returns (bool);
}

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Yield Hunter
    @notice "Hunts" the highest yields by comparing vaults of a given cofi token.
    @dev To perform the assets migration, this contract needs to be granted 'isUpkeep' role.
 */

contract YieldHunter {
    using SafeMath for uint256;

    /// @dev E.g., coUSD => [yvUSDC, wsoUSDC, yvDAI, etc.].
    mapping(address => address[]) public vaults;

    // E.g., yvUSDC => VaultInfo.
    mapping(address => VaultInfo) public vaultInfo;

    mapping(address => bool) authorized;

    ICOFIMoney cofiMoney;

    struct VaultInfo {
        // An array of assets value for the given shares ref, stored in chronological order.
        uint256[] assets;
        // Should be a minimum number of shares that needs to be maintained.
        /// @dev Should be total supply of shares at current point in time for max granularity.
        uint256 initSharesRef;
        // The decimals of the vault shares (usually the same as the underlying asset).
        uint256 decimals;
        // Indicates if this vault can migrated to.
        bool enabled;
    }

    enum Strategy {
        Mean,
        Median
        // Future deployments can add more strategies as necessary.
    }

    error VAULT_NOT_FOUND();
    error INSUFFICIENT_ENTRIES();
    error UNKNOWN_METHOD();

    constructor(
        address _diamond
    )
    {
        authorized[msg.sender] = true;
        cofiMoney = ICOFIMoney(_diamond);
    }

    /***************************************
                Yield Hunting Logic
    ****************************************/

    /**
     * @notice Captures assets from the shares ref point across all vaults, respectively.
     * @dev Need to ensure that captures are triggered over equal time intervals.
     * @dev Note that 'hunt()' also triggers 'capture()', so only one of these functions should
     *      be called at a time. If you no longer wish to trigger migrations but continue capturing
     *      assets values, ensure 'capture()' picks up the established cadence, and vice versa.
     *      Alternatively, you could disable all vaults and continue calling 'hunt()'.
     * @dev Intentionally, there is not a function to capture assets for a singular vault. This is
            to ensure that vault yield earnings are measured over equal periods.
     * @param _cofi The cofi token to capture assets values across each vault for.
     */
    function capture(
        address _cofi
    )   public onlyAuthorized
        returns (bool)
    {
        for (uint i; i < vaults[_cofi].length; i++) {
            vaultInfo[vaults[_cofi][i]].assets.push(
                IERC4626(vaults[_cofi][i]).previewRedeem(
                    vaultInfo[vaults[_cofi][i]].initSharesRef
                )
            );
        }
        return true;
    }

    /**
     * @notice Evaluates mean across ENABLED vaults only.
     * @param _cofi    The cofi token to evaluate which vault has the highest yield w.r.t. mean avg.
     * @param _entries The number of entries to evaluate.
     *                 E.g., if 3 entries which are captured 24h apart:
     *                 (start) capture entry_1 (+24h) + capture entry_2 (+24h) + capture entry_3 (finish) = 2 days.
     *                 Therefore: _entries - 1 = period.
     * @param _strict  See 'validEntries()' modifier.
     */
    function evaluateMean(
        address _cofi,
        uint256 _entries,
        bool    _strict
    )   public view
        returns (address target)
    {
        require(vaults[_cofi].length > 0, 'YieldHunter: Nothing to evaluate');

        // Get the first enabled vault in the vaults array and set that as the inital target.
        uint j;
        for (uint i; i < vaults[_cofi].length; i++) {
            if (vaultInfo[vaults[_cofi][i]].enabled) {
                target = vaults[_cofi][i];
                j = i;
                break;
            }
        }
        // If no enabled vaults found.
        if (target == address(0)) {
            return target;
        }

        uint256 winner = getTotalVaultYield(target, _entries, _strict, true);

        // Start from next index in prior for loop.
        for (uint i = j + 1; i < vaults[_cofi].length; i++) {
            // Again, skip disabled vaults.
            if (!vaultInfo[vaults[_cofi][i]].enabled) {
                continue;
            }
            /// @dev 'getTotalVaultYield()' is more computationally efficient than
            ///      'getMeanVaultYield()' and will always result in the same 'target'.
            uint256 round = getTotalVaultYield(vaults[_cofi][i], _entries, _strict, true);
            if (round > winner) {
                winner = round;
                target = vaults[_cofi][i];
            }
        }
    }

    /**
     * @notice Includes disabled vaults - can be useful for benchmarking.
     */
    function evaluateMeanInclDisabled(
        address _cofi,
        uint256 _entries,
        bool    _strict
    )   public view
        returns (address target)
    {
        require(vaults[_cofi].length > 0, 'YieldHunter: Nothing to evaluate');

        target = vaults[_cofi][0];

        uint256 winner = getTotalVaultYield(target, _entries, _strict, true);

        // Start from next index in prior for loop.
        for (uint i = 1; i < vaults[_cofi].length; i++) {
            /// @dev 'getTotalVaultYield()' is more computationally efficient than
            ///      'getMeanVaultYield()' and will always result in the same 'target'.
            uint256 round = getTotalVaultYield(vaults[_cofi][i], _entries, _strict, true);
            if (round > winner) {
                winner = round;
                target = vaults[_cofi][i];
            }
        }
    }

    /**
     * @notice Evaluates median across ENABLED vaults only.
     * @notice Median is often preferred as a more reliable measure for higher yielding venues.
     *         (particularly over longer time frames).
     */
    function evaluateMedian(
        address _cofi,
        uint256 _entries,
        bool    _strict
    )   public view
        returns (address target)
    {
        require(vaults[_cofi].length > 0, 'YieldHunter: Nothing to evaluate');

        // Get the first enabled vault in the vaults array and set that as the inital target.
        uint j;
        for (uint i; i < vaults[_cofi].length; i++) {
            if (vaultInfo[vaults[_cofi][i]].enabled) {
                target = vaults[_cofi][i];
                j = i;
                break;
            }
        }
        // If no enabled vaults found.
        if (target == address(0)) {
            return target;
        }

        uint256 winner = getMedianVaultYield(target, _entries, _strict, true);

        // Start from next index in prior for loop.
        for (uint i = j + 1; i < vaults[_cofi].length; i++) {
            // Again, skip disabled vaults.
            if (!vaultInfo[vaults[_cofi][i]].enabled) {
                continue;
            }
            uint256 round = getMedianVaultYield(vaults[_cofi][i], _entries, _strict, true);
            if (round > winner) {
                winner = round;
                target = vaults[_cofi][i];
            }
        }
    }

    /**
     * @notice Includes disabled vaults - can be useful for benchmarking.
     */
    function evaluateMedianInclDisabled(
        address _cofi,
        uint256 _entries,
        bool    _strict
    )   public view
        returns (address target)
    {
        require(vaults[_cofi].length > 0, 'YieldHunter: Nothing to evaluate');

        target = vaults[_cofi][0];

        uint256 winner = getMedianVaultYield(target, _entries, _strict, true);

        // Start from next index in prior for loop.
        for (uint i = 1; i < vaults[_cofi].length; i++) {
            uint256 round = getMedianVaultYield(vaults[_cofi][i], _entries, _strict, true);
            if (round > winner) {
                winner = round;
                target = vaults[_cofi][i];
            }
        }
    }

    /**
     * @notice Returns the total vault yield over a given period.
     * @param _scaled If true, scales to 18 decimals - useful to compare assets with
     *                different decimals (e.g., DAI, USDT and USDC).
     */
    function getTotalVaultYield(
        address _vault,
        uint256 _entries,
        bool    _strict,
        bool    _scaled
    )   public view validEntries(_vault, _entries, _strict)
        returns (uint256 yieldTotal)
    {
        yieldTotal =
            vaultInfo[_vault].assets[vaultInfo[_vault].assets.length - 1] -
            vaultInfo[_vault].assets[vaultInfo[_vault].assets.length - _entries];
        if (_scaled && vaultInfo[_vault].decimals != 18) {
            yieldTotal = _scaleBy(yieldTotal, 18, vaultInfo[_vault].decimals);
        }
    }

    /**
     * @dev Assumes assets entries are "up-only". Evaluates one vault per call.
     * @param _vault   The vault to evaluate.
     * @param _entries The number of entries to evaluate starting from the most recent.
     * @param _strict  Refer to 'validEntries()' modifier.
     */
    function getMeanVaultYield(
        address _vault,
        uint256 _entries,
        bool    _strict,
        bool    _scaled
    )   public view validEntries(_vault, _entries, _strict)
        returns (uint256 yieldMean)
    {
        yieldMean = getTotalVaultYield(_vault, _entries, _strict, _scaled) / _entries;
    }

    /**
     * @notice Returns the median vault yield, where yields are intra-period values determined from
     *         the difference in assets values.
     */
    function getMedianVaultYield(
        address _vault,
        uint256 _entries,
        bool    _strict,
        bool    _scaled
    )   public view validEntries(_vault, _entries, _strict)
        returns (uint256 yieldMedian)
    {
        // Created fixed size array.
        uint256[] memory assetsDelta = new uint256[](_entries - 1);

        // Get assets delta between entries.
        uint j;
        for (uint i = vaultInfo[_vault].assets.length - 1; i > vaultInfo[_vault].assets.length - _entries; i--) {
            assetsDelta[j] = vaultInfo[_vault].assets[i] - vaultInfo[_vault].assets[i-1];
            j++;
        }
        
        // Sort in ascending order of intra-period yield accrued to find median yield.
        assetsDelta = _bubbleSort(assetsDelta);

        if (assetsDelta.length % 2 == 0) {
            yieldMedian = (assetsDelta[assetsDelta.length/2-1] + assetsDelta[assetsDelta.length/2]) / 2;
        } else {
            /// @dev Decimals round downwards. E.g., 3 / 2 = 1.5 = 1.
            yieldMedian = assetsDelta[assetsDelta.length/2];
        }

        if (_scaled && vaultInfo[_vault].decimals != 18) {
            yieldMedian = _scaleBy(yieldMedian, 18, vaultInfo[_vault].decimals);
        }
    }

    /**
     * @notice Evaluates which vault for a given cofi token is the preferred,
     *         based on the given strategy, and migrates accordingly.
     * @dev When used in Prod, this function should be called at equal time intervals
     *      (e.g., by a Chainlink automation contract).
     * @dev If you wish to capture vault readings without triggering migrations,
     *      'capture()' should be used instead.
     */
    function hunt(
        address  _cofi,
        uint256  _entries,
        bool     _strict,
        Strategy _strategy
    )   public onlyAuthorized
        returns (address target, bool migrated)
    {
        // Take fresh capture for up-to-date evaluation.
        capture(_cofi);
        
        // Execute the chosen strategy.
        if (_strategy == Strategy(0)) {
            target = evaluateMean(_cofi, _entries, _strict);
        } else if (_strategy == Strategy(1)) {
            target = evaluateMedian(_cofi, _entries, _strict);
        } else {
            revert UNKNOWN_METHOD();
        }
        
        // If the target vault is enabled and not in use, trigger migration.
        /// @dev If all vaults are disabled, will not trigger migration
        ///      (continue to use the existing vault).
        if (target != cofiMoney.getVault(_cofi) && target != address(0)) {
            cofiMoney.migrate(_cofi, target);
            return (target, true);
        }
    }

    /***************************************
                    Admin
    ****************************************/

    /**
     * Adds a vault to the list of vaults operating for a given cofi token.
     */
    function addVault(
        address _cofi,
        address _vault,
        uint256 _decimals,
        bool    _enabled
    )   external onlyAuthorized
        returns (bool)
    {
        // Need to initialise a ref point for shares to track yield over time.
        // Initialise using all existing shares for max granularity.
        vaultInfo[_vault].initSharesRef = IERC20(_vault).totalSupply();
        vaultInfo[_vault].decimals = _decimals;
        vaultInfo[_vault].enabled = _enabled;

        vaults[_cofi].push(_vault);

        return true;
    }

    /**
     * @notice Removes the given vault from the array of available vaults.
     * @dev Does not remove data relating to VaultInfo (use 'resetVault()' for this).
     * @dev If the same vault has been added twice, only removes the prior vault in the array.
     */
    function removeVault(
        address _cofi,
        address _vault
    )   external onlyAuthorized
        returns (bool)
    {
        for (uint i = 0; i < vaults[_cofi].length; i++) {
            if (vaults[_cofi][i] == _vault) {
                // Overwrite with the last element.
                vaults[_cofi][i] = vaults[_cofi][vaults[_cofi].length - 1];
                // Remove the (now duplicated) last element.
                vaults[_cofi].pop();
                return true;
            }
        }
        revert VAULT_NOT_FOUND();
    }

    function resetVault(
        address _vault
    )   external onlyAuthorized
        returns (bool)
    {
        delete vaultInfo[_vault].assets;
        delete vaultInfo[_vault].initSharesRef;
        delete vaultInfo[_vault].decimals;
        delete vaultInfo[_vault].enabled;
        return true;
    }

    /// @notice Toggles whether a vault can be migrated to or not.
    /// @dev This can be useful for benchmarking purposes/piloting a new vault.
    function toggleVaultEnabled(
        address _vault
    )   external onlyAuthorized
        returns (bool)
    {
        vaultInfo[_vault].enabled = !vaultInfo[_vault].enabled;
        return vaultInfo[_vault].enabled;
    }

    /***************************************
                    Modifiers
    ****************************************/

    modifier onlyAuthorized() {
        require(authorized[msg.sender], 'YieldHunter: Caller not authorized');
        _;
    }

    /// @notice If set to false and _entries > assets length, _entries = assets length;
    ///         if set to true and _entries > assets length, reverts.
    /// @dev Can set '_entries' to type(uint256).max for yield value since inception
    ///      (but may error if too many values).
    modifier validEntries(address _vault, uint256 _entries, bool _strict) {
        require(_entries > 1, 'YieldHunter: Nothing to compare');

        if (vaultInfo[_vault].assets.length < _entries) {
            if (_strict) {
                revert INSUFFICIENT_ENTRIES();
            }
            _entries = vaultInfo[_vault].assets.length;
        }
        _;
    }

    /***************************************
                    Helpers
    ****************************************/

    /**
     * @dev Adjust the scale of an integer
     * @param to Decimals to scale to
     * @param from Decimals to scale from
     */
    function _scaleBy(
        uint256 x,
        uint256 to,
        uint256 from
    )   internal pure
        returns (uint256)
    {
        if (to > from) {
            x = x.mul(10**(to - from));
        } else if (to < from) {
            x = x.div(10**(from - to));
        }
        return x;
    }

    /// @notice Simple sorting algo. Not suitable for large data sets.
    function _bubbleSort(
        uint[] memory arr
    )   internal pure
        returns (uint[] memory)
    {
        uint n = arr.length;
        for (uint i = 0; i < n - 1; i++) {
            for (uint j = 0; j < n - i - 1; j++) {
                if (arr[j] > arr[j + 1]) {
                    (arr[j], arr[j + 1]) = (arr[j + 1], arr[j]);
                }
            }
        }
        return arr;
    }
}