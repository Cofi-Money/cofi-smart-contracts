// LibAppStorage.sol
// struct Vault {
//     address vault;
//     uint256 allocation; // Basis points.
// }
// // E.g., coUSD => [yvUSDC, wsoUSDC]. Must share the same asset.
// mapping(address => Vault[]) vaults;

// function _poke(
//     address _cofi
// )   internal
//     returns (uint256 assets, uint256 yield, uint256 shareYield)
// {
//     AppStorage storage s = LibAppStorage.diamondStorage();

//     uint256 currentSupply = IERC20(_cofi).totalSupply();
//     if (currentSupply == 0) return (0, 0, 0); 

//     for (uint i = 0; i < s.vaults[_cofi].length; i++) {
//         // Preemptively harvest if necessary for vault.
//         if (s.harvestable[s.vaults[_cofi][i].vault] == 1)
//             LibVault._harvest(s.vaults[_cofi][i].vault);
        
//         assets += _toCofiDecimals(
//             IERC4626(s.vaults[_cofi][0].vault).asset(),
//             LibVault._totalValue(s.vaults[_cofi][i].vault)
//         );
//     }

//     if (assets > currentSupply) {

//         yield = assets - currentSupply;
//         shareYield = yield.percentMul(1e4 - s.serviceFee[_cofi]);

//         _changeSupply(
//             _cofi,
//             currentSupply + shareYield,
//             yield,
//             yield - shareYield
//         );
//         if (yield - shareYield > 0)
//             _mint(_cofi, s.feeCollector, yield - shareYield);
//     } else return (assets, 0, 0);
// }