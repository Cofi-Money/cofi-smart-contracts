# Solidity API

## ICOFIMoney

### getVault

```solidity
function getVault(address _cofi) external view returns (address)
```

### migrate

```solidity
function migrate(address _cofi, address _newVault) external returns (bool)
```

## YieldHunter

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Yield Hunter
    @notice "Hunts" the highest yields by comparing vaults of a given cofi token.
    @dev To perform the assets migration, this contract needs to be granted 'isUpkeep' role.

### vaults

```solidity
mapping(address => address[]) vaults
```

### vaultInfo

```solidity
mapping(address => struct YieldHunter.VaultInfo) vaultInfo
```

### authorized

```solidity
mapping(address => bool) authorized
```

### cofiMoney

```solidity
contract ICOFIMoney cofiMoney
```

### VaultInfo

```solidity
struct VaultInfo {
  uint256[] assets;
  uint256 initSharesRef;
  uint256 decimals;
  bool enabled;
}
```

### Strategy

```solidity
enum Strategy {
  Mean,
  Median
}
```

### VAULT_NOT_FOUND

```solidity
error VAULT_NOT_FOUND()
```

### INSUFFICIENT_ENTRIES

```solidity
error INSUFFICIENT_ENTRIES()
```

### UNKNOWN_METHOD

```solidity
error UNKNOWN_METHOD()
```

### constructor

```solidity
constructor(contract ICOFIMoney _diamond) public
```

### capture

```solidity
function capture(address _cofi) public returns (bool)
```

Captures assets from the shares ref point across all vaults, respectively.

_Need to ensure that captures are triggered over equal time intervals.
Note that 'hunt()' also triggers 'capture()', so only one of these functions should
     be called at a time. If you no longer wish to trigger migrations but continue capturing
     assets values, ensure 'capture()' picks up the established cadence, and vice versa.
     Alternatively, you could disable all vaults and continue calling 'hunt()'.
Intentionally, there is not a function to capture assets for a singular vault. This is
            to ensure that vault yield earnings are measured over equal periods._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to capture assets values across each vault for. |

### evaluateMean

```solidity
function evaluateMean(address _cofi, uint256 _entries, bool _strict) public view returns (address target)
```

Evaluates mean across ENABLED vaults only.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to evaluate which vault has the highest yield w.r.t. mean avg. |
| _entries | uint256 | The number of entries to evaluate.                 E.g., if 3 entries which are captured 24h apart:                 (start) capture entry_1 (+24h) + capture entry_2 (+24h) + capture entry_3 (finish) = 2 days.                 Therefore: _entries - 1 = period. |
| _strict | bool | See 'validEntries()' modifier. |

### evaluateMeanInclDisabled

```solidity
function evaluateMeanInclDisabled(address _cofi, uint256 _entries, bool _strict) public view returns (address target)
```

Includes disabled vaults - can be useful for benchmarking.

### evaluateMedian

```solidity
function evaluateMedian(address _cofi, uint256 _entries, bool _strict) public view returns (address target)
```

Evaluates median across ENABLED vaults only.
Median is often preferred as a more reliable measure for higher yielding venues.
        (particularly over longer time frames).

### evaluateMedianInclDisabled

```solidity
function evaluateMedianInclDisabled(address _cofi, uint256 _entries, bool _strict) public view returns (address target)
```

Includes disabled vaults - can be useful for benchmarking.

### getTotalVaultYield

```solidity
function getTotalVaultYield(address _vault, uint256 _entries, bool _strict, bool _scaled) public view returns (uint256 yieldTotal)
```

Returns the total vault yield over a given period.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _vault | address |  |
| _entries | uint256 |  |
| _strict | bool |  |
| _scaled | bool | If true, scales to 18 decimals - useful to compare assets with                different decimals (e.g., DAI, USDT and USDC). |

### getMeanVaultYield

```solidity
function getMeanVaultYield(address _vault, uint256 _entries, bool _strict, bool _scaled) public view returns (uint256 yieldMean)
```

_Assumes assets entries are "up-only". Evaluates one vault per call._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _vault | address | The vault to evaluate. |
| _entries | uint256 | The number of entries to evaluate starting from the most recent. |
| _strict | bool | Refer to 'validEntries()' modifier. |
| _scaled | bool |  |

### getMedianVaultYield

```solidity
function getMedianVaultYield(address _vault, uint256 _entries, bool _strict, bool _scaled) public view returns (uint256 yieldMedian)
```

Returns the median vault yield, where yields are intra-period values determined from
        the difference in assets values.

### hunt

```solidity
function hunt(address _cofi, uint256 _entries, bool _strict, enum YieldHunter.Strategy _strategy) public returns (address target, bool migrated)
```

Evaluates which vault for a given cofi token is the preferred,
        based on the given strategy, and migrates accordingly.

_When used in Prod, this function should be called at equal time intervals
     (e.g., by a Chainlink automation contract).
If you wish to capture vault readings without triggering migrations,
     'capture()' should be used instead._

### addVault

```solidity
function addVault(address _cofi, address _vault, uint256 _decimals, bool _enabled) external returns (bool)
```

Adds a vault to the list of vaults operating for a given cofi token.

### removeVault

```solidity
function removeVault(address _cofi, address _vault) external returns (bool)
```

Removes the given vault from the array of available vaults.

_Does not remove data relating to VaultInfo (use 'resetVault()' for this).
If the same vault has been added twice, only removes the prior vault in the array._

### resetVault

```solidity
function resetVault(address _vault) external returns (bool)
```

### toggleVaultEnabled

```solidity
function toggleVaultEnabled(address _vault) external returns (bool)
```

Toggles whether a vault can be migrated to or not.

_This can be useful for benchmarking purposes/piloting a new vault._

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

### validEntries

```solidity
modifier validEntries(address _vault, uint256 _entries, bool _strict)
```

If set to false and _entries > assets length, _entries = assets length;
        if set to true and _entries > assets length, reverts.

_Can set '_entries' to type(uint256).max for yield value since inception
     (but may error if too many values)._

### _scaleBy

```solidity
function _scaleBy(uint256 x, uint256 to, uint256 from) internal pure returns (uint256)
```

_Adjust the scale of an integer_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 |  |
| to | uint256 | Decimals to scale to |
| from | uint256 | Decimals to scale from |

### _bubbleSort

```solidity
function _bubbleSort(uint256[] arr) internal pure returns (uint256[])
```

Simple sorting algo. Not suitable for large data sets.

## IERC4626

### Deposit

```solidity
event Deposit(address caller, address owner, uint256 assets, uint256 shares)
```

### Withdraw

```solidity
event Withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
```

### asset

```solidity
function asset() external view returns (address)
```

### deposit

```solidity
function deposit(uint256 assets, address receiver) external returns (uint256 shares)
```

### harvest

```solidity
function harvest() external returns (uint256)
```

_Addition for executing harvest in the context of COFI._

### mint

```solidity
function mint(uint256 shares, address receiver) external returns (uint256 assets)
```

### withdraw

```solidity
function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares)
```

### redeem

```solidity
function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets)
```

### totalAssets

```solidity
function totalAssets() external view returns (uint256)
```

### convertToShares

```solidity
function convertToShares(uint256 assets) external view returns (uint256)
```

### convertToAssets

```solidity
function convertToAssets(uint256 shares) external view returns (uint256)
```

### previewDeposit

```solidity
function previewDeposit(uint256 assets) external view returns (uint256)
```

### previewMint

```solidity
function previewMint(uint256 shares) external view returns (uint256)
```

### previewWithdraw

```solidity
function previewWithdraw(uint256 assets) external view returns (uint256)
```

### previewRedeem

```solidity
function previewRedeem(uint256 shares) external view returns (uint256)
```

### maxDeposit

```solidity
function maxDeposit(address) external view returns (uint256)
```

### maxMint

```solidity
function maxMint(address) external view returns (uint256)
```

### maxWithdraw

```solidity
function maxWithdraw(address owner) external view returns (uint256)
```

### maxRedeem

```solidity
function maxRedeem(address owner) external view returns (uint256)
```

## CofiBridge

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Cofi Bridge
    @notice Source contract for bridging cofi tokens to a supported detination chain.
    @dev    There is a one-to-many relationship between source (bridge) and destination
            (unbridge) contracts.
    @dev    Although caller can pass fee, it is advised to maintain a small amount of
            ETH at this address to account for minor wei discrepancies.

### PayFeesIn

```solidity
enum PayFeesIn {
  Native,
  LINK
}
```

### i_link

```solidity
address i_link
```

### MessageSent

```solidity
event MessageSent(bytes32 messageId)
```

### CallSuccessful

```solidity
event CallSuccessful()
```

### InsufficientFee

```solidity
error InsufficientFee()
```

### NotAuthorizedTransmitter

```solidity
error NotAuthorizedTransmitter()
```

### mandateFee

```solidity
bool mandateFee
```

### gasLimit

```solidity
uint256 gasLimit
```

### vault

```solidity
mapping(address => contract IERC4626) vault
```

_Cofi rebasing tokens need to be wrapped before bridging, as rebasing is not
     supported cross-chain._

### destShare

```solidity
mapping(address => mapping(uint64 => address)) destShare
```

### srcAsset

```solidity
mapping(address => address) srcAsset
```

_When bridged back, indicated which cofi token to finalise the redemption for._

### receiver

```solidity
mapping(uint64 => address) receiver
```

### authorizedTransmitter

```solidity
mapping(address => bool) authorizedTransmitter
```

### authorized

```solidity
mapping(address => bool) authorized
```

### constructor

```solidity
constructor(address _router, address _link, address _cofi, address _vault, uint64 _destChainSelector, address _destShare, address _receiver) public
```

_See Chainlink CCIP docs for explanation of Router, Chain Selector, etc._

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

### receive

```solidity
receive() external payable
```

### setAuthorized

```solidity
function setAuthorized(address _account, bool _authorized) external
```

Sets whether an account has authorized status.

### setAuthorizedTransmitter

```solidity
function setAuthorizedTransmitter(address _account, bool _authorized) external
```

Indicates whether a tx originating from an account on a
        foreign chain is authorized as a correspondent transmitter.

### setVault

```solidity
function setVault(address _cofi, address _vault) external
```

Sets the ERC4626-vault for wrapping and unwrapping cofi tokens
        upon bridging and un-bridging, respectively.

### setDestShare

```solidity
function setDestShare(address _cofi, uint64 _destChainSelector, address _destShare) external
```

Sets the address of the destination share token on the foreign chain.
        E.g., coUSD => matwcoUSD.
        I.e., the foreign contract to mint destination share tokens.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address |  |
| _destChainSelector | uint64 | Chainlink chain selector for the target chain. |
| _destShare | address |  |

### setReceiver

```solidity
function setReceiver(uint64 _destChainSelector, address _receiver, bool _authorizedTransmitter) external
```

Sets the receiver contract on the destination/foreign chain ('CofiUnbridge.sol').

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _destChainSelector | uint64 |  |
| _receiver | address |  |
| _authorizedTransmitter | bool | Indicates whether the receiver contract is eligible                               to transmit txs to this contract (e.g., 'unbridge()'). |

### setMandateFee

```solidity
function setMandateFee(bool _enabled) external
```

Indicates whether the end-user is mandated to pay a fee for bridging or
        if this fee is paid from this contract's pre-existing balance.

### setGasLimit

```solidity
function setGasLimit(uint256 _gasLimit) external
```

Sets the gas limit for executing cross-chain txs.

### bridge

```solidity
function bridge(address _cofi, uint64 _destChainSelector, uint256 _amount, address _destSharesReceiver) external payable returns (uint256 shares)
```

Bridging function for cofi tokens.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to bridge (e.g., coUSD). |
| _destChainSelector | uint64 | Chainlink chain selector of the target chain. |
| _amount | uint256 | The amount of cofi tokens to bridge. |
| _destSharesReceiver | address | The account receiving share tokens on the destination chain. |

### _mint

```solidity
function _mint(uint64 _destChainSelector, address _share, address _recipient, uint256 _amount) internal
```

### getFeeETH

```solidity
function getFeeETH(address _cofi, uint64 _destChainSelector, uint256 _amount, address _destSharesReceiver) public view returns (uint256 fee)
```

Returns the estimated fee in wei required for bridging op.
Pass same args as if were doing actual bridging op.

### redeem

```solidity
function redeem(address _cofi, uint256 _shares, address _assetsReceiver) public returns (uint256 assets)
```

Receiver functions, only triggered by Chainlink router contract.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to redeem. |
| _shares | uint256 | The number of shares to redeem (e.g., wcoUSD => coUSD). |
| _assetsReceiver | address | The account receiving cofi tokens. |

### _ccipReceive

```solidity
function _ccipReceive(struct Client.Any2EVMMessage message) internal
```

Override this function in your implementation.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| message | struct Client.Any2EVMMessage | Any2EVMMessage |

### doPing

```solidity
function doPing(uint256 _ping, address _receiver, uint64 _chainSelector) external payable
```

_Tests whether a function successfully executes cross-chain without bridging tokens._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _ping | uint256 | Number should appear in receiver contract if successful. |
| _receiver | address |  |
| _chainSelector | uint64 |  |

### _doPing

```solidity
function _doPing(uint256 _ping, address _receiver, uint64 _chainSelector) internal
```

### getFeeETHPing

```solidity
function getFeeETHPing(uint256 _pong, address _receiver, uint64 _chainSelector) public view returns (uint256 fee)
```

_Fee amount is unique for each function that executes a cross-chain tx._

## CofiUnbridge

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Cofi Unbridge
    @notice Destination contract for bridging cofi tokens from a supported source chain.
            Also handles "unbridging".
    @dev    There is a many-to-one relationship between destination (unbridge) and source (bridge)
            contracts.
    @dev    Although caller can pass fee, it is advised to maintain a small amount of ETH at this
            address to account for minor wei discrepancies.

### PayFeesIn

```solidity
enum PayFeesIn {
  Native,
  LINK
}
```

### i_link

```solidity
address i_link
```

### MessageSent

```solidity
event MessageSent(bytes32 messageId)
```

### CallSuccessful

```solidity
event CallSuccessful()
```

### InsufficientFee

```solidity
error InsufficientFee()
```

### NotAuthorizedTrasnmitter

```solidity
error NotAuthorizedTrasnmitter()
```

### mandateFee

```solidity
bool mandateFee
```

### gasLimit

```solidity
uint256 gasLimit
```

### SourceAsset

```solidity
struct SourceAsset {
  address asset;
  uint64 chainSelector;
}
```

### srcAsset

```solidity
mapping(address => struct CofiUnbridge.SourceAsset) srcAsset
```

### receiver

```solidity
mapping(uint64 => address) receiver
```

### authorizedTransmitter

```solidity
mapping(address => bool) authorizedTransmitter
```

### authorized

```solidity
mapping(address => bool) authorized
```

### constructor

```solidity
constructor(address _router, address _link, address _destShare, address _srcAsset, uint64 _srcChainSelector) public
```

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

### receive

```solidity
receive() external payable
```

### setAuthorized

```solidity
function setAuthorized(address _account, bool _authorized) external
```

Sets whether an account has authorized status.

### setAuthorizedTransmitter

```solidity
function setAuthorizedTransmitter(address _account, bool _authorized) external
```

Indicates whether a tx originating from an account on a
        foreign chain is authorized as a correspondent transmitter.

### setSourceAsset

```solidity
function setSourceAsset(address _destShare, uint64 _srcChainSelector, address _srcAsset) external
```

Sets the address of the source asset for the given destination
        share (e.g., matwcoUSD => coUSD).

### setReceiver

```solidity
function setReceiver(uint64 _destChainSelector, address _receiver, bool _authorizedTransmitter) external
```

Sets the receiver contract on the destination/foreign chain ('CofiBridge.sol').

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _destChainSelector | uint64 |  |
| _receiver | address |  |
| _authorizedTransmitter | bool | Indicates whether the receiver contract is eligible                               to transmit txs to this contract (e.g., 'bridge()'). |

### setMandateFee

```solidity
function setMandateFee(bool _enabled) external
```

Indicates whether the end-user is mandated to pay a fee for bridging or
        if this fee is paid from this contract's pre-existing balance.

### setGasLimit

```solidity
function setGasLimit(uint256 _gasLimit) external
```

Sets the gas limit for executing cross-chain txs.

### unbridge

```solidity
function unbridge(address _destShare, uint256 _amount, address _srcAssetsReceiver) external payable
```

Unbridging function for cofi tokens.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _destShare | address | The (local) destination share to redeem. |
| _amount | uint256 | The amount of shares to redeem. |
| _srcAssetsReceiver | address | The account receiving assets (e.g., coUSD) on the                           destination (source) chain. |

### _burn

```solidity
function _burn(uint64 _srcChainSelector, address _asset, address _recipient, uint256 _amount) internal
```

### getFeeETH

```solidity
function getFeeETH(address _destShare, uint256 _amount, address _srcAssetReceiver) public view returns (uint256 fee)
```

### mint

```solidity
function mint(address _destShare, address _destSharesReceiver, uint256 _amount) public
```

Receiver functions, only triggered by Chainlink router contract.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _destShare | address | The destination share token to mint. |
| _destSharesReceiver | address | The account to mint to. |
| _amount | uint256 | The amount of share tokens to mint. |

### _ccipReceive

```solidity
function _ccipReceive(struct Client.Any2EVMMessage message) internal
```

Override this function in your implementation.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| message | struct Client.Any2EVMMessage | Any2EVMMessage |

### doPong

```solidity
function doPong(uint256 _pong, address _receiver, uint64 _chainSelector) external payable
```

### _doPong

```solidity
function _doPong(uint256 _pong, address _receiver, uint64 _chainSelector) internal
```

### getFeeETHPong

```solidity
function getFeeETHPong(uint256 _pong, address _receiver, uint64 _chainSelector) public view returns (uint256 fee)
```

## Withdraw

THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
DO NOT USE THIS CODE IN PRODUCTION.

### FailedToWithdrawEth

```solidity
error FailedToWithdrawEth(address owner, address target, uint256 value)
```

### withdraw

```solidity
function withdraw(address beneficiary) public
```

### withdrawToken

```solidity
function withdrawToken(address beneficiary, address token) public
```

## ERC20Token

### constructor

```solidity
constructor(string _name, string _symbol, uint8 decimals_) public
```

### mint

```solidity
function mint(address _to, uint256 _amount) external
```

### burn

```solidity
function burn(address _from, uint256 _amount) external
```

### decimals

```solidity
function decimals() public view returns (uint8)
```

_Returns the number of decimals used to get its user representation.
For example, if `decimals` equals `2`, a balance of `505` tokens should
be displayed to a user as `5.05` (`505 / 10 ** 2`).

Tokens usually opt for a value of 18, imitating the relationship between
Ether and Wei. This is the default value returned by this function, unless
it's overridden.

NOTE: This information is only used for _display_ purposes: it in
no way affects any of the arithmetic of the contract, including
{IERC20-balanceOf} and {IERC20-transfer}._

## IDiamondCut

### FacetCutAction

```solidity
enum FacetCutAction {
  Add,
  Replace,
  Remove
}
```

### FacetCut

```solidity
struct FacetCut {
  address facetAddress;
  enum IDiamondCut.FacetCutAction action;
  bytes4[] functionSelectors;
}
```

### diamondCut

```solidity
function diamondCut(struct IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata) external
```

Add/replace/remove any number of functions and optionally execute
        a function with delegatecall

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _diamondCut | struct IDiamondCut.FacetCut[] | Contains the facet addresses and function selectors |
| _init | address | The address of the contract or facet to execute _calldata |
| _calldata | bytes | A function call, including function selector and arguments                  _calldata is executed with delegatecall on _init |

### DiamondCut

```solidity
event DiamondCut(struct IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata)
```

## InitializationFunctionReverted

```solidity
error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata)
```

## LibDiamond

### DIAMOND_STORAGE_POSITION

```solidity
bytes32 DIAMOND_STORAGE_POSITION
```

### FacetAddressAndPosition

```solidity
struct FacetAddressAndPosition {
  address facetAddress;
  uint96 functionSelectorPosition;
}
```

### FacetFunctionSelectors

```solidity
struct FacetFunctionSelectors {
  bytes4[] functionSelectors;
  uint256 facetAddressPosition;
}
```

### DiamondStorage

```solidity
struct DiamondStorage {
  mapping(bytes4 => struct LibDiamond.FacetAddressAndPosition) selectorToFacetAndPosition;
  mapping(address => struct LibDiamond.FacetFunctionSelectors) facetFunctionSelectors;
  address[] facetAddresses;
  mapping(uint256 => bytes32) selectorSlots;
  uint16 selectorCount;
  mapping(bytes4 => bool) supportedInterfaces;
  address contractOwner;
}
```

### diamondStorage

```solidity
function diamondStorage() internal pure returns (struct LibDiamond.DiamondStorage ds)
```

### OwnershipTransferred

```solidity
event OwnershipTransferred(address previousOwner, address newOwner)
```

### setContractOwner

```solidity
function setContractOwner(address _newOwner) internal
```

### contractOwner

```solidity
function contractOwner() internal view returns (address contractOwner_)
```

### enforceIsContractOwner

```solidity
function enforceIsContractOwner() internal view
```

### DiamondCut

```solidity
event DiamondCut(struct IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata)
```

### diamondCut

```solidity
function diamondCut(struct IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata) internal
```

### addFunctions

```solidity
function addFunctions(address _facetAddress, bytes4[] _functionSelectors) internal
```

### replaceFunctions

```solidity
function replaceFunctions(address _facetAddress, bytes4[] _functionSelectors) internal
```

### removeFunctions

```solidity
function removeFunctions(address _facetAddress, bytes4[] _functionSelectors) internal
```

### addFacet

```solidity
function addFacet(struct LibDiamond.DiamondStorage ds, address _facetAddress) internal
```

### addFunction

```solidity
function addFunction(struct LibDiamond.DiamondStorage ds, bytes4 _selector, uint96 _selectorPosition, address _facetAddress) internal
```

### removeFunction

```solidity
function removeFunction(struct LibDiamond.DiamondStorage ds, address _facetAddress, bytes4 _selector) internal
```

### initializeDiamondCut

```solidity
function initializeDiamondCut(address _init, bytes _calldata) internal
```

### enforceHasContractCode

```solidity
function enforceHasContractCode(address _contract, string _errorMessage) internal view
```

## VaultManagerFacet

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Vault Manager Facet
    @notice Provides logic for managing vaults and distributing yield.

### rebase

```solidity
function rebase(address _cofi) external returns (uint256 assets, uint256 yield, uint256 shareYield)
```

Syncs cofi token supply to reflect vault earnings.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to distribute yield earnings for. |

### migrate

```solidity
function migrate(address _cofi, address _newVault) external returns (bool)
```

Migrates assets to '_newVault'.

_Ensure that a buffer of the relevant underlying token resides at this contract
     before executing to account for slippage._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to migrate underlying tokens for. |
| _newVault | address | The new ERC4626 vault. |

### setBuffer

```solidity
function setBuffer(address _underlying, uint256 _buffer) external returns (bool)
```

_The buffer is an amount of underlying that resides at this contract for the purpose
     of ensuring a successful migration. This is because a rebase must execute to "sync"
     balances, which can only occur if the new supply is greater than the previous supply.
     Because withdrawals may incur slippage, therefore, need to overcome this._

### setMigrationEnabled

```solidity
function setMigrationEnabled(address _vaultA, address _vaultB, uint8 _enabled) external returns (bool)
```

### setVault

```solidity
function setVault(address _cofi, address _vault) external returns (bool)
```

_Only for setting up a new cofi token. 'migrateVault()' must be used otherwise._

### setRateLimit

```solidity
function setRateLimit(address _cofi, uint256 _rateLimit) external returns (bool)
```

### setRebasePublic

```solidity
function setRebasePublic(address _cofi, uint8 _enabled) external returns (bool)
```

### setHarvestable

```solidity
function setHarvestable(address _vault, uint8 _enabled) external returns (bool)
```

### rebaseOptIn

```solidity
function rebaseOptIn(address _cofi) external returns (bool)
```

Ops this contract into receiving yield on holding of cofi tokens.

### rebaseOptOut

```solidity
function rebaseOptOut(address _cofi) external returns (bool)
```

### getTotalAssets

```solidity
function getTotalAssets(address _cofi) external view returns (uint256 assets)
```

Returns the total assets held within the vault for a given cofi token.
         This value should therefore closely mirror the cofi token's total supply.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to enquire for. |

### getVault

```solidity
function getVault(address _cofi) external view returns (address vault)
```

### getRateLimit

```solidity
function getRateLimit(address _cofi) external view returns (uint256)
```

### getBuffer

```solidity
function getBuffer(address _underlying) external view returns (uint256)
```

Returns the 'buffer' for an underlying, which is an amount of tokens that
         resides at this contract for the purpose of executing migrations.
         This is because the new cofi token supply must "sync" to the new assets by
         rebasing, which can only occur if there are more assets than previously captured.

### getRebasePublic

```solidity
function getRebasePublic(address _cofi) external view returns (uint8)
```

Indicates if rebases can be called by any account for a given cofi token.

### getHarvestable

```solidity
function getHarvestable(address _vault) external view returns (uint8)
```

Indicates if the vault has a 'harvest()' function, which executes some action
         (e.g., reinvest staking rewards) prior to rebasing.

## ICOFIToken

Interface for executing functions on cofi rebasing tokens.

### mint

```solidity
function mint(address _account, uint256 _amount) external
```

### mintOptIn

```solidity
function mintOptIn(address _account, uint256 _amount) external
```

### burn

```solidity
function burn(address _account, uint256 _amount) external
```

### redeem

```solidity
function redeem(address _from, address _to, uint256 _value) external returns (bool)
```

### lock

```solidity
function lock(address _account, uint256 _amount) external returns (bool)
```

### unlock

```solidity
function unlock(address _account, uint256 _amount) external returns (bool)
```

### changeSupply

```solidity
function changeSupply(uint256 _newTotalSupply) external
```

### freeBalanceOf

```solidity
function freeBalanceOf(address _account) external view returns (uint256)
```

### getYieldEarned

```solidity
function getYieldEarned(address _account) external view returns (uint256)
```

### rebasingCreditsPerTokenHighres

```solidity
function rebasingCreditsPerTokenHighres() external view returns (uint256)
```

### creditsToBal

```solidity
function creditsToBal(uint256 _amount) external view returns (uint256)
```

### rebaseOptIn

```solidity
function rebaseOptIn() external
```

### rebaseOptOut

```solidity
function rebaseOptOut() external
```

## IRouter

### Route

```solidity
struct Route {
  address from;
  address to;
  bool stable;
  address factory;
}
```

### ConversionFromV2ToV1VeloProhibited

```solidity
error ConversionFromV2ToV1VeloProhibited()
```

### ETHTransferFailed

```solidity
error ETHTransferFailed()
```

### Expired

```solidity
error Expired()
```

### InsufficientAmount

```solidity
error InsufficientAmount()
```

### InsufficientAmountA

```solidity
error InsufficientAmountA()
```

### InsufficientAmountB

```solidity
error InsufficientAmountB()
```

### InsufficientAmountADesired

```solidity
error InsufficientAmountADesired()
```

### InsufficientAmountBDesired

```solidity
error InsufficientAmountBDesired()
```

### InsufficientAmountAOptimal

```solidity
error InsufficientAmountAOptimal()
```

### InsufficientLiquidity

```solidity
error InsufficientLiquidity()
```

### InsufficientOutputAmount

```solidity
error InsufficientOutputAmount()
```

### InvalidAmountInForETHDeposit

```solidity
error InvalidAmountInForETHDeposit()
```

### InvalidTokenInForETHDeposit

```solidity
error InvalidTokenInForETHDeposit()
```

### InvalidPath

```solidity
error InvalidPath()
```

### InvalidRouteA

```solidity
error InvalidRouteA()
```

### InvalidRouteB

```solidity
error InvalidRouteB()
```

### OnlyWETH

```solidity
error OnlyWETH()
```

### PoolDoesNotExist

```solidity
error PoolDoesNotExist()
```

### PoolFactoryDoesNotExist

```solidity
error PoolFactoryDoesNotExist()
```

### SameAddresses

```solidity
error SameAddresses()
```

### ZeroAddress

```solidity
error ZeroAddress()
```

### factoryRegistry

```solidity
function factoryRegistry() external view returns (address)
```

Address of FactoryRegistry.sol

### v1Factory

```solidity
function v1Factory() external view returns (address)
```

Address of Velodrome v1 PairFactory.sol

### defaultFactory

```solidity
function defaultFactory() external view returns (address)
```

Address of Velodrome v2 PoolFactory.sol

### voter

```solidity
function voter() external view returns (address)
```

Address of Voter.sol

### weth

```solidity
function weth() external view returns (contract IWETH)
```

Interface of WETH contract used for WETH => ETH wrapping/unwrapping

### ETHER

```solidity
function ETHER() external view returns (address)
```

_Represents Ether. Used by zapper to determine whether to return assets as ETH/WETH._

### Zap

_Struct containing information necessary to zap in and out of pools_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |

```solidity
struct Zap {
  address tokenA;
  address tokenB;
  bool stable;
  address factory;
  uint256 amountOutMinA;
  uint256 amountOutMinB;
  uint256 amountAMin;
  uint256 amountBMin;
}
```

### sortTokens

```solidity
function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1)
```

Sort two tokens by which address value is less than the other

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenA | address | Address of token to sort |
| tokenB | address | Address of token to sort |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| token0 | address | Lower address value between tokenA and tokenB |
| token1 | address | Higher address value between tokenA and tokenB |

### poolFor

```solidity
function poolFor(address tokenA, address tokenB, bool stable, address _factory) external view returns (address pool)
```

Calculate the address of a pool by its' factory.
        Used by all Router functions containing a `Route[]` or `_factory` argument.
        Reverts if _factory is not approved by the FactoryRegistry

_Returns a randomly generated address for a nonexistent pool_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenA | address | Address of token to query |
| tokenB | address | Address of token to query |
| stable | bool | True if pool is stable, false if volatile |
| _factory | address | Address of factory which created the pool |

### pairFor

```solidity
function pairFor(address tokenA, address tokenB, bool stable, address _factory) external view returns (address pool)
```

Wraps around poolFor(tokenA,tokenB,stable,_factory) for backwards compatibility to Velodrome v1

### getReserves

```solidity
function getReserves(address tokenA, address tokenB, bool stable, address _factory) external view returns (uint256 reserveA, uint256 reserveB)
```

Fetch and sort the reserves for a pool

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenA | address | . |
| tokenB | address | . |
| stable | bool | True if pool is stable, false if volatile |
| _factory | address | Address of PoolFactory for tokenA and tokenB |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| reserveA | uint256 | Amount of reserves of the sorted token A |
| reserveB | uint256 | Amount of reserves of the sorted token B |

### getAmountsOut

```solidity
function getAmountsOut(uint256 amountIn, struct IRouter.Route[] routes) external view returns (uint256[] amounts)
```

Perform chained getAmountOut calculations on any number of pools

### quoteAddLiquidity

```solidity
function quoteAddLiquidity(address tokenA, address tokenB, bool stable, address _factory, uint256 amountADesired, uint256 amountBDesired) external view returns (uint256 amountA, uint256 amountB, uint256 liquidity)
```

Quote the amount deposited into a Pool

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenA | address | . |
| tokenB | address | . |
| stable | bool | True if pool is stable, false if volatile |
| _factory | address | Address of PoolFactory for tokenA and tokenB |
| amountADesired | uint256 | Amount of tokenA desired to deposit |
| amountBDesired | uint256 | Amount of tokenB desired to deposit |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountA | uint256 | Amount of tokenA to actually deposit |
| amountB | uint256 | Amount of tokenB to actually deposit |
| liquidity | uint256 | Amount of liquidity token returned from deposit |

### quoteRemoveLiquidity

```solidity
function quoteRemoveLiquidity(address tokenA, address tokenB, bool stable, address _factory, uint256 liquidity) external view returns (uint256 amountA, uint256 amountB)
```

Quote the amount of liquidity removed from a Pool

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenA | address | . |
| tokenB | address | . |
| stable | bool | True if pool is stable, false if volatile |
| _factory | address | Address of PoolFactory for tokenA and tokenB |
| liquidity | uint256 | Amount of liquidity to remove |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountA | uint256 | Amount of tokenA received |
| amountB | uint256 | Amount of tokenB received |

### addLiquidity

```solidity
function addLiquidity(address tokenA, address tokenB, bool stable, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) external returns (uint256 amountA, uint256 amountB, uint256 liquidity)
```

Add liquidity of two tokens to a Pool

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenA | address | . |
| tokenB | address | . |
| stable | bool | True if pool is stable, false if volatile |
| amountADesired | uint256 | Amount of tokenA desired to deposit |
| amountBDesired | uint256 | Amount of tokenB desired to deposit |
| amountAMin | uint256 | Minimum amount of tokenA to deposit |
| amountBMin | uint256 | Minimum amount of tokenB to deposit |
| to | address | Recipient of liquidity token |
| deadline | uint256 | Deadline to receive liquidity |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountA | uint256 | Amount of tokenA to actually deposit |
| amountB | uint256 | Amount of tokenB to actually deposit |
| liquidity | uint256 | Amount of liquidity token returned from deposit |

### addLiquidityETH

```solidity
function addLiquidityETH(address token, bool stable, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
```

Add liquidity of a token and WETH (transferred as ETH) to a Pool

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| token | address | . |
| stable | bool | True if pool is stable, false if volatile |
| amountTokenDesired | uint256 | Amount of token desired to deposit |
| amountTokenMin | uint256 | Minimum amount of token to deposit |
| amountETHMin | uint256 | Minimum amount of ETH to deposit |
| to | address | Recipient of liquidity token |
| deadline | uint256 | Deadline to add liquidity |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountToken | uint256 | Amount of token to actually deposit |
| amountETH | uint256 | Amount of tokenETH to actually deposit |
| liquidity | uint256 | Amount of liquidity token returned from deposit |

### removeLiquidity

```solidity
function removeLiquidity(address tokenA, address tokenB, bool stable, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) external returns (uint256 amountA, uint256 amountB)
```

Remove liquidity of two tokens from a Pool

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenA | address | . |
| tokenB | address | . |
| stable | bool | True if pool is stable, false if volatile |
| liquidity | uint256 | Amount of liquidity to remove |
| amountAMin | uint256 | Minimum amount of tokenA to receive |
| amountBMin | uint256 | Minimum amount of tokenB to receive |
| to | address | Recipient of tokens received |
| deadline | uint256 | Deadline to remove liquidity |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountA | uint256 | Amount of tokenA received |
| amountB | uint256 | Amount of tokenB received |

### removeLiquidityETH

```solidity
function removeLiquidityETH(address token, bool stable, uint256 liquidity, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) external returns (uint256 amountToken, uint256 amountETH)
```

Remove liquidity of a token and WETH (returned as ETH) from a Pool

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| token | address | . |
| stable | bool | True if pool is stable, false if volatile |
| liquidity | uint256 | Amount of liquidity to remove |
| amountTokenMin | uint256 | Minimum amount of token to receive |
| amountETHMin | uint256 | Minimum amount of ETH to receive |
| to | address | Recipient of liquidity token |
| deadline | uint256 | Deadline to receive liquidity |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountToken | uint256 | Amount of token received |
| amountETH | uint256 | Amount of ETH received |

### removeLiquidityETHSupportingFeeOnTransferTokens

```solidity
function removeLiquidityETHSupportingFeeOnTransferTokens(address token, bool stable, uint256 liquidity, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) external returns (uint256 amountETH)
```

Remove liquidity of a fee-on-transfer token and WETH (returned as ETH) from a Pool

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| token | address | . |
| stable | bool | True if pool is stable, false if volatile |
| liquidity | uint256 | Amount of liquidity to remove |
| amountTokenMin | uint256 | Minimum amount of token to receive |
| amountETHMin | uint256 | Minimum amount of ETH to receive |
| to | address | Recipient of liquidity token |
| deadline | uint256 | Deadline to receive liquidity |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountETH | uint256 | Amount of ETH received |

### swapExactTokensForTokens

```solidity
function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, struct IRouter.Route[] routes, address to, uint256 deadline) external returns (uint256[] amounts)
```

Swap one token for another

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountIn | uint256 | Amount of token in |
| amountOutMin | uint256 | Minimum amount of desired token received |
| routes | struct IRouter.Route[] | Array of trade routes used in the swap |
| to | address | Recipient of the tokens received |
| deadline | uint256 | Deadline to receive tokens |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amounts | uint256[] | Array of amounts returned per route |

### swapExactETHForTokens

```solidity
function swapExactETHForTokens(uint256 amountOutMin, struct IRouter.Route[] routes, address to, uint256 deadline) external payable returns (uint256[] amounts)
```

Swap ETH for a token

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountOutMin | uint256 | Minimum amount of desired token received |
| routes | struct IRouter.Route[] | Array of trade routes used in the swap |
| to | address | Recipient of the tokens received |
| deadline | uint256 | Deadline to receive tokens |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amounts | uint256[] | Array of amounts returned per route |

### swapExactTokensForETH

```solidity
function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, struct IRouter.Route[] routes, address to, uint256 deadline) external returns (uint256[] amounts)
```

Swap a token for WETH (returned as ETH)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountIn | uint256 | Amount of token in |
| amountOutMin | uint256 | Minimum amount of desired ETH |
| routes | struct IRouter.Route[] | Array of trade routes used in the swap |
| to | address | Recipient of the tokens received |
| deadline | uint256 | Deadline to receive tokens |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amounts | uint256[] | Array of amounts returned per route |

### UNSAFE_swapExactTokensForTokens

```solidity
function UNSAFE_swapExactTokensForTokens(uint256[] amounts, struct IRouter.Route[] routes, address to, uint256 deadline) external returns (uint256[])
```

Swap one token for another without slippage protection

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amounts | uint256[] |  |
| routes | struct IRouter.Route[] | Array of trade routes used in the swap |
| to | address | Recipient of the tokens received |
| deadline | uint256 | Deadline to receive tokens |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256[] | amounts     Array of amounts to swap  per route |

### swapExactTokensForTokensSupportingFeeOnTransferTokens

```solidity
function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, struct IRouter.Route[] routes, address to, uint256 deadline) external
```

Swap one token for another supporting fee-on-transfer tokens

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountIn | uint256 | Amount of token in |
| amountOutMin | uint256 | Minimum amount of desired token received |
| routes | struct IRouter.Route[] | Array of trade routes used in the swap |
| to | address | Recipient of the tokens received |
| deadline | uint256 | Deadline to receive tokens |

### swapExactETHForTokensSupportingFeeOnTransferTokens

```solidity
function swapExactETHForTokensSupportingFeeOnTransferTokens(uint256 amountOutMin, struct IRouter.Route[] routes, address to, uint256 deadline) external payable
```

Swap ETH for a token supporting fee-on-transfer tokens

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountOutMin | uint256 | Minimum amount of desired token received |
| routes | struct IRouter.Route[] | Array of trade routes used in the swap |
| to | address | Recipient of the tokens received |
| deadline | uint256 | Deadline to receive tokens |

### swapExactTokensForETHSupportingFeeOnTransferTokens

```solidity
function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, struct IRouter.Route[] routes, address to, uint256 deadline) external
```

Swap a token for WETH (returned as ETH) supporting fee-on-transfer tokens

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountIn | uint256 | Amount of token in |
| amountOutMin | uint256 | Minimum amount of desired ETH |
| routes | struct IRouter.Route[] | Array of trade routes used in the swap |
| to | address | Recipient of the tokens received |
| deadline | uint256 | Deadline to receive tokens |

### zapIn

```solidity
function zapIn(address tokenIn, uint256 amountInA, uint256 amountInB, struct IRouter.Zap zapInPool, struct IRouter.Route[] routesA, struct IRouter.Route[] routesB, address to, bool stake) external payable returns (uint256 liquidity)
```

Zap a token A into a pool (B, C). (A can be equal to B or C).
        Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
        Slippage is required for the initial swap.
        Additional slippage may be required when adding liquidity as the
        price of the token may have changed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenIn | address | Token you are zapping in from (i.e. input token). |
| amountInA | uint256 | Amount of input token you wish to send down routesA |
| amountInB | uint256 | Amount of input token you wish to send down routesB |
| zapInPool | struct IRouter.Zap | Contains zap struct information. See Zap struct. |
| routesA | struct IRouter.Route[] | Route used to convert input token to tokenA |
| routesB | struct IRouter.Route[] | Route used to convert input token to tokenB |
| to | address | Address you wish to mint liquidity to. |
| stake | bool | Auto-stake liquidity in corresponding gauge. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| liquidity | uint256 | Amount of LP tokens created from zapping in. |

### zapOut

```solidity
function zapOut(address tokenOut, uint256 liquidity, struct IRouter.Zap zapOutPool, struct IRouter.Route[] routesA, struct IRouter.Route[] routesB) external
```

Zap out a pool (B, C) into A.
        Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
        Slippage is required for the removal of liquidity.
        Additional slippage may be required on the swap as the
        price of the token may have changed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenOut | address | Token you are zapping out to (i.e. output token). |
| liquidity | uint256 | Amount of liquidity you wish to remove. |
| zapOutPool | struct IRouter.Zap | Contains zap struct information. See Zap struct. |
| routesA | struct IRouter.Route[] | Route used to convert tokenA into output token. |
| routesB | struct IRouter.Route[] | Route used to convert tokenB into output token. |

### generateZapInParams

```solidity
function generateZapInParams(address tokenA, address tokenB, bool stable, address _factory, uint256 amountInA, uint256 amountInB, struct IRouter.Route[] routesA, struct IRouter.Route[] routesB) external view returns (uint256 amountOutMinA, uint256 amountOutMinB, uint256 amountAMin, uint256 amountBMin)
```

Used to generate params required for zapping in.
        Zap in => remove liquidity then swap.
        Apply slippage to expected swap values to account for changes in reserves in between.

_Output token refers to the token you want to zap in from._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenA | address | . |
| tokenB | address | . |
| stable | bool | . |
| _factory | address | . |
| amountInA | uint256 | Amount of input token you wish to send down routesA |
| amountInB | uint256 | Amount of input token you wish to send down routesB |
| routesA | struct IRouter.Route[] | Route used to convert input token to tokenA |
| routesB | struct IRouter.Route[] | Route used to convert input token to tokenB |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountOutMinA | uint256 | Minimum output expected from swapping input token to tokenA. |
| amountOutMinB | uint256 | Minimum output expected from swapping input token to tokenB. |
| amountAMin | uint256 | Minimum amount of tokenA expected from depositing liquidity. |
| amountBMin | uint256 | Minimum amount of tokenB expected from depositing liquidity. |

### generateZapOutParams

```solidity
function generateZapOutParams(address tokenA, address tokenB, bool stable, address _factory, uint256 liquidity, struct IRouter.Route[] routesA, struct IRouter.Route[] routesB) external view returns (uint256 amountOutMinA, uint256 amountOutMinB, uint256 amountAMin, uint256 amountBMin)
```

Used to generate params required for zapping out.
        Zap out => swap then add liquidity.
        Apply slippage to expected liquidity values to account for changes in reserves in between.

_Output token refers to the token you want to zap out of._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenA | address | . |
| tokenB | address | . |
| stable | bool | . |
| _factory | address | . |
| liquidity | uint256 | Amount of liquidity being zapped out of into a given output token. |
| routesA | struct IRouter.Route[] | Route used to convert tokenA into output token. |
| routesB | struct IRouter.Route[] | Route used to convert tokenB into output token. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountOutMinA | uint256 | Minimum output expected from swapping tokenA into output token. |
| amountOutMinB | uint256 | Minimum output expected from swapping tokenB into output token. |
| amountAMin | uint256 | Minimum amount of tokenA expected from withdrawing liquidity. |
| amountBMin | uint256 | Minimum amount of tokenB expected from withdrawing liquidity. |

### quoteStableLiquidityRatio

```solidity
function quoteStableLiquidityRatio(address tokenA, address tokenB, address factory) external view returns (uint256 ratio)
```

Used by zapper to determine appropriate ratio of A to B to deposit liquidity. Assumes stable pool.

_Returns stable liquidity ratio of B to (A + B).
     E.g. if ratio is 0.4, it means there is more of A than there is of B.
     Therefore you should deposit more of token A than B._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenA | address | tokenA of stable pool you are zapping into. |
| tokenB | address | tokenB of stable pool you are zapping into. |
| factory | address | Factory that created stable pool. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| ratio | uint256 | Ratio of token0 to token1 required to deposit into zap. |

## IWETH

### deposit

```solidity
function deposit() external payable
```

### withdraw

```solidity
function withdraw(uint256) external
```

## YieldPointsCapture

```solidity
struct YieldPointsCapture {
  uint256 yield;
  uint256 points;
}
```

## RewardStatus

```solidity
struct RewardStatus {
  uint8 initClaimed;
  uint8 referClaimed;
  uint8 referDisabled;
}
```

## SwapProtocol

```solidity
enum SwapProtocol {
  NonExistent,
  SwapV2,
  SwapV3
}
```

## SwapRouteV2

```solidity
struct SwapRouteV2 {
  address mid;
  bool[2] stable;
}
```

## SwapInfo

```solidity
struct SwapInfo {
  uint256 slippage;
  uint256 wait;
}
```

## AppStorage

```solidity
struct AppStorage {
  mapping(address => uint256) minDeposit;
  mapping(address => uint256) minWithdraw;
  mapping(address => uint256) mintFee;
  mapping(address => uint256) redeemFee;
  mapping(address => uint256) serviceFee;
  mapping(address => uint256) pointsRate;
  mapping(address => uint256) buffer;
  mapping(address => uint256) supplyLimit;
  mapping(address => uint256) rateLimit;
  mapping(address => address) vault;
  mapping(address => uint8) mintEnabled;
  mapping(address => uint8) redeemEnabled;
  mapping(address => uint8) decimals;
  mapping(address => uint8) rebasePublic;
  mapping(address => uint8) harvestable;
  uint256 initReward;
  uint256 referReward;
  mapping(address => struct RewardStatus) rewardStatus;
  mapping(address => mapping(address => struct YieldPointsCapture)) YPC;
  mapping(address => uint256) XPC;
  mapping(address => uint8) isWhitelisted;
  mapping(address => uint8) isWhitelister;
  mapping(address => uint8) isAdmin;
  mapping(address => uint8) isUpkeep;
  address feeCollector;
  address owner;
  address backupOwner;
  uint8 reentrantStatus;
  mapping(address => mapping(address => enum SwapProtocol)) swapProtocol;
  mapping(address => mapping(address => struct SwapRouteV2)) swapRouteV2;
  mapping(address => mapping(address => bytes)) swapRouteV3;
  mapping(address => mapping(address => struct SwapInfo)) swapInfo;
  mapping(address => address[]) supportedSwaps;
  mapping(address => address) priceFeed;
  mapping(address => mapping(address => uint8)) migrationEnabled;
  uint256 defaultSlippage;
  uint256 defaultWait;
}
```

## LibAppStorage

### diamondStorage

```solidity
function diamondStorage() internal pure returns (struct AppStorage ds)
```

### abs

```solidity
function abs(int256 x_) internal pure returns (uint256)
```

## Modifiers

### s

```solidity
struct AppStorage s
```

### isWhitelisted

```solidity
modifier isWhitelisted()
```

### minDeposit

```solidity
modifier minDeposit(uint256 _amount, address _cofi)
```

### minWithdraw

```solidity
modifier minWithdraw(uint256 _amount, address _cofi)
```

### mintEnabled

```solidity
modifier mintEnabled(address _cofi)
```

### redeemEnabled

```solidity
modifier redeemEnabled(address _cofi)
```

### onlyOwner

```solidity
modifier onlyOwner()
```

### onlyAdmin

```solidity
modifier onlyAdmin()
```

### onlyUpkeepOrAdmin

```solidity
modifier onlyUpkeepOrAdmin()
```

### onlyWhitelister

```solidity
modifier onlyWhitelister()
```

### nonReentrant

```solidity
modifier nonReentrant()
```

## LibReward

### RewardDistributed

```solidity
event RewardDistributed(address account, uint256 points)
```

Emitted when external points are distributed (not tied to yield).

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| account | address | The recipient of the points. |
| points | uint256 | The amount of points distributed. |

### Referral

```solidity
event Referral(address referral, address account, uint256 points)
```

Emitted when a referral is executed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| referral | address | The referral account. |
| account | address | The account using the referral. |
| points | uint256 | The amount of points distributed to the referral account. |

### _reward

```solidity
function _reward(address _account, uint256 _points) internal
```

Distributes points not tied to yield.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The account receiving points. |
| _points | uint256 | The amount of points distributed. |

### _initReward

```solidity
function _initReward() internal
```

Reward distributed for each new first deposit.

### _referReward

```solidity
function _referReward(address _referral) internal
```

Reward distributed for each referral.

## LibSwap

### Swap

```solidity
event Swap(address from, address to, uint256 amountIn, uint256 amountOut, address recipient)
```

Emitted when a swap operation is executed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| from | address | The asset being swapped. |
| to | address | The asset being received. |
| amountIn | uint256 | The amount of 'from' assets being swapped. |
| amountOut | uint256 | The amount of 'to' assets received. |
| recipient | address | The account receiving 'to' assets. (For system entry, will always be this contract, and for exit, user). |

### WETH

```solidity
contract IWETH WETH
```

### _swapERC20ForERC20

```solidity
function _swapERC20ForERC20(uint256 _amountIn, address _from, address _to, address _recipient) internal returns (uint256 amountOut)
```

_Swaps from this contract (not '_depositFrom')._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _amountIn | uint256 | The amount of '_from' token to swap. |
| _from | address | The token to swap. |
| _to | address | The token to receive. |
| _recipient | address |  |

### _swapETHForERC20

```solidity
function _swapETHForERC20(address _to) internal returns (uint256 amountOut)
```

_Used for entering the app ONLY, therefore recipient is this address.
Swaps ETH directly from msg.sender (not this contract)._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _to | address | The token to receive. |

### _swapERC20ForETH

```solidity
function _swapERC20ForETH(uint256 _amountIn, address _from, address _recipient) internal returns (uint256 amountOut)
```

_Used for exiting the app ONLY, therefore recipient of swap operation is user._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _amountIn | uint256 | The amount of '_from' token to swap. |
| _from | address | The token to swap. |
| _recipient | address | The receiver of ETH. |

### _getAmountOutMin

```solidity
function _getAmountOutMin(uint256 _amountIn, address _from, address _to) internal view returns (uint256 amountOutMin)
```

Computes 'amountOutMin' by retrieving prices of '_from' and '_to' assets and applying slippage.

_If a custom value for slippage is not set for the '_from', '_to' mapping, will use default._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _amountIn | uint256 | The amount of '_from' tokens to swap. |
| _from | address | The asset to swap (e.g., wETH). |
| _to | address | The asset to receive (e.g., USDC). |

### _getConversion

```solidity
function _getConversion(uint256 _amount, uint256 _fee, address _from, address _to) internal view returns (uint256 fromTo)
```

_Similar to '_getAmountOutMin()' however takes into account a custom deducation amount 'fee' in basis points._

### _getFromToLatestPrice

```solidity
function _getFromToLatestPrice(address _from, address _to) internal view returns (uint256 fromTo)
```

Retrieves latest price of '_from' and '_to' assets from respective Chainlink price oracle.

_Return values adjusted to 8 decimals (e.g., $1.00 = 1(.)00_000_000)._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _from | address | The asset to enquire price for. |
| _to | address | The asset to denominate price in. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| fromTo | uint256 | The '_from' asset price denominated in '_to' asset. |

### _getLatestPrice

```solidity
function _getLatestPrice(address _asset) internal view returns (uint256 price)
```

Retrieves latest price of '_asset' from Chainlink price oracle.

## LibToken

### Transfer

```solidity
event Transfer(address asset, uint256 amount, address transferFrom, address recipient)
```

Emitted when a transfer operation is executed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The asset transferred (underlying, share, or cofi token). |
| amount | uint256 | The amount transferred. |
| transferFrom | address | The account that assets were transferred from. |
| recipient | address | The account that received assets. |

### Mint

```solidity
event Mint(address cofi, uint256 amount, address to)
```

Emitted when a cofi token is minted.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| cofi | address | The cofi token minted. |
| amount | uint256 | The amount minted. |
| to | address | The account cofi tokens were minted to. |

### Burn

```solidity
event Burn(address cofi, uint256 amount, address from)
```

Emitted when a cofi token is burned.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| cofi | address | The cofi token burned. |
| amount | uint256 | The amount burned. |
| from | address | The account cofi tokens were burned from. |

### TotalSupplyUpdated

```solidity
event TotalSupplyUpdated(address cofi, uint256 assets, uint256 yield, uint256 rCPT, uint256 fee)
```

Emitted when the total supply of a cofi token is updated.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| cofi | address | The cofi token with updated supply. |
| assets | uint256 | The new total supply. |
| yield | uint256 | The amount of supply added. |
| rCPT | uint256 | The new value for rebasing credits per token (used to calc interest rates). |
| fee | uint256 | The service fee captured (a share of the yield). |

### Deposit

```solidity
event Deposit(address asset, uint256 amount, address depositFrom, uint256 fee)
```

Emitted when a deposit action is executed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The asset deposited (e.g., USDC). |
| amount | uint256 | The amount deposited. |
| depositFrom | address | The account assets were deposited from. |
| fee | uint256 | The mint fee captured. |

### Withdraw

```solidity
event Withdraw(address asset, uint256 amount, address depositFrom, uint256 fee)
```

Emitted when a withdrawal action is executed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The asset being withdrawn (e.g., USDC). |
| amount | uint256 | The amount withdrawn. |
| depositFrom | address | The account cofi tokens were deposited from. |
| fee | uint256 | The redeem fee captured. |

### _transferFrom

```solidity
function _transferFrom(address _asset, uint256 _amount, address _sender, address _recipient) internal
```

Executes a transferFrom operation in the context of COFI.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _asset | address | The ERC20 token to transfer. |
| _amount | uint256 | The amount to transfer. |
| _sender | address | The account to transfer tokens from. |
| _recipient | address | The account to transfer tokens to. |

### _transfer

```solidity
function _transfer(address _asset, uint256 _amount, address _recipient) internal
```

Executes a transfer operation in the context of COFI.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _asset | address | The ERC20 token to transfer. |
| _amount | uint256 | The amount to transfer. |
| _recipient | address | The account to transfer tokens to. |

### _mint

```solidity
function _mint(address _cofi, address _to, uint256 _amount) internal
```

Executes a mint operation in the context of COFI.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to mint. |
| _to | address | The account to mint to. |
| _amount | uint256 | The amount to mint. |

### _mintOptIn

```solidity
function _mintOptIn(address _cofi, address _to, uint256 _amount) internal
```

Executes a mint operation and opts the receiver into rebases.

_Useful is receiver is a smart contract, as require manually opting in._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to mint. |
| _to | address | The account to mint to. |
| _amount | uint256 | The amount to mint. |

### _burn

```solidity
function _burn(address _cofi, address _from, uint256 _amount) internal
```

Executes a burn operation in the context of COFI.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to burn. |
| _from | address | The account to burn from. |
| _amount | uint256 | The amout to burn. |

### _redeem

```solidity
function _redeem(address _cofi, address _from, address _to, uint256 _amount) internal
```

Calls redeem operation on cofi token contract.

_Skips approval check._

### _lock

```solidity
function _lock(address _cofi, address _from, uint256 _amount) internal
```

Ensures the amount of cofi tokens are non-transferable from the account.
Useful for future collateralisation purposes.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to lock. |
| _from | address | The account to lock for. |
| _amount | uint256 | The amount of cofi tokens to lock. |

### _unlock

```solidity
function _unlock(address _cofi, address _from, uint256 _amount) internal
```

Frees up previously locked baalnce.

### _poke

```solidity
function _poke(address _cofi) internal returns (uint256 assets, uint256 yield, uint256 shareYield)
```

Updates cofi token supply to assets held in vault. Used to distribute earnings.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to distribute earnings for. |

### _changeSupply

```solidity
function _changeSupply(address _cofi, uint256 _amount, uint256 _yield, uint256 _fee) internal
```

_Updates supply directly._

### _getRebasingCreditsPerToken

```solidity
function _getRebasingCreditsPerToken(address _cofi) internal view returns (uint256)
```

Gets the rCPT for a given cofi token.
Reading at two different points in time can determine interest rate.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to enquire for. |

### _getMintFee

```solidity
function _getMintFee(address _cofi, uint256 _amount) internal view returns (uint256)
```

Gets the mint fee for a given amount of cofi tokens.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to mint. |
| _amount | uint256 | The amount of cofi tokens to mint. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | mintFee in cofi tokens. |

### _getRedeemFee

```solidity
function _getRedeemFee(address _cofi, uint256 _amount) internal view returns (uint256)
```

Gets the redeem fee for a given amount of cofi tokens.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to redeem. |
| _amount | uint256 | The amount of cofi tokens to redeem. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | redeemFee in cofi tokens. |

### _rebaseOptIn

```solidity
function _rebaseOptIn(address _cofi) internal
```

Opts this contract into receiving rebases.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to opt-in to rebases for. |

### _rebaseOptOut

```solidity
function _rebaseOptOut(address _cofi) internal
```

Opts this contract out of receiving rebases.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to opt-out of rebases for. |

### _getYieldEarned

```solidity
function _getYieldEarned(address _account, address _cofi) internal view returns (uint256)
```

Gets yield earned of a given cofi token for a given account.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The account to get yield earnings for.      @ @param _cofi     The cofi token to enquire for. |
| _cofi | address |  |

### _toCofiDecimals

```solidity
function _toCofiDecimals(address _underlying, uint256 _amount) internal view returns (uint256)
```

Represents an underlying token in cofi decimals (18).

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _underlying | address | The token to represent in cofi decimals. |
| _amount | uint256 | The amount of underlying to convert. |

### _toUnderlyingDecimals

```solidity
function _toUnderlyingDecimals(address _cofi, uint256 _amount) internal view returns (uint256)
```

Represents a cofi token in its underlying token's decimals.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to represent in underlying decimals. |
| _amount | uint256 | The amount of cofi tokens to translate. |

## LibUniswapV3

### UNISWAP_V3_ROUTER

```solidity
contract ISwapRouter UNISWAP_V3_ROUTER
```

### WETH

```solidity
address WETH
```

### _exactInput

```solidity
function _exactInput(uint256 _amountIn, uint256 _amountOutMin, address _from, address _to, address _recipient) internal returns (uint256 amountOut)
```

### _exactInputETH

```solidity
function _exactInputETH(uint256 _amountOutMin, address _to) internal returns (uint256 amountOut)
```

## LibVault

### Wrap

```solidity
event Wrap(address vault, uint256 assets, uint256 shares)
```

Emitted when a wrap operation is executed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| vault | address | The ERC4626 vault deposited assets into. |
| assets | uint256 | The amount of assets wrapped. |
| shares | uint256 | The amount of shares received. |

### Unwrap

```solidity
event Unwrap(address vault, uint256 assets, uint256 shares)
```

Emitted when an unwrap operation is executed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| vault | address | The ERC4626 vault shares were redeemeed from. |
| assets | uint256 | The amount of assets redeemed. |
| shares | uint256 | The amount of shares unwrapped. |

### VaultMigration

```solidity
event VaultMigration(address cofi, address vault, address newVault, uint256 assets, uint256 newAssets)
```

Emitted when a vault migration is executed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| cofi | address | The cofi token to migrate assets for. |
| vault | address | The vault migrated from. |
| newVault | address | The vault migrated to. |
| assets | uint256 | The amount of assets pre-migration (represented in underlying decimals). |
| newAssets | uint256 | The amount of assets post-migration (represented in underlying decimals). |

### Harvest

```solidity
event Harvest(address vault, uint256 assets)
```

Emitted when a harvest operation is executed (usually immediately prior to a rebase).

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| vault | address | The actual vault where the harvest operation resides. |
| assets | uint256 | The amount of assets harvested. |

### _wrap

```solidity
function _wrap(uint256 _amount, address _vault) internal returns (uint256 shares)
```

Wraps an underlying token into shares via the vault provided.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _amount | uint256 | The amount of underlying tokens to wrap. |
| _vault | address | The ERC4626 vault to wrap via. |

### _unwrap

```solidity
function _unwrap(uint256 _amount, address _vault, address _recipient) internal returns (uint256 assets)
```

Unwraps shares into underlying tokens via the vault provided.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _amount | uint256 | The amount of cofi tokens to redeem (target 1:1 correlation to vault assets). |
| _vault | address | The ERC4626 vault. |
| _recipient | address | The account receiving underlying tokens. |

### _harvest

```solidity
function _harvest(address _vault) internal
```

Executes a harvest operation in the vault contract.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _vault | address | The vault to harvest (must contain harvest function). |

### _getAssets

```solidity
function _getAssets(uint256 _shares, address _vault) internal view returns (uint256 assets)
```

Returns the number of assets from shares of a given vault.

### _getShares

```solidity
function _getShares(uint256 _assets, address _vault) internal view returns (uint256 shares)
```

Returns the number of shares from assets for a given vault.

### _totalValue

```solidity
function _totalValue(address _vault) internal view returns (uint256 assets)
```

Gets total value of this contract's holding of shares from the relevant vault.

## LibVelodromeV2

### VELODROME_V2_ROUTER

```solidity
contract IRouter VELODROME_V2_ROUTER
```

### VELODROME_V2_FACTORY

```solidity
address VELODROME_V2_FACTORY
```

### WETH

```solidity
address WETH
```

### _swapExactTokensForTokens

```solidity
function _swapExactTokensForTokens(uint256 _amountIn, uint256 _amountOutMin, address _from, address _to, address _recipient) internal returns (uint256[] amounts)
```

### _swapExactETHForTokens

```solidity
function _swapExactETHForTokens(uint256 _amountOutMin, address _to) internal returns (uint256[] amounts)
```

### _swapExactTokensForETH

```solidity
function _swapExactTokensForETH(uint256 _amountIn, uint256 _amountOutMin, address _from, address _recipient) internal returns (uint256[] amounts)
```

### _getRoutes

```solidity
function _getRoutes(address _from, address _to) internal view returns (struct IRouter.Route[] routes)
```

### _getAmountsOut

```solidity
function _getAmountsOut(uint256 _amountIn, address _from, address _to) internal view returns (uint256[] amounts)
```

## FixedPointMath

Arithmetic library with operations for fixed-point numbers.

### MAX_UINT256

```solidity
uint256 MAX_UINT256
```

### WAD

```solidity
uint256 WAD
```

### mulWadDown

```solidity
function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256)
```

### mulWadUp

```solidity
function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256)
```

### divWadDown

```solidity
function divWadDown(uint256 x, uint256 y) internal pure returns (uint256)
```

### divWadUp

```solidity
function divWadUp(uint256 x, uint256 y) internal pure returns (uint256)
```

### mulDivDown

```solidity
function mulDivDown(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z)
```

### mulDivUp

```solidity
function mulDivUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z)
```

### rpow

```solidity
function rpow(uint256 x, uint256 n, uint256 scalar) internal pure returns (uint256 z)
```

### sqrt

```solidity
function sqrt(uint256 x) internal pure returns (uint256 z)
```

### unsafeMod

```solidity
function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z)
```

### unsafeDiv

```solidity
function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r)
```

### unsafeDivUp

```solidity
function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z)
```

## PercentageMath

Provides functions to perform percentage calculations

_Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down._

### PERCENTAGE_FACTOR

```solidity
uint256 PERCENTAGE_FACTOR
```

### HALF_PERCENTAGE_FACTOR

```solidity
uint256 HALF_PERCENTAGE_FACTOR
```

### percentMul

```solidity
function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result)
```

Executes a percentage multiplication

_assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | uint256 | The value of which the percentage needs to be calculated |
| percentage | uint256 | The percentage of the value to be calculated |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | uint256 | value percentmul percentage |

### percentDiv

```solidity
function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256 result)
```

Executes a percentage division

_assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | uint256 | The value of which the percentage needs to be calculated |
| percentage | uint256 | The percentage of the value to be calculated |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | uint256 | value percentdiv percentage |

## StableMath

### scaleBy

```solidity
function scaleBy(uint256 x, uint256 to, uint256 from) internal pure returns (uint256)
```

_Adjust the scale of an integer_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 |  |
| to | uint256 | Decimals to scale to |
| from | uint256 | Decimals to scale from |

### mulTruncate

```solidity
function mulTruncate(uint256 x, uint256 y) internal pure returns (uint256)
```

_Multiplies two precise units, and then truncates by the full scale_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to multiplication |
| y | uint256 | Right hand input to multiplication |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the two inputs and then dividing by the shared         scale unit |

### mulTruncateScale

```solidity
function mulTruncateScale(uint256 x, uint256 y, uint256 scale) internal pure returns (uint256)
```

_Multiplies two precise units, and then truncates by the given scale. For example,
when calculating 90% of 10e18, (10e18 * 9e17) / 1e18 = (9e36) / 1e18 = 9e18_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to multiplication |
| y | uint256 | Right hand input to multiplication |
| scale | uint256 | Scale unit |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the two inputs and then dividing by the shared         scale unit |

### mulTruncateCeil

```solidity
function mulTruncateCeil(uint256 x, uint256 y) internal pure returns (uint256)
```

_Multiplies two precise units, and then truncates by the full scale, rounding up the result_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to multiplication |
| y | uint256 | Right hand input to multiplication |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the two inputs and then dividing by the shared          scale unit, rounded up to the closest base unit. |

### divPrecisely

```solidity
function divPrecisely(uint256 x, uint256 y) internal pure returns (uint256)
```

_Precisely divides two units, by first scaling the left hand operand. Useful
     for finding percentage weightings, i.e. 8e18/10e18 = 80% (or 8e17)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to division |
| y | uint256 | Right hand input to division |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the left operand by the scale, and         executing the division on the right hand input. |

### abs

```solidity
function abs(int256 x) internal pure returns (uint256)
```

## COFIRebasingToken

NOTE that this is an ERC20 token but the invariant that the sum of
balanceOf(x) for all x is not >= totalSupply(). This is a consequence of the
rebasing design. Any integrations should be aware.

### TotalSupplyUpdatedHighres

```solidity
event TotalSupplyUpdatedHighres(uint256 totalSupply, uint256 rebasingCredits, uint256 rebasingCreditsPerToken)
```

### RebaseOptions

```solidity
enum RebaseOptions {
  NotSet,
  OptOut,
  OptIn
}
```

### _totalSupply

```solidity
uint256 _totalSupply
```

### nonRebasingSupply

```solidity
uint256 nonRebasingSupply
```

### _creditBalances

```solidity
mapping(address => uint256) _creditBalances
```

### nonRebasingCreditsPerToken

```solidity
mapping(address => uint256) nonRebasingCreditsPerToken
```

### isUpgraded

```solidity
mapping(address => uint256) isUpgraded
```

### rebaseState

```solidity
mapping(address => enum COFIRebasingToken.RebaseOptions) rebaseState
```

### app

```solidity
address app
```

### paused

```solidity
uint8 paused
```

### yieldExcl

```solidity
mapping(address => int256) yieldExcl
```

### locked

```solidity
mapping(address => uint256) locked
```

### constructor

```solidity
constructor(string _name, string _symbol) public
```

### totalSupply

```solidity
function totalSupply() public view returns (uint256)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The total supply of tokens. |

### rebasingCreditsPerToken

```solidity
function rebasingCreditsPerToken() public view returns (uint256)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Low resolution rebasingCreditsPerToken. |

### rebasingCredits

```solidity
function rebasingCredits() public view returns (uint256)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Low resolution total number of rebasing credits. |

### rebasingCreditsPerTokenHighres

```solidity
function rebasingCreditsPerTokenHighres() public view returns (uint256)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | High resolution rebasingCreditsPerToken. |

### rebasingCreditsHighres

```solidity
function rebasingCreditsHighres() public view returns (uint256)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | High resolution total number of rebasing credits. |

### balanceOf

```solidity
function balanceOf(address _account) public view returns (uint256)
```

_Gets the balance of the specified address._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | Address to query the balance of. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | A uint256 representing the amount of base units owned by the          specified address. |

### freeBalanceOf

```solidity
function freeBalanceOf(address _account) public view returns (uint256)
```

Returns the transferable balance of an account.

### lock

```solidity
function lock(address _account, uint256 _amount) external returns (bool)
```

Locks an amount of tokens at the holder's address.

### unlock

```solidity
function unlock(address _account, uint256 _amount) external returns (bool)
```

### creditsToBal

```solidity
function creditsToBal(uint256 _amount) external view returns (uint256)
```

Returns the number of tokens from an amount of credits.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _amount | uint256 | The amount of credits to convert to tokens. |

### creditsBalanceOf

```solidity
function creditsBalanceOf(address _account) public view returns (uint256, uint256)
```

_Gets the credits balance of the specified address.
Backwards compatible with old low res credits per token._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The address to query the balance of. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | (uint256, uint256) Credit balance and credits per token of the                  address. |
| [1] | uint256 |  |

### creditsBalanceOfHighres

```solidity
function creditsBalanceOfHighres(address _account) public view returns (uint256, uint256, bool)
```

_Gets the credits balance of the specified address._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The address to query the balance of. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | (uint256, uint256, bool) Credit balance, credits per token of the                  address, and isUpgraded. |
| [1] | uint256 |  |
| [2] | bool |  |

### transfer

```solidity
function transfer(address _to, uint256 _value) public returns (bool)
```

_Transfer tokens to a specified address._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _to | address | The address to transfer to. |
| _value | uint256 | The amount to be transferred. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True on success. |

### transferFrom

```solidity
function transferFrom(address _from, address _to, uint256 _value) public returns (bool)
```

_Transfer tokens from one address to another._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _from | address | The address you want to send tokens from. |
| _to | address | The address you want to transfer to. |
| _value | uint256 | The amount of tokens to be transferred. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True on success. |

### redeem

```solidity
function redeem(address _from, address _to, uint256 _value) external returns (bool)
```

Redeem function, only callable from Diamond, to return tokens.

_Skips approval check._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _from | address | The address to redeem tokens from. |
| _to | address | The receiver of the tokens (usually the fee collector). |
| _value | uint256 | The amount of tokens to redeem. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | True on success. |

### _executeTransfer

```solidity
function _executeTransfer(address _from, address _to, uint256 _value) internal
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _from | address | The address you want to send tokens from. |
| _to | address | The address you want to transfer to. |
| _value | uint256 | Amount of tokens to transfer |

### allowance

```solidity
function allowance(address _owner, address _spender) public view returns (uint256)
```

_Function to check the amount of tokens that _owner has allowed to
     `_spender`._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _owner | address | The address which owns the funds. |
| _spender | address | The address which will spend the funds. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The number of tokens still available for the _spender. |

### approve

```solidity
function approve(address _spender, uint256 _value) public returns (bool)
```

_Approve the passed address to spend the specified amount of tokens
     on behalf of msg.sender. This method is included for ERC20
     compatibility. `increaseAllowance` and `decreaseAllowance` should be
     used instead.

     Changing an allowance with this method brings the risk that someone
     may transfer both the old and the new allowance - if they are both
     greater than zero - if a transfer transaction is mined before the
     later approve() call is mined._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _spender | address | The address which will spend the funds. |
| _value | uint256 | The amount of tokens to be spent. |

### increaseAllowance

```solidity
function increaseAllowance(address _spender, uint256 _addedValue) public returns (bool)
```

_Increase the amount of tokens that an owner has allowed to
     `_spender`.
     This method should be used instead of approve() to avoid the double
     approval vulnerability described above._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _spender | address | The address which will spend the funds. |
| _addedValue | uint256 | The amount of tokens to increase the allowance by. |

### decreaseAllowance

```solidity
function decreaseAllowance(address _spender, uint256 _subtractedValue) public returns (bool)
```

_Decrease the amount of tokens that an owner has allowed to
            `_spender`._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _spender | address | The address which will spend the funds. |
| _subtractedValue | uint256 | The amount of tokens to decrease the allowance                          by. |

### mint

```solidity
function mint(address _account, uint256 _amount) external
```

_Mints new tokens, increasing totalSupply._

### mintOptIn

```solidity
function mintOptIn(address _account, uint256 _amount) external
```

_Additional function for opting the account in after minting._

### _mint

```solidity
function _mint(address _account, uint256 _amount) internal
```

_Creates `_amount` tokens and assigns them to `_account`, increasing
the total supply.

Emits a {Transfer} event with `from` set to the zero address.

Requirements

- `to` cannot be the zero address._

### burn

```solidity
function burn(address _account, uint256 _amount) external
```

_Burns tokens, decreasing totalSupply.
     When an account burns tokens without redeeming, the amount burned is
     essentially redistributed to the remaining holders upon the next rebase._

### _burn

```solidity
function _burn(address _account, uint256 _amount) internal
```

_Destroys `_amount` tokens from `_account`, reducing the
total supply.

Emits a {Transfer} event with `to` set to the zero address.

Requirements

- `_account` cannot be the zero address.
- `_account` must have at least `_amount` tokens._

### _creditsPerToken

```solidity
function _creditsPerToken(address _account) internal view returns (uint256)
```

_Get the credits per token for an account. Returns a fixed amount
     if the account is non-rebasing._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | Address of the account. |

### _isNonRebasingAccount

```solidity
function _isNonRebasingAccount(address _account) internal returns (bool)
```

_Is an account using rebasing accounting or non-rebasing accounting?
     Also, ensure contracts are non-rebasing if they have not opted in._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | Address of the account. |

### _ensureRebasingMigration

```solidity
function _ensureRebasingMigration(address _account) internal
```

_Ensures internal account for rebasing and non-rebasing credits and
     supply is updated following deployment of frozen yield change._

### rebaseOptIn

```solidity
function rebaseOptIn() public
```

_Add a contract address to the non-rebasing exception list. The
address's balance will be part of rebases and the account will be exposed
to upside and downside._

### rebaseOptInExternal

```solidity
function rebaseOptInExternal(address _account) public
```

_Add a contract address to the non-rebasing exception list. The
address's balance will be part of rebases and the account will be exposed
to upside and downside._

### rebaseOptOut

```solidity
function rebaseOptOut() public
```

_Explicitly mark that an address is non-rebasing._

### rebaseOptOutExternal

```solidity
function rebaseOptOutExternal(address _account) public
```

_Explicitly mark that an address is non-rebasing._

### changeSupply

```solidity
function changeSupply(uint256 _newTotalSupply) external
```

_Modify the supply without minting new tokens. This uses a change in
     the exchange rate between "credits" and tokens to change balances._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _newTotalSupply | uint256 | New total supply of tokens. |

### getYieldEarned

```solidity
function getYieldEarned(address _account) external view returns (uint256)
```

Returns the amount of yield earned by ignoring account
         balance changes resulting from mint/burn/transfer.

_yieldExcl[_account]:
     Increases for outgoing amount (transfer 1,000) = 1,000.
     - E.g., burning 1,000 from = +1,000.
     Decreases for incoming amount (receive 1,000) = -1,000.
     - E.g., minting 1,000 to = -1,000.

Rebases usually introduce a very minor wei discrepancy
     between yield earned and token balance. Account for this
     by returning either 0 or a valid uint256._

### convertToAssets

```solidity
function convertToAssets(uint256 _creditBalance) public view returns (uint256 assets)
```

_Helper function to convert credit balance to token balance._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _creditBalance | uint256 | The credit balance to convert. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| assets | uint256 | The amount converted to token balance. |

### convertToCredits

```solidity
function convertToCredits(uint256 _tokenBalance) public view returns (uint256 credits)
```

_Helper function to convert token balance to credit balance._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokenBalance | uint256 | The token balance to convert. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| credits | uint256 | The amount converted to credit balance. |

### setAdmin

```solidity
function setAdmin(address _account, uint8 _enabled) external returns (bool)
```

### setFrozen

```solidity
function setFrozen(address _account, uint8 _enabled) external returns (bool)
```

_If freezing, first ensure account is opted out of rebases._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool Indicating true if frozen. |

### setPaused

```solidity
function setPaused(uint8 _enabled) external returns (bool)
```

### setRebaseLock

```solidity
function setRebaseLock(address _account, uint8 _enabled) external returns (bool)
```

### setApp

```solidity
function setApp(address _app) external returns (bool)
```

### onlyApp

```solidity
modifier onlyApp()
```

_Verifies that the caller is the Diamond (app) contract._

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

_Verifies that the caller is Owner or Admin._

### isValidTransfer

```solidity
modifier isValidTransfer(uint256 _value, address _from, address _to)
```

_Verifies that the transfer is valid by running checks._

## StableMath

### scaleBy

```solidity
function scaleBy(uint256 x, uint256 to, uint256 from) internal pure returns (uint256)
```

_Adjust the scale of an integer_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 |  |
| to | uint256 | Decimals to scale to |
| from | uint256 | Decimals to scale from |

### mulTruncate

```solidity
function mulTruncate(uint256 x, uint256 y) internal pure returns (uint256)
```

_Multiplies two precise units, and then truncates by the full scale_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to multiplication |
| y | uint256 | Right hand input to multiplication |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the two inputs and then dividing by the shared         scale unit |

### mulTruncateScale

```solidity
function mulTruncateScale(uint256 x, uint256 y, uint256 scale) internal pure returns (uint256)
```

_Multiplies two precise units, and then truncates by the given scale. For example,
when calculating 90% of 10e18, (10e18 * 9e17) / 1e18 = (9e36) / 1e18 = 9e18_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to multiplication |
| y | uint256 | Right hand input to multiplication |
| scale | uint256 | Scale unit |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the two inputs and then dividing by the shared         scale unit |

### mulTruncateCeil

```solidity
function mulTruncateCeil(uint256 x, uint256 y) internal pure returns (uint256)
```

_Multiplies two precise units, and then truncates by the full scale, rounding up the result_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to multiplication |
| y | uint256 | Right hand input to multiplication |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the two inputs and then dividing by the shared          scale unit, rounded up to the closest base unit. |

### divPrecisely

```solidity
function divPrecisely(uint256 x, uint256 y) internal pure returns (uint256)
```

_Precisely divides two units, by first scaling the left hand operand. Useful
     for finding percentage weightings, i.e. 8e18/10e18 = 80% (or 8e17)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to division |
| y | uint256 | Right hand input to division |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the left operand by the scale, and         executing the division on the right hand input. |

### abs

```solidity
function abs(int256 x) internal pure returns (uint256)
```

## ERC20Permit

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author cofi.money
    @title  ERC20Permit
    @notice OZ ERC20Permit contract with amendments for _allowances to adhere to parent contract functionality.

_Implementation of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].

Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
need to send a transaction, and thus is not required to hold Ether at all.

_Available since v3.4.__

### _allowances

```solidity
mapping(address => mapping(address => uint256)) _allowances
```

_Moved _allowances from parent contract to here._

### constructor

```solidity
constructor(string name) internal
```

_Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.

It's a good idea to use the same `name` that is defined as the ERC20 token name._

### permit

```solidity
function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public virtual
```

_See {IERC20Permit-permit}._

### nonces

```solidity
function nonces(address owner) public view virtual returns (uint256)
```

_See {IERC20Permit-nonces}._

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32)
```

_See {IERC20Permit-DOMAIN_SEPARATOR}._

### _useNonce

```solidity
function _useNonce(address owner) internal virtual returns (uint256 current)
```

_"Consume a nonce": return the current value and increment.

_Available since v4.1.__

## PercentageMath

Provides functions to perform percentage calculations

_Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down._

### PERCENTAGE_FACTOR

```solidity
uint256 PERCENTAGE_FACTOR
```

### HALF_PERCENTAGE_FACTOR

```solidity
uint256 HALF_PERCENTAGE_FACTOR
```

### percentMul

```solidity
function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result)
```

Executes a percentage multiplication

_assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | uint256 | The value of which the percentage needs to be calculated |
| percentage | uint256 | The percentage of the value to be calculated |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | uint256 | value percentmul percentage |

### percentDiv

```solidity
function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256 result)
```

Executes a percentage division

_assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| value | uint256 | The value of which the percentage needs to be calculated |
| percentage | uint256 | The percentage of the value to be calculated |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| result | uint256 | value percentdiv percentage |

## LoanExample

### SUBPAR_THRESHOLD

```solidity
uint256 SUBPAR_THRESHOLD
```

### FAIR_THRESHOLD

```solidity
uint256 FAIR_THRESHOLD
```

### GOOD_THRESHOLD

```solidity
uint256 GOOD_THRESHOLD
```

### EXCELLENT_THRESHOLD

```solidity
uint256 EXCELLENT_THRESHOLD
```

### Account

```solidity
struct Account {
  uint256 outstanding;
  uint256 creditScore;
  uint256 deadline;
  bool active;
}
```

### account

```solidity
mapping(address => struct LoanExample.Account) account
```

### constructor

```solidity
constructor(string _name, string _symbol, uint8 decimals_) public
```

### getLoanTerms

```solidity
function getLoanTerms(address _account) public view returns (uint256 maxBorrow, uint256 apr, uint256 deadline)
```

### borrow

```solidity
function borrow(uint256 _amount) external returns (uint256 newOutstanding)
```

### simulateOneYearElapsed

```solidity
function simulateOneYearElapsed() external returns (uint256 newOutstanding)
```

### repay

```solidity
function repay(uint256 _amount) external returns (uint256 newOutstanding)
```

### mint

```solidity
function mint(address _to, uint256 _amount) external
```

### burn

```solidity
function burn(address _from, uint256 _amount) external
```

### decimals

```solidity
function decimals() public view returns (uint8)
```

_Returns the number of decimals used to get its user representation.
For example, if `decimals` equals `2`, a balance of `505` tokens should
be displayed to a user as `5.05` (`505 / 10 ** 2`).

Tokens usually opt for a value of 18, imitating the relationship between
Ether and Wei. This is the default value returned by this function, unless
it's overridden.

NOTE: This information is only used for _display_ purposes: it in
no way affects any of the arithmetic of the contract, including
{IERC20-balanceOf} and {IERC20-transfer}._

### setCreditScore

```solidity
function setCreditScore(address _account, uint256 _creditScore) external
```

### getOutstanding

```solidity
function getOutstanding(address _account) external view returns (uint256)
```

### getCreditScore

```solidity
function getCreditScore(address _account) external view returns (uint256)
```

### getDeadline

```solidity
function getDeadline(address _account) external view returns (uint256)
```

### getActive

```solidity
function getActive(address _account) external view returns (bool)
```

### enquireMaxBorrow

```solidity
function enquireMaxBorrow(address _account) public view returns (uint256 maxBorrow)
```

### enquireApr

```solidity
function enquireApr(address _account) public view returns (uint256 apr)
```

### enquireDeadline

```solidity
function enquireDeadline(address _account) public view returns (uint256 deadline)
```

## ICOFIMoney

### rebase

```solidity
function rebase(address _cofi) external returns (uint256, uint256, uint256)
```

## ICOFIRebasingToken

### rebasingCreditsPerToken

```solidity
function rebasingCreditsPerToken() external view returns (uint256)
```

## Helper

### rcpt

```solidity
mapping(address => uint256[]) rcpt
```

### admin

```solidity
mapping(address => uint8) admin
```

### upkeep

```solidity
mapping(address => uint8) upkeep
```

### app

```solidity
contract ICOFIMoney app
```

### constructor

```solidity
constructor(address _app, address _coUSD, address _coETH, address _coBTC) public
```

### rebase

```solidity
function rebase(address _cofi) external returns (bool)
```

Performs rebase and stores rcpt value for APY calc.

### getRebasingCreditsPerToken

```solidity
function getRebasingCreditsPerToken(address _cofi, uint256 _period) external view returns (uint256 rcptA, uint256 rcptB)
```

Used for APY calculation off-chain: (rcptA / rcptB)^(365.25 / period) - 1.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to enquire for. |
| _period | uint256 | The number of days to retrieve annualized APY for. |

### setRebasingCreditsPerToken

```solidity
function setRebasingCreditsPerToken(address _cofi, uint256[] _rcpt) external returns (bool)
```

Enables admin to manually set rcpt.

### pushRebasingCreditsPerToken

```solidity
function pushRebasingCreditsPerToken(address _cofi, uint256 _rcpt) external returns (bool)
```

Enables admin to manually add rcpt entry.

### setUpkeep

```solidity
function setUpkeep(address _account, uint8 _enabled) external returns (bool)
```

### setAdmin

```solidity
function setAdmin(address _account, uint8 _enabled) external returns (bool)
```

### onlyAdmin

```solidity
modifier onlyAdmin()
```

### onlyUpkeep

```solidity
modifier onlyUpkeep()
```

## COFIBridgeEntry

THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
DO NOT USE THIS CODE IN PRODUCTION.

### PayFeesIn

```solidity
enum PayFeesIn {
  Native,
  LINK
}
```

### i_link

```solidity
address i_link
```

### MessageSent

```solidity
event MessageSent(bytes32 messageId)
```

### CallSuccessful

```solidity
event CallSuccessful()
```

### InsufficientFee

```solidity
error InsufficientFee()
```

### NotAuthorizedTransmitter

```solidity
error NotAuthorizedTransmitter()
```

### mandateFee

```solidity
bool mandateFee
```

### gasLimit

```solidity
uint256 gasLimit
```

### testCofi

```solidity
address testCofi
```

### pong

```solidity
uint256 pong
```

### vault

```solidity
mapping(address => contract IERC4626) vault
```

### destShare

```solidity
mapping(address => mapping(uint64 => address)) destShare
```

### srcAsset

```solidity
mapping(address => address) srcAsset
```

### receiver

```solidity
mapping(uint64 => address) receiver
```

### authorizedTransmitter

```solidity
mapping(address => bool) authorizedTransmitter
```

### authorized

```solidity
mapping(address => bool) authorized
```

### constructor

```solidity
constructor(address _router, address _link, address _cofi, address _vault, uint64 _destChainSelector, address _destShare, address _receiver) public
```

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

### receive

```solidity
receive() external payable
```

### setAuthorized

```solidity
function setAuthorized(address _account, bool _authorized) external
```

### setAuthorizedTransmitter

```solidity
function setAuthorizedTransmitter(address _account, bool _authorized) external
```

### setVault

```solidity
function setVault(address _cofi, address _vault) external
```

### setDestShare

```solidity
function setDestShare(address _cofi, uint64 _destChainSelector, address _destShare) external
```

### setReceiver

```solidity
function setReceiver(uint64 _destChainSelector, address _receiver, bool _authorizedTransmitter) external
```

### setMandateFee

```solidity
function setMandateFee(bool _enabled) external
```

### setGasLimit

```solidity
function setGasLimit(uint256 _gasLimit) external
```

### enter

```solidity
function enter(address _cofi, uint64 _destChainSelector, uint256 _amount, address _destSharesReceiver) external payable returns (uint256 shares)
```

### _mint

```solidity
function _mint(uint64 _destChainSelector, address _share, address _recipient, uint256 _amount) internal
```

### getFeeETH

```solidity
function getFeeETH(address _cofi, uint64 _destChainSelector, uint256 _amount, address _destSharesReceiver) public view returns (uint256 fee)
```

### redeem

```solidity
function redeem(address _cofi, uint256 _shares, address _assetsReceiver) public returns (uint256 assets)
```

### _ccipReceive

```solidity
function _ccipReceive(struct Client.Any2EVMMessage message) internal
```

Override this function in your implementation.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| message | struct Client.Any2EVMMessage | Any2EVMMessage |

### doPing

```solidity
function doPing(uint256 _ping, address _receiver, uint64 _chainSelector) external payable
```

### _doPing

```solidity
function _doPing(uint256 _ping, address _receiver, uint64 _chainSelector) internal
```

### getFeeETHPing

```solidity
function getFeeETHPing(uint256 _pong, address _receiver, uint64 _chainSelector) public view returns (uint256 fee)
```

### doPong

```solidity
function doPong(uint256 _pong) public
```

### getCofi

```solidity
function getCofi(uint256 _amount) external
```

### testWrap

```solidity
function testWrap(uint256 _amount) external returns (uint256 shares)
```

### testUnwrap

```solidity
function testUnwrap(address _cofi, address _recipient, uint256 _amount) external returns (uint256 assets)
```

## COFIBridgeExit

THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
DO NOT USE THIS CODE IN PRODUCTION.

### PayFeesIn

```solidity
enum PayFeesIn {
  Native,
  LINK
}
```

### i_link

```solidity
address i_link
```

### MessageSent

```solidity
event MessageSent(bytes32 messageId)
```

### CallSuccessful

```solidity
event CallSuccessful()
```

### InsufficientFee

```solidity
error InsufficientFee()
```

### NotAuthorizedTrasnmitter

```solidity
error NotAuthorizedTrasnmitter()
```

### mandateFee

```solidity
bool mandateFee
```

### gasLimit

```solidity
uint256 gasLimit
```

### testDestShare

```solidity
address testDestShare
```

### ping

```solidity
uint256 ping
```

### SourceAsset

```solidity
struct SourceAsset {
  address asset;
  uint64 chainSelector;
}
```

### srcAsset

```solidity
mapping(address => struct COFIBridgeExit.SourceAsset) srcAsset
```

### receiver

```solidity
mapping(uint64 => address) receiver
```

### authorizedTransmitter

```solidity
mapping(address => bool) authorizedTransmitter
```

### authorized

```solidity
mapping(address => bool) authorized
```

### constructor

```solidity
constructor(address _router, address _link, address _destShare, address _srcAsset, uint64 _srcChainSelector) public
```

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

### receive

```solidity
receive() external payable
```

### setAuthorized

```solidity
function setAuthorized(address _account, bool _authorized) external
```

### setAuthorizedTransmitter

```solidity
function setAuthorizedTransmitter(address _account, bool _authorized) external
```

### setSourceAsset

```solidity
function setSourceAsset(address _destShare, uint64 _srcChainSelector, address _srcAsset) external
```

### setReceiver

```solidity
function setReceiver(uint64 _destChainSelector, address _receiver, bool _authorizedTransmitter) external
```

### setMandateFee

```solidity
function setMandateFee(bool _enabled) external
```

### setGasLimit

```solidity
function setGasLimit(uint256 _gasLimit) external
```

### getSourceAsset

```solidity
function getSourceAsset(address _destShare) external view returns (address)
```

### getSourceChainSelector

```solidity
function getSourceChainSelector(address _destShare) external view returns (uint64)
```

### exit

```solidity
function exit(address _destShare, uint256 _amount, address _srcAssetsReceiver) external payable
```

### _burn

```solidity
function _burn(uint64 _srcChainSelector, address _asset, address _recipient, uint256 _amount) internal
```

### getFeeETH

```solidity
function getFeeETH(address _destShare, uint256 _amount, address _srcAssetReceiver) public view returns (uint256 fee)
```

### mint

```solidity
function mint(address _destShare, address _destSharesReceiver, uint256 _amount) public
```

### _ccipReceive

```solidity
function _ccipReceive(struct Client.Any2EVMMessage message) internal
```

Override this function in your implementation.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| message | struct Client.Any2EVMMessage | Any2EVMMessage |

### doPong

```solidity
function doPong(uint256 _pong, address _receiver, uint64 _chainSelector) external payable
```

### _doPong

```solidity
function _doPong(uint256 _pong, address _receiver, uint64 _chainSelector) internal
```

### getFeeETHPong

```solidity
function getFeeETHPong(uint256 _pong, address _receiver, uint64 _chainSelector) public view returns (uint256 fee)
```

### doPing

```solidity
function doPing(uint256 _ping) public
```

### getShares

```solidity
function getShares(uint256 _amount) external
```

"Bridging" back arbitrarily minted destination shares will fail if insufficient
source shares do not reside at bridge entry contract.

### testBurn

```solidity
function testBurn(uint256 _amount) external
```

## Diamond

### constructor

```solidity
constructor(address _contractOwner, address _diamondCutFacet) public payable
```

### fallback

```solidity
fallback() external payable
```

### receive

```solidity
receive() external payable
```

## InitDiamond

### s

```solidity
struct AppStorage s
```

### Args

```solidity
struct Args {
  address coUSD;
  address coETH;
  address coBTC;
  address coOP;
  address vUSD;
  address vETH;
  address vBTC;
  address vOP;
  address[] roles;
}
```

### init

```solidity
function init(struct InitDiamond.Args _args) external
```

## InitDiamondEthereum

### s

```solidity
struct AppStorage s
```

### Args

```solidity
struct Args {
  address coUSD;
  address vDAI;
  address DAI;
  address[] roles;
}
```

### init

```solidity
function init(struct InitDiamondEthereum.Args _args) external
```

## DiamondCutFacet

### diamondCut

```solidity
function diamondCut(struct IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata) external
```

Add/replace/remove any number of functions and optionally execute
        a function with delegatecall

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _diamondCut | struct IDiamondCut.FacetCut[] | Contains the facet addresses and function selectors |
| _init | address | The address of the contract or facet to execute _calldata |
| _calldata | bytes | A function call, including function selector and arguments                  _calldata is executed with delegatecall on _init |

## DiamondLoupeFacet

### facets

```solidity
function facets() external view returns (struct IDiamondLoupe.Facet[] facets_)
```

Gets all facets and their selectors.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| facets_ | struct IDiamondLoupe.Facet[] | Facet |

### facetFunctionSelectors

```solidity
function facetFunctionSelectors(address _facet) external view returns (bytes4[] facetFunctionSelectors_)
```

Gets all the function selectors provided by a facet.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _facet | address | The facet address. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| facetFunctionSelectors_ | bytes4[] |  |

### facetAddresses

```solidity
function facetAddresses() external view returns (address[] facetAddresses_)
```

Get all the facet addresses used by a diamond.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| facetAddresses_ | address[] |  |

### facetAddress

```solidity
function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_)
```

Gets the facet that supports the given selector.

_If facet is not found return address(0)._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _functionSelector | bytes4 | The function selector. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| facetAddress_ | address | The facet address. |

### supportsInterface

```solidity
function supportsInterface(bytes4 _interfaceId) external view returns (bool)
```

## OwnershipFacet

### transferOwnership

```solidity
function transferOwnership(address _newOwner) public virtual
```

Set the address of the new owner of the contract

_Set _newOwner to address(0) to renounce any ownership._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _newOwner | address | The address of the new owner of the contract |

### owner

```solidity
function owner() external view returns (address owner_)
```

Get the address of the owner

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| owner_ | address | The address of the owner. |

## IDiamondLoupe

### Facet

These functions are expected to be called frequently
by tools.

```solidity
struct Facet {
  address facetAddress;
  bytes4[] functionSelectors;
}
```

### facets

```solidity
function facets() external view returns (struct IDiamondLoupe.Facet[] facets_)
```

Gets all facet addresses and their four byte function selectors.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| facets_ | struct IDiamondLoupe.Facet[] | Facet |

### facetFunctionSelectors

```solidity
function facetFunctionSelectors(address _facet) external view returns (bytes4[] facetFunctionSelectors_)
```

Gets all the function selectors supported by a specific facet.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _facet | address | The facet address. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| facetFunctionSelectors_ | bytes4[] |  |

### facetAddresses

```solidity
function facetAddresses() external view returns (address[] facetAddresses_)
```

Get all the facet addresses used by a diamond.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| facetAddresses_ | address[] |  |

### facetAddress

```solidity
function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_)
```

Gets the facet that supports the given selector.

_If facet is not found return address(0)._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _functionSelector | bytes4 | The function selector. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| facetAddress_ | address | The facet address. |

## IERC165

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```

Query if a contract implements an interface

_Interface identification is specified in ERC-165. This function
 uses less than 30,000 gas._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| interfaceId | bytes4 | The interface identifier, as specified in ERC-165 |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | `true` if the contract implements `interfaceID` and  `interfaceID` is not 0xffffffff, `false` otherwise |

## IERC173

### OwnershipTransferred

```solidity
event OwnershipTransferred(address previousOwner, address newOwner)
```

_This emits when ownership of a contract changes._

### owner

```solidity
function owner() external view returns (address owner_)
```

Get the address of the owner

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| owner_ | address | The address of the owner. |

### transferOwnership

```solidity
function transferOwnership(address _newOwner) external
```

Set the address of the new owner of the contract

_Set _newOwner to address(0) to renounce any ownership._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _newOwner | address | The address of the new owner of the contract |

## AccountManagerFacet

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Account Manager Facet
    @notice Admin functions for managing accounts.

### recover

```solidity
function recover(address _token, uint256 _amount, address _recipient) external returns (bool)
```

### lock

```solidity
function lock(address _cofi, address _account, uint256 _amount) external returns (bool)
```

### unlock

```solidity
function unlock(address _cofi, address _account, uint256 _amount) external returns (bool)
```

### setWhitelist

```solidity
function setWhitelist(address _account, uint8 _enabled) external returns (bool)
```

### setAdmin

```solidity
function setAdmin(address _account, uint8 _enabled) external returns (bool)
```

### setUpkeep

```solidity
function setUpkeep(address _account, uint8 _enabled) external returns (bool)
```

### setFeeCollector

```solidity
function setFeeCollector(address _account) external returns (bool)
```

### getWhitelistStatus

```solidity
function getWhitelistStatus(address _account) external view returns (uint8)
```

### getAdminStatus

```solidity
function getAdminStatus(address _account) external view returns (uint8)
```

### getWhitelisterStatus

```solidity
function getWhitelisterStatus(address _account) external view returns (uint8)
```

### getUpkeepStatus

```solidity
function getUpkeepStatus(address _account) external view returns (uint8)
```

### getFeeCollector

```solidity
function getFeeCollector() external view returns (address)
```

## PointsManagerFacet

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Points Manager Facet
    @notice Provides logic for managing and distributing points.

### captureYieldPoints

```solidity
function captureYieldPoints(address[] _accounts, address _cofi) external returns (bool)
```

This function must be called after the last rebase of a 'pointsRate' and before
         the application of a new 'pointsRate' for a given cofi token, for every account
         that is eliigble for yield/points. If not, the new 'pointsRate' will apply to
         yield earned during the previous, different pointsRate epoch - which we want to avoid.

_This function may be required to be called multiple times, as per the size limit for
     passing addresses, in order for all relevant accounts to be updated. Rebasing for the
     relevant cofi token should be paused beforehand so as to not interupt this process._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _accounts | address[] | The array of accounts to capture points for. |
| _cofi | address | The cofi token to capture points for. |

### reward

```solidity
function reward(address[] _accounts, uint256 _amount) external returns (bool)
```

Distributed points not intrinsically linked to yield.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _accounts | address[] | The array of accounts to distribute points for. |
| _amount | uint256 | The amount of points to distribute to each account. |

### setPointsRate

```solidity
function setPointsRate(address _cofi, uint256 _pointsRate) external returns (bool)
```

_Yield points must be captured beforehand to ensure update correctness._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofi | address | The cofi token to update 'pointsRate' for. |
| _pointsRate | uint256 | The new 'pointsRate' in basis points. |

### setInitReward

```solidity
function setInitReward(uint256 _reward) external returns (bool)
```

_Setting to 0 deactivates._

### setReferReward

```solidity
function setReferReward(uint256 _reward) external returns (bool)
```

_Setting to 0 deactivates._

### setRewardStatus

```solidity
function setRewardStatus(address _account, uint8 _initClaimed, uint8 _referClaimed, uint8 _referDisabled) external returns (bool)
```

_Used to manually configure reward status of account._

### getPoints

```solidity
function getPoints(address _account, address[] _cofi) public view returns (uint256 pointsTotal)
```

Returns the total number of points accrued for a given account (accrued through
         yield earnings and external means) for a given number of cofi tokens.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The account to enquire for. |
| _cofi | address[] | An array of cofi tokens to retrieve points for. |

### getYieldPoints

```solidity
function getYieldPoints(address _account, address[] _cofi) public view returns (uint256 pointsTotal)
```

Returns the number of points accrued, through yield earnings only, across
         a given number of cofi tokens (e.g., [coUSD, coETH, coBTC]).

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The account to enquire for. |
| _cofi | address[] | An array of cofi tokens to retrieve yield points for. |

### getExternalPoints

```solidity
function getExternalPoints(address _account) public view returns (uint256)
```

Gets external points for an account, earned through means not tied to yield.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The account to enquire for. |

### getPointsRate

```solidity
function getPointsRate(address _cofi) external view returns (uint256)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The 'pointsRate' denominated in basis points. |

### getInitReward

```solidity
function getInitReward() external view returns (uint256)
```

### getReferReward

```solidity
function getReferReward() external view returns (uint256)
```

### getRewardStatus

```solidity
function getRewardStatus(address _account) external view returns (uint8, uint8, uint8)
```

## SupplyFacet

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Supply Facet
    @notice User-operated functions for minting/redeeming cofi tokens.
            Backing assets are deployed to the respective vault as per schema.

### enterCofi

```solidity
function enterCofi(uint256 _tokensIn, address _token, address _cofi, address _depositFrom, address _recipient, address _referral) external payable returns (uint256 mintAfterFee, uint256 underlyingOut)
```

Simplified entry point for minting COFI tokens. Refer to 'getSupportedSwaps()'
         in 'SwapManagerFacet.sol' to see list of supported assets for entering with.

_Swap parameters must be set for token._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _tokensIn | uint256 | The amount of tokens to swap (pass instead as msg.value if native Ether). |
| _token | address | The ERC20 token to swap (irrelevant if native Ether). |
| _cofi | address | The cofi token to receive. |
| _depositFrom | address | The account to transfer tokens from (msg.sender if native Ether). |
| _recipient | address | The account receiving cofi tokens. |
| _referral | address | The referral account (address(0) if none given). |

### _ETHToCofi

```solidity
function _ETHToCofi(address _cofi, address _underlying, address _recipient, address _referral) internal returns (uint256 mintAfterFee, uint256 underlyingOut)
```

### exitCofi

```solidity
function exitCofi(uint256 _cofiIn, address _token, address _cofi, address _depositFrom, address _recipient) external returns (uint256 burnAfterFee, uint256 tokensOut)
```

Simplified exit point for minting COFI tokens. Refer to 'getSupportedSwaps()'
         in 'SwapManagerFacet.sol' to see list of supported assets for exiting to.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofiIn | uint256 | The amount of cofi tokens to redeem. |
| _token | address | The ERC20 token to receive (address(0) if requesting native Ether). |
| _cofi | address | The cofi token to redeem. |
| _depositFrom | address | The account to transfer cofi tokens from. |
| _recipient | address | The account receiving tokens. |

### _cofiToETH

```solidity
function _cofiToETH(uint256 _cofiIn, address _cofi, address _depositFrom, address _recipient) internal returns (uint256 burnAfterFee, uint256 ETHOut)
```

### underlyingToCofi

```solidity
function underlyingToCofi(uint256 _underlyingIn, address _cofi, address _depositFrom, address _recipient, address _referral) external returns (uint256 mintAfterFee)
```

Converts a supported underlying token into a cofi token (e.g., USDC to coUSD).

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _underlyingIn | uint256 | The amount of underlying tokens to deposit. |
| _cofi | address | The cofi token to receive. |
| _depositFrom | address | The account to transfer underlying tokens from. |
| _recipient | address | The account receiving cofi tokens. |
| _referral | address | The referral account (address(0) if none given). |

### _underlyingToCofi

```solidity
function _underlyingToCofi(uint256 _underlyingIn, address _cofi, address _underlying, address _recipient, address _referral) internal returns (uint256 mintAfterFee, uint256 fee)
```

### cofiToUnderlying

```solidity
function cofiToUnderlying(uint256 _cofiIn, address _cofi, address _depositFrom, address _recipient) external returns (uint256 burnAfterFee)
```

Converts a cofi token to its collateral underlying token (e.g., coUSD to USDC).

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _cofiIn | uint256 | The amount of cofi tokens to redeem. |
| _cofi | address | The cofi token to redeem. |
| _depositFrom | address | The account to deposit cofi tokens from. |
| _recipient | address | The account receiving underlying tokens. |

### _cofiToUnderlying

```solidity
function _cofiToUnderlying(uint256 _cofiIn, address _cofi, address _depositFrom, address _recipient) internal returns (uint256 burnAfterFee)
```

### getEstimatedCofiOut

```solidity
function getEstimatedCofiOut(uint256 _tokensIn, address _token, address _cofi) external view returns (uint256 cofiOut)
```

Returns the estimated cofi tokens received from the amount of entry tokens deposited.

### getEstimatedTokensOut

```solidity
function getEstimatedTokensOut(uint256 _cofiIn, address _cofi, address _token) external view returns (uint256 cofiOut)
```

Returns the estimated tokens out (incl. ETH) from the amount of cofi tokens deposited.

## SupplyManagerFacet

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Supply Manager Facet
    @notice Admin functions for managing asset params.

### onboardAsset

```solidity
function onboardAsset(address _cofi, address _vault) external returns (bool)
```

_Set cofi token vars first BEFORE onboarding (refer to LibAppStorage.sol)._

### setDecimals

```solidity
function setDecimals(address _asset, uint8 _decimals) external returns (bool)
```

### setMinDeposit

```solidity
function setMinDeposit(address _cofi, uint256 _underlyingInMin) external returns (bool)
```

'minDeposit' applies to the amount of underlying tokens required for deposit.

### setMinWithdraw

```solidity
function setMinWithdraw(address _cofi, uint256 _underlyingOutMin) external returns (bool)
```

'minWithdraw' applies to the amount of underlying tokens redeemed.

### setMintFee

```solidity
function setMintFee(address _cofi, uint256 _amount) external returns (bool)
```

### setMintEnabled

```solidity
function setMintEnabled(address _cofi, uint8 _enabled) external returns (bool)
```

### setRedeemFee

```solidity
function setRedeemFee(address _cofi, uint256 _amount) external returns (bool)
```

### setRedeemEnabled

```solidity
function setRedeemEnabled(address _cofi, uint8 _enabled) external returns (bool)
```

### setServiceFee

```solidity
function setServiceFee(address _cofi, uint256 _amount) external returns (bool)
```

### setSupplyLimit

```solidity
function setSupplyLimit(address _cofi, uint256 _supplyLimit) external returns (bool)
```

### getDecimals

```solidity
function getDecimals(address _asset) external view returns (uint8)
```

### getMinDeposit

```solidity
function getMinDeposit(address _cofi) external view returns (uint256)
```

### getMinWithdraw

```solidity
function getMinWithdraw(address _cofi) external view returns (uint256)
```

### getMintFee

```solidity
function getMintFee(address _cofi) external view returns (uint256)
```

### getMintEnabled

```solidity
function getMintEnabled(address _cofi) external view returns (uint8)
```

### getRedeemFee

```solidity
function getRedeemFee(address _cofi) external view returns (uint256)
```

### getRedeemEnabled

```solidity
function getRedeemEnabled(address _cofi) external view returns (uint8)
```

### getServiceFee

```solidity
function getServiceFee(address _cofi) external view returns (uint256)
```

### getSupplyLimit

```solidity
function getSupplyLimit(address _cofi) external view returns (uint256)
```

### getUnderlying

```solidity
function getUnderlying(address _cofi) external view returns (address)
```

## SwapManagerFacet

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Swap Manager Facet
    @notice Admin functions for managing swap params.

### setSwapProtocol

```solidity
function setSwapProtocol(address _tokenA, address _tokenB, enum SwapProtocol _swapProtocol) external returns (bool)
```

_Sets the swap protocol used to execute a swap between two tokens.
Sets forward and reverse order.
Need to ensure that swap route has been set beforehand._

### setV2Route

```solidity
function setV2Route(address _tokenA, address _tokenMid, address _tokenB, bool[2] _stable) external returns (bool)
```

_Sets UniswapV2 + VelodromeV2 swap routes.
Sets forward and reverse order._

### setV3Route

```solidity
function setV3Route(address _tokenA, uint24 _poolFee1, address _tokenMid, uint24 _poolFee2, address _tokenB) external returns (bool)
```

_Sets UniswapV3 swap routes.
Sets forward and reverse order._

### setSlippage

```solidity
function setSlippage(uint256 _slippage, address _tokenA, address _tokenB) external returns (bool)
```

_Overrides default slippage. To revert to default, set to 0.
Sets slippage for forward and reverse order._

### setWait

```solidity
function setWait(uint256 _wait, address _tokenA, address _tokenB) external returns (bool)
```

_Overrides default wait. To revert to default, set to 0.
Sets wait for forward and reverse order._

### setDefaultSlippage

```solidity
function setDefaultSlippage(uint256 _slippage) external
```

### setDefaultWait

```solidity
function setDefaultWait(uint256 _wait) external
```

### setPriceFeed

```solidity
function setPriceFeed(address _token, address _priceFeed) external returns (bool)
```

Sets Chainlink price oracle used to retrieve prices for swaps.

### getSwapProtocol

```solidity
function getSwapProtocol(address _tokenA, address _tokenB) external view returns (enum SwapProtocol)
```

### getSupportedSwaps

```solidity
function getSupportedSwaps(address _token) external view returns (address[])
```

Returns an array of tokens that are supported for swapping between.
         ETH/wETH are supported for all COFI tokens by default, as well as its current
         underlying token, so the array excludes these.
         E.g., coUSD => [DAI] (+ current underlying USDC) (+ ETH/wETH) are supported
         when minting and burning coUSD via 'enterCofi()' and 'exitCofi()' functions, respectively.
         2nd e.g., coBTC => []. Therfore can only mint coBTC with its underlying (wBTC)
         or ETH/wETH.

### getSwapRouteV2

```solidity
function getSwapRouteV2(address _tokenA, address _tokenB) external view returns (struct SwapRouteV2)
```

### getSwapRouteV3

```solidity
function getSwapRouteV3(address _tokenA, address _tokenB) external view returns (bytes)
```

### getSlippage

```solidity
function getSlippage(address _tokenA, address _tokenB) external view returns (uint256)
```

### getWait

```solidity
function getWait(address _tokenA, address _tokenB) external view returns (uint256)
```

### getDefaultSlippage

```solidity
function getDefaultSlippage() external view returns (uint256)
```

### getDefaultWait

```solidity
function getDefaultWait() external view returns (uint256)
```

### getPriceFeed

```solidity
function getPriceFeed(address _token) external view returns (address)
```

### getAmountOutMin

```solidity
function getAmountOutMin(uint256 _amountIn, address _from, address _to) external view returns (uint256 amountOutMin)
```

Returns the minimum amount received from a swap operation.

### getConversion

```solidity
function getConversion(uint256 _amount, uint256 _fee, address _from, address _to) external view returns (uint256 fromTo)
```

Returns the price of amount '_from' denominated in '_to'.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _amount | uint256 | The amount of from asset to convert from. |
| _fee | uint256 | A custom deduction amount in basis points applied to amount. |
| _from | address | The asset to convert from. |
| _to | address | The asset to convert to. |

### _getForCofi

```solidity
function _getForCofi(address _token) internal view returns (address underlying)
```

## IERC20

### transfer

```solidity
function transfer(address to, uint256 amount) external returns (bool)
```

## IPermit2

### TokenPermissions

```solidity
struct TokenPermissions {
  contract IERC20 token;
  uint256 amount;
}
```

### PermitTransferFrom

```solidity
struct PermitTransferFrom {
  struct IPermit2.TokenPermissions permitted;
  uint256 nonce;
  uint256 deadline;
}
```

### SignatureTransferDetails

```solidity
struct SignatureTransferDetails {
  address to;
  uint256 requestedAmount;
}
```

### permitTransferFrom

```solidity
function permitTransferFrom(struct IPermit2.PermitTransferFrom permit, struct IPermit2.SignatureTransferDetails transferDetails, address owner, bytes signature) external
```

## UniswapSwap

### UNISWAP_V3_ROUTER

```solidity
contract ISwapRouter UNISWAP_V3_ROUTER
```

### WETH

```solidity
contract IWETH WETH
```

### ETH_PRICE_FEED

```solidity
contract AggregatorV3Interface ETH_PRICE_FEED
```

_Leave for reference._

### WETH_DECIMALS

```solidity
uint8 WETH_DECIMALS
```

### TokenInfo

```solidity
struct TokenInfo {
  contract AggregatorV3Interface priceFeed;
  uint8 decimals;
}
```

### path

```solidity
mapping(address => mapping(address => bytes)) path
```

### tokenInfo

```solidity
mapping(address => struct UniswapSwap.TokenInfo) tokenInfo
```

### wait

```solidity
uint256 wait
```

### slippage

```solidity
uint256 slippage
```

### constructor

```solidity
constructor(uint256 _wait, uint256 _slippage) public
```

### exactInput

```solidity
function exactInput(uint256 _amountIn, address _from, address _to) external payable returns (uint256 amountOut)
```

### exactInputETH

```solidity
function exactInputETH(address _to) external payable returns (uint256 amountOut)
```

### fallback

```solidity
fallback() external payable
```

### unwrap

```solidity
function unwrap(uint256 _amountIn, address _recipient) external payable
```

### setPath

```solidity
function setPath(address _tokenA, uint24 _poolFee1, address _mid, uint24 _poolFee2, address _tokenB) external returns (bool)
```

### setDecimals

```solidity
function setDecimals(address _token, uint8 _decimals) external returns (bool)
```

### setPriceFeed

```solidity
function setPriceFeed(address _token, contract AggregatorV3Interface _priceFeed) external returns (bool)
```

### getLatestPrice

```solidity
function getLatestPrice(address _from, address _to) public view returns (uint256 fromUSD, uint256 toUSD, uint256 fromTo)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| fromUSD | uint256 | adjusted to 8 decimals (e.g., $1 = 100_000_000) |
| toUSD | uint256 |  |
| fromTo | uint256 |  |

### getAmountOutMin

```solidity
function getAmountOutMin(uint256 _amountIn, address _from, address _to) public view returns (uint256 amountOutMin)
```

## VelodromeSwap

### VELODROME_V2_ROUTER

```solidity
contract IRouter VELODROME_V2_ROUTER
```

### VELODROME_V2_FACTORY

```solidity
address VELODROME_V2_FACTORY
```

### WETH

```solidity
address WETH
```

### ETH_PRICE_FEED

```solidity
contract AggregatorV3Interface ETH_PRICE_FEED
```

_Leave for reference._

### WETH_DECIMALS

```solidity
uint8 WETH_DECIMALS
```

### Route

```solidity
struct Route {
  address mid;
  bool[2] stable;
}
```

### TokenInfo

```solidity
struct TokenInfo {
  contract AggregatorV3Interface priceFeed;
  uint8 decimals;
}
```

### route

```solidity
mapping(address => mapping(address => struct VelodromeSwap.Route)) route
```

### tokenInfo

```solidity
mapping(address => struct VelodromeSwap.TokenInfo) tokenInfo
```

### wait

```solidity
uint256 wait
```

_Can later move to Route struct._

### slippage

```solidity
uint256 slippage
```

### constructor

```solidity
constructor(uint256 _wait, uint256 _slippage) public
```

### swapExactTokensForTokens

```solidity
function swapExactTokensForTokens(uint256 _amountIn, address _from, address _to) external returns (uint256[] amounts)
```

_Repeat for obtaining DAI._

### setDecimals

```solidity
function setDecimals(address _token, uint8 _decimals) external returns (bool)
```

### setPriceFeed

```solidity
function setPriceFeed(address _token, contract AggregatorV3Interface _priceFeed) external returns (bool)
```

### setRoute

```solidity
function setRoute(address _tokenA, address _mid, address _tokenB, bool[2] _stable) external returns (bool)
```

_Assumes reverse route._

### getRoute

```solidity
function getRoute(address _from, address _to) external view returns (struct VelodromeSwap.Route)
```

### getLatestPrice

```solidity
function getLatestPrice(address _from, address _to) public view returns (uint256 fromUSD, uint256 toUSD, uint256 fromTo)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| fromUSD | uint256 | adjusted to 8 decimals (e.g., $1 = 100_000_000) |
| toUSD | uint256 |  |
| fromTo | uint256 |  |

### getAmountOutMin

```solidity
function getAmountOutMin(uint256 _amountIn, address _from, address _to) public view returns (uint256 amountOutMin)
```

### swapExactETHForTokens

```solidity
function swapExactETHForTokens(address _to) public payable returns (uint256[] amounts)
```

_Repeat for obtaining DAI._

### swapExactTokensForETH

```solidity
function swapExactTokensForETH(uint256 _amountIn, address _from) public returns (uint256[] amounts)
```

### getAmountsOut

```solidity
function getAmountsOut(uint256 _amountIn, address _from, address _to) public view returns (uint256[] amounts)
```

## AaveV3Reinvest

Extended implementation of yield-daddy's ERC4626 for Aave V3 with rewards reinvesting
Reinvests rewards accrued for higher APY

### MIN_AMOUNT_ERROR

```solidity
error MIN_AMOUNT_ERROR()
```

Thrown when reinvested amounts are not enough.

### INVALID_AMOUNT_INPUT_ERROR

```solidity
error INVALID_AMOUNT_INPUT_ERROR()
```

Thrown when legnths mismatch

### INVALID_ACCESS

```solidity
error INVALID_ACCESS()
```

Thrown when trying to call a permissioned function with an invalid access

### REWARDS_NOT_SET

```solidity
error REWARDS_NOT_SET()
```

When rewardsSet is false

### ZERO_ASSETS

```solidity
error ZERO_ASSETS()
```

Thrown when trying to redeem shares worth 0 assets

### DECIMALS_MASK

```solidity
uint256 DECIMALS_MASK
```

### ACTIVE_MASK

```solidity
uint256 ACTIVE_MASK
```

### FROZEN_MASK

```solidity
uint256 FROZEN_MASK
```

### PAUSED_MASK

```solidity
uint256 PAUSED_MASK
```

### SUPPLY_CAP_MASK

```solidity
uint256 SUPPLY_CAP_MASK
```

### SUPPLY_CAP_START_BIT_POSITION

```solidity
uint256 SUPPLY_CAP_START_BIT_POSITION
```

### RESERVE_DECIMALS_START_BIT_POSITION

```solidity
uint256 RESERVE_DECIMALS_START_BIT_POSITION
```

### manager

```solidity
address manager
```

Manager for setting swap routes for harvest()

### rewardsSet

```solidity
bool rewardsSet
```

Check if rewards have been set before harvest() and setRoutes()

### aToken

```solidity
contract ERC20 aToken
```

The Aave aToken contract

### lendingPool

```solidity
contract IPool lendingPool
```

The Aave Pool contract

### rewardsController

```solidity
contract IRewardsController rewardsController
```

The Aave RewardsController contract

### rewardTokens

```solidity
address[] rewardTokens
```

The Aave reward tokens for a pool

### swapInfoMap

```solidity
mapping(address => struct AaveV3Reinvest.swapInfo) swapInfoMap
```

Map rewardToken to its swapInfo for harvest

### SwapInfo

```solidity
struct AaveV3Reinvest.swapInfo SwapInfo
```

Pointer to swapInfo

### swapInfo

Compact struct to make two swaps (on Uniswap v2)
A => B (using pair1) then B => asset (of Wrapper) (using pair2)

```solidity
struct swapInfo {
  address token;
  address pair1;
  address pair2;
}
```

### authorized

```solidity
mapping(address => uint8) authorized
```

### constructor

```solidity
constructor(contract ERC20 asset_, contract ERC20 aToken_, contract IPool lendingPool_, contract IRewardsController rewardsController_, address manager_) public
```

Construct a new AaveV3ERC4626Reinvest

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset_ | contract ERC20 | The underlying asset |
| aToken_ | contract ERC20 | The Aave aToken contract |
| lendingPool_ | contract IPool | The Aave Pool contract |
| rewardsController_ | contract IRewardsController | The Aave RewardsController contract |
| manager_ | address | The manager for setting swap routes for harvest() |

### setRewards

```solidity
function setRewards() external returns (address[] tokens)
```

Get all rewards from AAVE market

_Call before setting routes
Requires manual management of Routes_

### setRoutes

```solidity
function setRoutes(address rewardToken_, address token_, address pair1_, address pair2_) external
```

Set swap routes for selling rewards

_Set route for each rewardToken separately
Setting wrong addresses here will revert harvest() calls_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rewardToken_ | address | The reward token address |
| token_ | address | The token to swap rewardToken_ to |
| pair1_ | address | The first pair to swap rewardToken_ to token_ |
| pair2_ | address | The second pair to swap token_ to asset_ |

### harvest

```solidity
function harvest(uint256[] minAmounts_) external
```

Claims liquidity mining rewards from Aave and sends it to this Vault

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| minAmounts_ | uint256[] | The minimum amounts of underlying asset to receive for each reward token |

### swapRewards

```solidity
function swapRewards(address rewardToken_, uint256 earned_, uint256 minAmount_) internal
```

Swap reward token for underlying asset

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| rewardToken_ | address | The reward token address |
| earned_ | uint256 | The amount of reward token to swap |
| minAmount_ | uint256 | The minimum amount of underlying asset to receive |

### getAllRewardsAccrued

```solidity
function getAllRewardsAccrued() external view returns (address[] rewardList, uint256[] claimedAmounts)
```

Check how much rewards are available to claim, useful before harvest()

### recoverERC20

```solidity
function recoverERC20(address token, uint256 amount, address recipient) external returns (bool)
```

### toggleAuthorized

```solidity
function toggleAuthorized(address account) external returns (bool)
```

### deposit

```solidity
function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares)
```

### mint

```solidity
function mint(uint256 shares, address receiver) public virtual returns (uint256 assets)
```

### withdraw

```solidity
function withdraw(uint256 assets_, address receiver_, address owner_) public virtual returns (uint256 shares)
```

### redeem

```solidity
function redeem(uint256 shares_, address receiver_, address owner_) public virtual returns (uint256 assets)
```

### totalAssets

```solidity
function totalAssets() public view virtual returns (uint256)
```

### afterDeposit

```solidity
function afterDeposit(uint256 assets, uint256) internal virtual
```

### maxDeposit

```solidity
function maxDeposit(address) public view virtual returns (uint256)
```

### maxMint

```solidity
function maxMint(address) public view virtual returns (uint256)
```

### maxWithdraw

```solidity
function maxWithdraw(address owner_) public view virtual returns (uint256)
```

### maxRedeem

```solidity
function maxRedeem(address owner) public view virtual returns (uint256)
```

### _vaultName

```solidity
function _vaultName(contract ERC20 asset_) internal view virtual returns (string vaultName)
```

### _vaultSymbol

```solidity
function _vaultSymbol(contract ERC20 asset_) internal view virtual returns (string vaultSymbol)
```

### _getDecimals

```solidity
function _getDecimals(uint256 configData) internal pure returns (uint8)
```

### _getActive

```solidity
function _getActive(uint256 configData) internal pure returns (bool)
```

### _getFrozen

```solidity
function _getFrozen(uint256 configData) internal pure returns (bool)
```

### _getPaused

```solidity
function _getPaused(uint256 configData) internal pure returns (bool)
```

### _getSupplyCap

```solidity
function _getSupplyCap(uint256 configData) internal pure returns (uint256)
```

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

## CompoundV2Reinvest

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
            (Adapted from ZeroPoint Labs).
    @title  CompoundV2Reinvest
    @notice Custom implementation of yield-daddy wrapper with flexible
            reinvesting logic.
    @dev    This is a passthrough wrapper and hence underlying assets reside
            in the respective protocol.

### COMPOUND_ERROR

```solidity
error COMPOUND_ERROR(uint256 errorCode)
```

Thrown when a call to Compound returned an error.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| errorCode | uint256 | The error code returned by Compound |

### MIN_AMOUNT_ERROR

```solidity
error MIN_AMOUNT_ERROR()
```

Thrown when reinvest amount is not enough.

### INVALID_FEE_ERROR

```solidity
error INVALID_FEE_ERROR()
```

Thrown when swap path fee in reinvest is invalid.

### NOT_AUTHORIZED

```solidity
error NOT_AUTHORIZED()
```

Thrown when the caller is not authorized.

### NOT_ADMIN

```solidity
error NOT_ADMIN()
```

Thrown when the caller is not admin.

### NO_ERROR

```solidity
uint256 NO_ERROR
```

### reward

```solidity
contract ERC20 reward
```

The COMP-like token contract

### cToken

```solidity
contract ICERC20 cToken
```

The Compound cToken contract

### comptroller

```solidity
contract IComptroller comptroller
```

The Compound comptroller contract

### swapPath

```solidity
bytes swapPath
```

Pointer to swapInfo

### swapRouter

```solidity
contract ISwapRouter swapRouter
```

### SwapParams

```solidity
struct SwapParams {
  uint256 amountInMin;
  uint256 slippage;
  uint256 wait;
  uint8 enabled;
}
```

### swapParams

```solidity
struct CompoundV2Reinvest.SwapParams swapParams
```

### rewardPriceFeed

```solidity
contract AggregatorV3Interface rewardPriceFeed
```

### wantPriceFeed

```solidity
contract AggregatorV3Interface wantPriceFeed
```

### authorized

```solidity
mapping(address => uint8) authorized
```

### authorizedEnabled

```solidity
uint8 authorizedEnabled
```

### admin

```solidity
mapping(address => uint8) admin
```

### constructor

```solidity
constructor(contract ERC20 _asset, contract ERC20 _reward, contract ICERC20 _cToken, contract AggregatorV3Interface _wantPriceFeed, uint256 _amountInMin, uint256 _slippage, uint256 _wait) public
```

Constructor for the CompoundV2ERC4626Wrapper.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _asset | contract ERC20 | The address of the underlying asset. |
| _reward | contract ERC20 | The address of the reward token. |
| _cToken | contract ICERC20 | The address of the cToken. |
| _wantPriceFeed | contract AggregatorV3Interface |  |
| _amountInMin | uint256 | The min amount of reward to execute swap for. |
| _slippage | uint256 | The max slippage incurred by swap (in basis points). |
| _wait | uint256 | The max wait time for swap execution (in seconds). |

### accrueInterest

```solidity
function accrueInterest() public
```

_Updates value of 'exchangeRateStored()'_

### setRoute

```solidity
function setRoute(uint24 _poolFee1, address _tokenMid, uint24 _poolFee2) external
```

Sets the swap path for reinvesting rewards.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolFee1 | uint24 | Fee for first swap. |
| _tokenMid | address | Token for first swap. |
| _poolFee2 | uint24 | Fee for second swap. |

### harvest

```solidity
function harvest() external returns (uint256 deposited)
```

_Harvest operation accrues interest._

### harvestWithSwap

```solidity
function harvestWithSwap() internal returns (uint256 deposited)
```

Claims liquidity mining rewards from Compound and performs low-lvl swap
        with instant reinvesting.

### flush

```solidity
function flush() public returns (uint256 deposited)
```

Deposits this contract's balance of want into venue.

### getLatestPrice

```solidity
function getLatestPrice() public view returns (uint256 answer)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| answer | uint256 | with 8 decimals |

### claimRewards

```solidity
function claimRewards() external
```

Manually claim rewards.

### recoverERC20

```solidity
function recoverERC20(contract ERC20 _token, uint8 _claimRewards) external
```

Useful for manual rewards reinvesting (executed by receiver).
        where there is a lack of a trusted price feed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _token | contract ERC20 | The ERC20 token to recover. |
| _claimRewards | uint8 | Indicates whether to claim rewards in same tx. |

### setAmountInMin

```solidity
function setAmountInMin(uint256 _amountInMin) external returns (bool)
```

_An extremely small or large number can result in an undesiriable exchange rate._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _amountInMin | uint256 | The min amount of reward asset to be exchanged. |

### setSlippage

```solidity
function setSlippage(uint256 _slippage) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _slippage | uint256 | The slippage tolerance in basis points. |

### setWait

```solidity
function setWait(uint256 _wait) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _wait | uint256 | The wait time for a swap to execute in seconds. |

### setEnabled

```solidity
function setEnabled(uint8 _enabled) external returns (bool)
```

Disables swap route for harvest operation.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _enabled | uint8 | Indicates whether swapping is enabled. |

### setAdmin

```solidity
function setAdmin(address _account, uint8 _enabled) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The account to amend admin status for. |
| _enabled | uint8 | Whether the account has admin status. |

### setAuthorized

```solidity
function setAuthorized(address _account, uint8 _enabled) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The account to provide authorization for. |
| _enabled | uint8 | Whether the account has authorization. |

### setAuthorizedEnabled

```solidity
function setAuthorizedEnabled(uint8 _enabled) external returns (bool)
```

### deposit

```solidity
function deposit(uint256 _assets, address _receiver) public returns (uint256 shares)
```

### mint

```solidity
function mint(uint256 _shares, address _receiver) public returns (uint256 assets)
```

### withdraw

```solidity
function withdraw(uint256 _assets, address _receiver, address _owner) public returns (uint256 shares)
```

### redeem

```solidity
function redeem(uint256 _shares, address _receiver, address _owner) public returns (uint256 assets)
```

### totalAssets

```solidity
function totalAssets() public view virtual returns (uint256)
```

calling 'accrueInterest()' immediately prior.

### beforeWithdraw

```solidity
function beforeWithdraw(uint256 _assets, uint256) internal virtual
```

### afterDeposit

```solidity
function afterDeposit(uint256 _assets, uint256) internal virtual
```

### maxDeposit

```solidity
function maxDeposit(address) public view returns (uint256)
```

### maxMint

```solidity
function maxMint(address) public view returns (uint256)
```

### maxWithdraw

```solidity
function maxWithdraw(address _owner) public view returns (uint256)
```

### maxRedeem

```solidity
function maxRedeem(address _owner) public view returns (uint256)
```

### _vaultName

```solidity
function _vaultName(contract ERC20 _asset) internal view virtual returns (string vaultName)
```

### _vaultSymbol

```solidity
function _vaultSymbol(contract ERC20 _asset) internal view virtual returns (string vaultSymbol)
```

### onlyAdmin

```solidity
modifier onlyAdmin()
```

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

_Add to prevent state change outside of app context._

### onlyAuthorizedOrAdmin

```solidity
modifier onlyAuthorizedOrAdmin()
```

## YearnV2

a contract for providing Yearn V2 contracts with an ERC-4626-compliant interface
        Developed for Resonate.

_The initial deposit to this contract should be made immediately following deployment_

### registry

```solidity
contract IYearnRegistry registry
```

NB: If this is deployed on non-Mainnet chains
    Then this address may be different

### yVault

```solidity
contract VaultAPI yVault
```

### token

```solidity
address token
```

### _decimals

```solidity
uint8 _decimals
```

Decimals for native token

### flushReceiver

```solidity
address flushReceiver
```

### authorized

```solidity
mapping(address => uint8) authorized
```

### authorizedEnabled

```solidity
uint8 authorizedEnabled
```

### constructor

```solidity
constructor(contract VaultAPI _vault) public
```

### vault

```solidity
function vault() external view returns (address)
```

### migrate

```solidity
function migrate() external
```

_Verify that current Yearn vault is latest with Yearn registry. If not, migrate funds automatically_

### vaultTotalSupply

```solidity
function vaultTotalSupply() external view returns (uint256)
```

### setAuthorized

```solidity
function setAuthorized(address _account, uint8 _enabled) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The account to provide authorization for. |
| _enabled | uint8 | Whether the account has authorization. |

### setAuthorizedEnabled

```solidity
function setAuthorizedEnabled(uint8 _enabled) external returns (bool)
```

### setFlushReceiver

```solidity
function setFlushReceiver(address _receiver) external returns (bool)
```

### recoverERC20

```solidity
function recoverERC20(contract IERC20 _token) external
```

Useful for manual rewards reinvesting (executed by receiver).
        where there is a lack of a trusted price feed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _token | contract IERC20 | The ERC20 token to recover. |

### deposit

```solidity
function deposit(uint256 assets, address receiver) public returns (uint256 shares)
```

_See {IERC4626-deposit}._

### mint

```solidity
function mint(uint256 shares, address receiver) public returns (uint256 assets)
```

_See {IERC4626-mint}.

As opposed to {deposit}, minting is allowed even if the vault is in a state where the price of a share is zero.
In this case, the shares will be minted without requiring any assets to be deposited._

### withdraw

```solidity
function withdraw(uint256 assets, address receiver, address _owner) public returns (uint256 shares)
```

### redeem

```solidity
function redeem(uint256 shares, address receiver, address _owner) public returns (uint256 assets)
```

### harvest

```solidity
function harvest() public returns (uint256 deposited)
```

### totalAssets

```solidity
function totalAssets() public view returns (uint256)
```

_See {IERC4626-totalAssets}._

### convertToShares

```solidity
function convertToShares(uint256 assets) public view returns (uint256)
```

_See {IERC4626-convertToShares}._

### convertToAssets

```solidity
function convertToAssets(uint256 shares) public view returns (uint256 assets)
```

_See {IERC4626-convertToAssets}._

### getFreeFunds

```solidity
function getFreeFunds() public view virtual returns (uint256)
```

### previewDeposit

```solidity
function previewDeposit(uint256 assets) public view returns (uint256)
```

_See {IERC4626-previewDeposit}._

### previewWithdraw

```solidity
function previewWithdraw(uint256 assets) public view returns (uint256)
```

_See {IERC4626-previewWithdraw}._

### previewMint

```solidity
function previewMint(uint256 shares) public view returns (uint256)
```

_See {IERC4626-previewMint}._

### previewRedeem

```solidity
function previewRedeem(uint256 shares) public view returns (uint256)
```

_See {IERC4626-previewRedeem}._

### maxDeposit

```solidity
function maxDeposit(address) public view returns (uint256)
```

_See {IERC4626-maxDeposit}._

### maxMint

```solidity
function maxMint(address _account) public view returns (uint256)
```

### maxWithdraw

```solidity
function maxWithdraw(address _owner) public view returns (uint256)
```

### maxRedeem

```solidity
function maxRedeem(address _owner) public view returns (uint256)
```

### _deposit

```solidity
function _deposit(uint256 amount, address receiver, address depositor) internal returns (uint256 deposited, uint256 mintedShares)
```

### _flush

```solidity
function _flush(uint256 amount) internal returns (uint256 deposited, uint256 mintedShares)
```

### _withdraw

```solidity
function _withdraw(uint256 amount, address receiver, address sender) internal returns (uint256 assets, uint256 shares)
```

### _redeem

```solidity
function _redeem(uint256 shares, address receiver, address sender) internal returns (uint256 assets, uint256 sharesBurnt)
```

### convertAssetsToYearnShares

```solidity
function convertAssetsToYearnShares(uint256 assets) internal view returns (uint256 yShares)
```

VIEW METHODS

### convertYearnSharesToAssets

```solidity
function convertYearnSharesToAssets(uint256 yearnShares) internal view returns (uint256 assets)
```

### convertSharesToYearnShares

```solidity
function convertSharesToYearnShares(uint256 shares) internal view returns (uint256 yShares)
```

### allowance

```solidity
function allowance(address _owner, address spender) public view virtual returns (uint256)
```

### balanceOf

```solidity
function balanceOf(address account) public view virtual returns (uint256)
```

### name

```solidity
function name() public view virtual returns (string)
```

### symbol

```solidity
function symbol() public view virtual returns (string)
```

### totalSupply

```solidity
function totalSupply() public view virtual returns (uint256)
```

### onlyAdmin

```solidity
modifier onlyAdmin()
```

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

_Add to prevent operation outside of app context._

## YearnV2StakingRewards

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author The Stoa Corporation Ltd. (Adapted from RobAnon, 0xTraub, 0xTinder).
    @title  YearnV2StakingRewards
    @notice Provides 4626-compatibility and functions for reinvesting
            staking rewards.
    @dev    This is a passthrough wrapper and hence underlying assets reside
            in the respective protocol.

### registry

```solidity
contract IYearnRegistry registry
```

### yVault

```solidity
contract VaultAPI yVault
```

### yVaultReward

```solidity
contract VaultAPI yVaultReward
```

### stakingRewards

```solidity
contract IStakingRewards stakingRewards
```

### stakingRewardsZap

```solidity
contract IStakingRewardsZap stakingRewardsZap
```

### rewardPriceFeed

```solidity
contract AggregatorV3Interface rewardPriceFeed
```

### wantPriceFeed

```solidity
contract AggregatorV3Interface wantPriceFeed
```

### swapRouter

```solidity
contract ISwapRouter swapRouter
```

### preemptiveHarvestEnabled

```solidity
uint8 preemptiveHarvestEnabled
```

### SwapParams

```solidity
struct SwapParams {
  uint256 getRewardMin;
  uint256 amountInMin;
  uint256 slippage;
  uint256 wait;
  uint24 poolFee;
  uint8 enabled;
}
```

### swapParams

```solidity
struct YearnV2StakingRewards.SwapParams swapParams
```

### authorized

```solidity
mapping(address => uint8) authorized
```

### authorizedEnabled

```solidity
uint8 authorizedEnabled
```

### admin

```solidity
mapping(address => uint8) admin
```

### rewardShareReceiver

```solidity
address rewardShareReceiver
```

### constructor

```solidity
constructor(contract VaultAPI _vault, contract VaultAPI _rewardVault, contract IStakingRewards _stakingRewards, contract AggregatorV3Interface _wantPriceFeed, uint256 _getRewardMin, uint256 _amountInMin, uint256 _slippage, uint256 _wait, uint24 _poolFee, uint8 _enabled) public
```

_Ensure to set 'rewardShareReceiver' after deploying._

### vault

```solidity
function vault() external view returns (address)
```

### vaultTotalSupply

```solidity
function vaultTotalSupply() external view returns (uint256)
```

_This number will be different from this token's totalSupply._

### harvest

```solidity
function harvest() public returns (uint256 deposited)
```

### harvestWithSwap

```solidity
function harvestWithSwap() internal returns (uint256 deposited)
```

### swapExactInputSingle

```solidity
function swapExactInputSingle(uint256 _amountIn) internal returns (uint256 amountOut)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _amountIn | uint256 | The amount of reward asset to swap for want. |

### getLatestPrice

```solidity
function getLatestPrice() public view returns (uint256 answer)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| answer | uint256 | with 8 decimals |

### claimRewards

```solidity
function claimRewards() external
```

Manually claim rewards.

### recoverERC20

```solidity
function recoverERC20(contract IERC20 _token, uint8 _claimRewards) external
```

Useful for manual rewards reinvesting (executed by receiver).
        where there is a lack of a trusted price feed.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _token | contract IERC20 | The ERC20 token to recover. |
| _claimRewards | uint8 | Whether to claim rewards in same tx. |

### flush

```solidity
function flush() public returns (uint256 deposited)
```

Deposits this contract's balance of want into venue.

_Need to mint reward shares to receiver (in COFI's conetxt, the diamond contract).
        This ensures yield from rewards is reflected in the rebasing token rather than shares._

### setGetRewardMin

```solidity
function setGetRewardMin(uint256 _getRewardMin) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _getRewardMin | uint256 | The minimum amount of rewards to claim from the staking contract. |

### setAmountInMin

```solidity
function setAmountInMin(uint256 _amountInMin) external returns (bool)
```

_Extremely small Uniswap trades can incur high slippage, hence important to set this_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _amountInMin | uint256 | The minimum amount of reward assets to initiate a swap. |

### setSlippage

```solidity
function setSlippage(uint256 _slippage) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _slippage | uint256 | The maximum amount of slippage a swap can incur (in basis points). |

### setWait

```solidity
function setWait(uint256 _wait) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _wait | uint256 | The maximum wait time for a swap to execute (in seconds). |

### setPoolFee

```solidity
function setPoolFee(uint24 _poolFee) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _poolFee | uint24 | Identifier for the Uniswap pool to exchange through. |

### setEnabled

```solidity
function setEnabled(uint8 _enabled) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _enabled | uint8 | Indicates whether swapping is enabled. |

### setPreemptiveHarvest

```solidity
function setPreemptiveHarvest(uint8 _enabled) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _enabled | uint8 | Indicates whether to preemptively harves given the relevant function call. |

### setAdmin

```solidity
function setAdmin(address _account, uint8 _enabled) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The account to amend admin status for. |
| _enabled | uint8 | Whether the account has admin status. |

### setAuthorized

```solidity
function setAuthorized(address _account, uint8 _enabled) external returns (bool)
```

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _account | address | The account to provide authorization for. |
| _enabled | uint8 | Whether the account has authorization. |

### setAuthorizedEnabled

```solidity
function setAuthorizedEnabled(uint8 _enabled) external returns (bool)
```

### setRewardShareReceiver

```solidity
function setRewardShareReceiver(address _account) external returns (bool)
```

The rewardShareReceiver should be tha account owning share tokens.
         "reward shares" are shares received by investing wants received from rewards
         into the vault (e.g., yvUSDC).

### deposit

```solidity
function deposit(uint256 _assets, address _receiver) public returns (uint256 shares)
```

### mint

```solidity
function mint(uint256 _shares, address _receiver) public returns (uint256 assets)
```

### withdraw

```solidity
function withdraw(uint256 _assets, address _receiver, address _owner) public returns (uint256 shares)
```

### redeem

```solidity
function redeem(uint256 _shares, address _receiver, address _owner) public returns (uint256 assets)
```

### maxDeposit

```solidity
function maxDeposit(address) public view returns (uint256)
```

_See {IERC4626-maxDeposit}._

### maxMint

```solidity
function maxMint(address _account) public view returns (uint256)
```

### maxWithdraw

```solidity
function maxWithdraw(address _owner) public view returns (uint256)
```

### maxRedeem

```solidity
function maxRedeem(address _owner) public view returns (uint256)
```

### _deposit

```solidity
function _deposit(uint256 _amount, address _receiver, address _depositor) internal returns (uint256 deposited, uint256 mintedShares)
```

### _doRewardDeposit

```solidity
function _doRewardDeposit(uint256 _amount, address _receiver) internal returns (uint256 deposited, uint256 mintedShares)
```

Deposit want obtained from reward (e.g., USDC received from swapping OP).

### _withdraw

```solidity
function _withdraw(uint256 _amount, address _receiver, address _sender) internal returns (uint256 assets, uint256 shares)
```

### _redeem

```solidity
function _redeem(uint256 _shares, address _receiver, address _sender) internal returns (uint256 assets, uint256 sharesBurnt)
```

### totalAssets

```solidity
function totalAssets() public view returns (uint256)
```

_See {IERC4626-totalAssets}._

### convertToShares

```solidity
function convertToShares(uint256 _assets) public view returns (uint256)
```

### convertToAssets

```solidity
function convertToAssets(uint256 _shares) public view returns (uint256 assets)
```

### convertToRewardAssets

```solidity
function convertToRewardAssets(uint256 _shares) public view returns (uint256 assets)
```

### getFreeFunds

```solidity
function getFreeFunds() public view virtual returns (uint256)
```

### getFreeRewardFunds

```solidity
function getFreeRewardFunds() public view virtual returns (uint256)
```

### previewDeposit

```solidity
function previewDeposit(uint256 _assets) public view returns (uint256)
```

### previewWithdraw

```solidity
function previewWithdraw(uint256 _assets) public view returns (uint256)
```

### previewMint

```solidity
function previewMint(uint256 _shares) public view returns (uint256)
```

### previewRedeem

```solidity
function previewRedeem(uint256 _shares) public view returns (uint256)
```

### previewRedeemReward

```solidity
function previewRedeemReward(uint256 _shares) public view returns (uint256)
```

### convertAssetsToYearnShares

```solidity
function convertAssetsToYearnShares(uint256 _assets) internal view returns (uint256 yShares)
```

### convertYearnSharesToAssets

```solidity
function convertYearnSharesToAssets(uint256 _yearnShares) internal view returns (uint256 assets)
```

_yvTokens held in staking rewards contract_

### convertYearnRewardSharesToAssets

```solidity
function convertYearnRewardSharesToAssets(uint256 _yearnShares) internal view returns (uint256 assets)
```

_Added function for rewards_

### convertSharesToYearnShares

```solidity
function convertSharesToYearnShares(uint256 _shares) internal view returns (uint256 yearnShares)
```

### allowance

```solidity
function allowance(address _owner, address _spender) public view virtual returns (uint256)
```

### balanceOf

```solidity
function balanceOf(address account) public view virtual returns (uint256)
```

### name

```solidity
function name() public view virtual returns (string)
```

### symbol

```solidity
function symbol() public view virtual returns (string)
```

### totalSupply

```solidity
function totalSupply() public view virtual returns (uint256)
```

### preemptivelyHarvest

```solidity
modifier preemptivelyHarvest()
```

### onlyAdmin

```solidity
modifier onlyAdmin()
```

### onlyAuthorized

```solidity
modifier onlyAuthorized()
```

_Add to prevent operation outside of app context._

## IPool

Defines the basic interface for an Aave Pool.

### ReserveConfigurationMap

```solidity
struct ReserveConfigurationMap {
  uint256 data;
}
```

### ReserveData

```solidity
struct ReserveData {
  struct IPool.ReserveConfigurationMap configuration;
  uint128 liquidityIndex;
  uint128 currentLiquidityRate;
  uint128 variableBorrowIndex;
  uint128 currentVariableBorrowRate;
  uint128 currentStableBorrowRate;
  uint40 lastUpdateTimestamp;
  uint16 id;
  address aTokenAddress;
  address stableDebtTokenAddress;
  address variableDebtTokenAddress;
  address interestRateStrategyAddress;
  uint128 accruedToTreasury;
  uint128 unbacked;
  uint128 isolationModeTotalDebt;
}
```

### supply

```solidity
function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external
```

Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
- E.g. User supplies 100 USDC and gets in return 100 aUSDC

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the underlying asset to supply |
| amount | uint256 | The amount to be supplied |
| onBehalfOf | address | The address that will receive the aTokens, same as msg.sender if the user wants to receive them on his own wallet, or a different address if the beneficiary of aTokens is a different wallet |
| referralCode | uint16 | Code used to register the integrator originating the operation, for potential rewards. 0 if the action is executed directly by the user, without any middle-man |

### withdraw

```solidity
function withdraw(address asset, uint256 amount, address to) external returns (uint256)
```

Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the underlying asset to withdraw |
| amount | uint256 | The underlying amount to be withdrawn - Send the value type(uint256).max in order to withdraw the whole aToken balance |
| to | address | The address that will receive the underlying, same as msg.sender if the user wants to receive it on his own wallet, or a different address if the beneficiary is a different wallet |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | The final amount withdrawn |

### getReserveData

```solidity
function getReserveData(address asset) external view returns (struct IPool.ReserveData)
```

Returns the state and configuration of the reserve

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The address of the underlying asset of the reserve |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | struct IPool.ReserveData | The state and configuration data of the reserve |

## IRewardsController

Defines the basic interface for a Rewards Controller.

### getAllUserRewards

```solidity
function getAllUserRewards(address[] assets, address user) external view returns (address[] rewardsList, uint256[] unclaimedAmounts)
```

### getRewardsByAsset

```solidity
function getRewardsByAsset(address asset) external view returns (address[])
```

_Returns the list of available reward token addresses of an incentivized asset_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| asset | address | The incentivized asset |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address[] | List of rewards addresses of the input asset |

### claimAllRewards

```solidity
function claimAllRewards(address[] assets, address to) external returns (address[] rewardsList, uint256[] claimedAmounts)
```

_Claims all rewards for a user to the desired address, on all the assets of the pool, accumulating the pending rewards_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| assets | address[] | The list of assets to check eligible distributions before claiming rewards |
| to | address | The address that will be receiving the rewards |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| rewardsList | address[] | List of addresses of the reward tokens |
| claimedAmounts | uint256[] | List that contains the claimed amount per reward, following same order as "rewardList" |

## IStargateRouter

### lzTxObj

```solidity
struct lzTxObj {
  uint256 dstGasForCall;
  uint256 dstNativeAmount;
  bytes dstNativeAddr;
}
```

### addLiquidity

```solidity
function addLiquidity(uint256 _poolId, uint256 _amountLD, address _to) external
```

### swap

```solidity
function swap(uint16 _dstChainId, uint256 _srcPoolId, uint256 _dstPoolId, address payable _refundAddress, uint256 _amountLD, uint256 _minAmountLD, struct IStargateRouter.lzTxObj _lzTxParams, bytes _to, bytes _payload) external payable
```

### redeemRemote

```solidity
function redeemRemote(uint16 _dstChainId, uint256 _srcPoolId, uint256 _dstPoolId, address payable _refundAddress, uint256 _amountLP, uint256 _minAmountLD, bytes _to, struct IStargateRouter.lzTxObj _lzTxParams) external payable
```

### instantRedeemLocal

```solidity
function instantRedeemLocal(uint16 _srcPoolId, uint256 _amountLP, address _to) external returns (uint256)
```

### redeemLocal

```solidity
function redeemLocal(uint16 _dstChainId, uint256 _srcPoolId, uint256 _dstPoolId, address payable _refundAddress, uint256 _amountLP, bytes _to, struct IStargateRouter.lzTxObj _lzTxParams) external payable
```

### sendCredits

```solidity
function sendCredits(uint16 _dstChainId, uint256 _srcPoolId, uint256 _dstPoolId, address payable _refundAddress) external payable
```

### quoteLayerZeroFee

```solidity
function quoteLayerZeroFee(uint16 _dstChainId, uint8 _functionType, bytes _toAddress, bytes _transferAndCallPayload, struct IStargateRouter.lzTxObj _lzTxParams) external view returns (uint256, uint256)
```

## ISwap

### getA

```solidity
function getA() external view returns (uint256)
```

### getToken

```solidity
function getToken(uint8 index) external view returns (contract IERC20)
```

### getTokenIndex

```solidity
function getTokenIndex(address tokenAddress) external view returns (uint8)
```

### getTokenBalance

```solidity
function getTokenBalance(uint8 index) external view returns (uint256)
```

### getVirtualPrice

```solidity
function getVirtualPrice() external view returns (uint256)
```

### isGuarded

```solidity
function isGuarded() external view returns (bool)
```

### calculateSwap

```solidity
function calculateSwap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx) external view returns (uint256)
```

### calculateTokenAmount

```solidity
function calculateTokenAmount(address account, uint256[] amounts, bool deposit) external view returns (uint256)
```

### calculateRemoveLiquidity

```solidity
function calculateRemoveLiquidity(uint256 amount) external view returns (uint256[])
```

### calculateRemoveLiquidityOneToken

```solidity
function calculateRemoveLiquidityOneToken(address account, uint256 tokenAmount, uint8 tokenIndex) external view returns (uint256 availableTokenAmount)
```

### initialize

```solidity
function initialize(contract IERC20[] pooledTokens, uint8[] decimals, string lpTokenName, string lpTokenSymbol, uint256 a, uint256 fee, uint256 adminFee, uint256 withdrawFee) external
```

### swap

```solidity
function swap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline) external returns (uint256)
```

### addLiquidity

```solidity
function addLiquidity(uint256[] amounts, uint256 minToMint, uint256 deadline) external returns (uint256)
```

### removeLiquidity

```solidity
function removeLiquidity(uint256 amount, uint256[] minAmounts, uint256 deadline) external returns (uint256[])
```

### removeLiquidityOneToken

```solidity
function removeLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex, uint256 minAmount, uint256 deadline) external returns (uint256)
```

### removeLiquidityImbalance

```solidity
function removeLiquidityImbalance(uint256[] amounts, uint256 maxBurnAmount, uint256 deadline) external returns (uint256)
```

### updateUserWithdrawFee

```solidity
function updateUserWithdrawFee(address recipient, uint256 transferAmount) external
```

## ICERC20

### mint

```solidity
function mint(uint256 underlyingAmount) external virtual returns (uint256)
```

### underlying

```solidity
function underlying() external view virtual returns (contract ERC20)
```

### getCash

```solidity
function getCash() external view virtual returns (uint256)
```

### totalBorrows

```solidity
function totalBorrows() external view virtual returns (uint256)
```

### totalReserves

```solidity
function totalReserves() external view virtual returns (uint256)
```

### exchangeRateStored

```solidity
function exchangeRateStored() external view virtual returns (uint256)
```

### accrualBlockNumber

```solidity
function accrualBlockNumber() external view virtual returns (uint256)
```

### redeemUnderlying

```solidity
function redeemUnderlying(uint256 underlyingAmount) external virtual returns (uint256)
```

### balanceOfUnderlying

```solidity
function balanceOfUnderlying(address) external virtual returns (uint256)
```

### reserveFactorMantissa

```solidity
function reserveFactorMantissa() external view virtual returns (uint256)
```

### interestRateModel

```solidity
function interestRateModel() external view virtual returns (contract IInterestRateModel)
```

### initialExchangeRateMantissa

```solidity
function initialExchangeRateMantissa() external view virtual returns (uint256)
```

### exchangeRateCurrent

```solidity
function exchangeRateCurrent() external virtual returns (uint256)
```

### accrueInterest

```solidity
function accrueInterest() external virtual returns (uint256)
```

## IComptroller

### getAllMarkets

```solidity
function getAllMarkets() external view returns (contract ICERC20[])
```

### allMarkets

```solidity
function allMarkets(uint256 index) external view returns (contract ICERC20)
```

### claimComp

```solidity
function claimComp(address holder) external
```

### claimComp

```solidity
function claimComp(address holder, contract ICERC20[] cTokens) external
```

### mintGuardianPaused

```solidity
function mintGuardianPaused(contract ICERC20 cToken) external view returns (bool)
```

### rewardAccrued

```solidity
function rewardAccrued(uint8, address) external view returns (uint256)
```

### enterMarkets

```solidity
function enterMarkets(contract ICERC20[] cTokens) external returns (uint256[])
```

## IInterestRateModel

### getBorrowRate

```solidity
function getBorrowRate(uint256, uint256, uint256) external view returns (uint256)
```

### getSupplyRate

```solidity
function getSupplyRate(uint256, uint256, uint256, uint256) external view returns (uint256)
```

## ISwapRouter

Functions for swapping tokens via Uniswap V3

### ExactInputSingleParams

```solidity
struct ExactInputSingleParams {
  address tokenIn;
  address tokenOut;
  uint24 fee;
  address recipient;
  uint256 deadline;
  uint256 amountIn;
  uint256 amountOutMinimum;
  uint160 sqrtPriceLimitX96;
}
```

### exactInputSingle

```solidity
function exactInputSingle(struct ISwapRouter.ExactInputSingleParams params) external payable returns (uint256 amountOut)
```

Swaps `amountIn` of one token for as much as possible of another token

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| params | struct ISwapRouter.ExactInputSingleParams | The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountOut | uint256 | The amount of the received token |

### ExactInputParams

```solidity
struct ExactInputParams {
  bytes path;
  address recipient;
  uint256 deadline;
  uint256 amountIn;
  uint256 amountOutMinimum;
}
```

### exactInput

```solidity
function exactInput(struct ISwapRouter.ExactInputParams params) external payable returns (uint256 amountOut)
```

Swaps `amountIn` of one token for as much as possible of another along the specified path

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| params | struct ISwapRouter.ExactInputParams | The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountOut | uint256 | The amount of the received token |

### ExactOutputSingleParams

```solidity
struct ExactOutputSingleParams {
  address tokenIn;
  address tokenOut;
  uint24 fee;
  address recipient;
  uint256 deadline;
  uint256 amountOut;
  uint256 amountInMaximum;
  uint160 sqrtPriceLimitX96;
}
```

### exactOutputSingle

```solidity
function exactOutputSingle(struct ISwapRouter.ExactOutputSingleParams params) external payable returns (uint256 amountIn)
```

Swaps as little as possible of one token for `amountOut` of another token

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| params | struct ISwapRouter.ExactOutputSingleParams | The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountIn | uint256 | The amount of the input token |

### ExactOutputParams

```solidity
struct ExactOutputParams {
  bytes path;
  address recipient;
  uint256 deadline;
  uint256 amountOut;
  uint256 amountInMaximum;
}
```

### exactOutput

```solidity
function exactOutput(struct ISwapRouter.ExactOutputParams params) external payable returns (uint256 amountIn)
```

Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| params | struct ISwapRouter.ExactOutputParams | The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountIn | uint256 | The amount of the input token |

## IUniswapV3SwapCallback

Any contract that calls IUniswapV3PoolActions#swap must implement this interface

### uniswapV3SwapCallback

```solidity
function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes data) external
```

Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.

_In the implementation you must pay the pool tokens owed for the swap.
The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
amount0Delta and amount1Delta can both be 0 if no tokens were swapped._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount0Delta | int256 | The amount of token0 that was sent (negative) or must be received (positive) by the pool by the end of the swap. If positive, the callback must send that amount of token0 to the pool. |
| amount1Delta | int256 | The amount of token1 that was sent (negative) or must be received (positive) by the pool by the end of the swap. If positive, the callback must send that amount of token1 to the pool. |
| data | bytes | Any data passed through by the caller via the IUniswapV3PoolActions#swap call |

## IStakingRewards

### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```

### earned

```solidity
function earned(address account) external view returns (uint256)
```

### withdraw

```solidity
function withdraw(uint256 amount) external
```

### getReward

```solidity
function getReward() external
```

### exit

```solidity
function exit() external
```

## IStakingRewardsZap

### zapIn

```solidity
function zapIn(address _targetVault, uint256 _underlyingAmount) external returns (uint256)
```

## IVaultWrapper

### NoAvailableShares

```solidity
error NoAvailableShares()
```

### NotEnoughAvailableSharesForAmount

```solidity
error NotEnoughAvailableSharesForAmount()
```

### SpenderDoesNotHaveApprovalToBurnShares

```solidity
error SpenderDoesNotHaveApprovalToBurnShares()
```

### NotEnoughAvailableAssetsForAmount

```solidity
error NotEnoughAvailableAssetsForAmount()
```

### InvalidMigrationTarget

```solidity
error InvalidMigrationTarget()
```

### MinimumDepositNotMet

```solidity
error MinimumDepositNotMet()
```

### NonZeroArgumentExpected

```solidity
error NonZeroArgumentExpected()
```

### vault

```solidity
function vault() external view returns (address)
```

### vaultTotalSupply

```solidity
function vaultTotalSupply() external view returns (uint256)
```

## StrategyParams

```solidity
struct StrategyParams {
  uint256 performanceFee;
  uint256 activation;
  uint256 debtRatio;
  uint256 minDebtPerHarvest;
  uint256 maxDebtPerHarvest;
  uint256 lastReport;
  uint256 totalDebt;
  uint256 totalGain;
  uint256 totalLoss;
}
```

## IYearnRegistry

### latestVault

```solidity
function latestVault(address asset) external returns (address)
```

## VaultAPI

### name

```solidity
function name() external view returns (string)
```

### symbol

```solidity
function symbol() external view returns (string)
```

### decimals

```solidity
function decimals() external view returns (uint256)
```

### apiVersion

```solidity
function apiVersion() external pure returns (string)
```

### permit

```solidity
function permit(address owner, address spender, uint256 amount, uint256 expiry, bytes signature) external returns (bool)
```

### deposit

```solidity
function deposit() external returns (uint256)
```

### deposit

```solidity
function deposit(uint256 amount) external returns (uint256)
```

### deposit

```solidity
function deposit(uint256 amount, address recipient) external returns (uint256)
```

### withdraw

```solidity
function withdraw() external returns (uint256)
```

### withdraw

```solidity
function withdraw(uint256 maxShares) external returns (uint256)
```

### withdraw

```solidity
function withdraw(uint256 maxShares, address recipient) external returns (uint256)
```

### withdraw

```solidity
function withdraw(uint256 maxShares, address recipient, uint256 maxLoss) external returns (uint256)
```

### token

```solidity
function token() external view returns (address)
```

### strategies

```solidity
function strategies(address _strategy) external view returns (struct StrategyParams)
```

### pricePerShare

```solidity
function pricePerShare() external view returns (uint256)
```

### totalAssets

```solidity
function totalAssets() external view returns (uint256)
```

### depositLimit

```solidity
function depositLimit() external view returns (uint256)
```

### maxAvailableShares

```solidity
function maxAvailableShares() external view returns (uint256)
```

### availableDepositLimit

```solidity
function availableDepositLimit() external view returns (uint256)
```

### creditAvailable

```solidity
function creditAvailable() external view returns (uint256)
```

View how much the Vault would increase this Strategy's borrow limit,
based on its present performance (since its last report). Can be used to
determine expectedReturn in your Strategy.

### debtOutstanding

```solidity
function debtOutstanding() external view returns (uint256)
```

View how much the Vault would like to pull back from the Strategy,
based on its present performance (since its last report). Can be used to
determine expectedReturn in your Strategy.

### expectedReturn

```solidity
function expectedReturn() external view returns (uint256)
```

View how much the Vault expect this Strategy to return at the current
block, based on its present performance (since its last report). Can be
used to determine expectedReturn in your Strategy.

### report

```solidity
function report(uint256 _gain, uint256 _loss, uint256 _debtPayment) external returns (uint256)
```

This is the main contact point where the Strategy interacts with the
Vault. It is critical that this call is handled as intended by the
Strategy. Therefore, this function will be called by BaseStrategy to
make sure the integration is correct.

### revokeStrategy

```solidity
function revokeStrategy() external
```

This function should only be used in the scenario where the Strategy is
being retired but no migration of the positions are possible, or in the
extreme scenario that the Strategy needs to be put into "Emergency Exit"
mode in order for it to exit as quickly as possible. The latter scenario
could be for any reason that is considered "critical" that the Strategy
exits its position as fast as possible, such as a sudden change in
market conditions leading to losses, or an imminent failure in an
external dependency.

### governance

```solidity
function governance() external view returns (address)
```

View the governance address of the Vault to assert privileged functions
can only be called by governance. The Strategy serves the Vault, so it
is subject to governance defined by the Vault.

### management

```solidity
function management() external view returns (address)
```

View the management address of the Vault to assert privileged functions
can only be called by management. The Strategy serves the Vault, so it
is subject to management defined by the Vault.

### guardian

```solidity
function guardian() external view returns (address)
```

View the guardian address of the Vault to assert privileged functions
can only be called by guardian. The Strategy serves the Vault, so it
is subject to guardian defined by the Vault.

### lockedProfitDegradation

```solidity
function lockedProfitDegradation() external view returns (uint256)
```

### lockedProfitDegration

```solidity
function lockedProfitDegration() external view returns (uint256)
```

### lastReport

```solidity
function lastReport() external view returns (uint256)
```

### lockedProfit

```solidity
function lockedProfit() external view returns (uint256)
```

### totalDebt

```solidity
function totalDebt() external view returns (uint256)
```

## FixedPointMathLib

Arithmetic library with operations for fixed-point numbers.

### WAD

```solidity
uint256 WAD
```

### mulWadDown

```solidity
function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256)
```

### mulWadUp

```solidity
function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256)
```

### divWadDown

```solidity
function divWadDown(uint256 x, uint256 y) internal pure returns (uint256)
```

### divWadUp

```solidity
function divWadUp(uint256 x, uint256 y) internal pure returns (uint256)
```

### mulDivDown

```solidity
function mulDivDown(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z)
```

### mulDivUp

```solidity
function mulDivUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z)
```

### rpow

```solidity
function rpow(uint256 x, uint256 n, uint256 scalar) internal pure returns (uint256 z)
```

### sqrt

```solidity
function sqrt(uint256 x) internal pure returns (uint256 z)
```

## LibCompound

Get up to date cToken data without mutating state.
Forked from Transmissions11 (https://github.com/transmissions11/libcompound) to upgrade version

### RATE_TOO_HIGH

```solidity
error RATE_TOO_HIGH()
```

### viewUnderlyingBalanceOf

```solidity
function viewUnderlyingBalanceOf(contract ICERC20 cToken, address user) internal view returns (uint256)
```

_Make use of "exchangeRateStored()" so as to not break ERC4626-compatibility._

### viewExchangeRate

```solidity
function viewExchangeRate(contract ICERC20 cToken) internal returns (uint256)
```

_Adapted to state modifying function used by Sonne Finance._

## StableMath

### scaleBy

```solidity
function scaleBy(uint256 x, uint256 to, uint256 from) internal pure returns (uint256)
```

_Adjust the scale of an integer_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 |  |
| to | uint256 | Decimals to scale to |
| from | uint256 | Decimals to scale from |

### mulTruncate

```solidity
function mulTruncate(uint256 x, uint256 y) internal pure returns (uint256)
```

_Multiplies two precise units, and then truncates by the full scale_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to multiplication |
| y | uint256 | Right hand input to multiplication |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the two inputs and then dividing by the shared         scale unit |

### mulTruncateScale

```solidity
function mulTruncateScale(uint256 x, uint256 y, uint256 scale) internal pure returns (uint256)
```

_Multiplies two precise units, and then truncates by the given scale. For example,
when calculating 90% of 10e18, (10e18 * 9e17) / 1e18 = (9e36) / 1e18 = 9e18_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to multiplication |
| y | uint256 | Right hand input to multiplication |
| scale | uint256 | Scale unit |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the two inputs and then dividing by the shared         scale unit |

### mulTruncateCeil

```solidity
function mulTruncateCeil(uint256 x, uint256 y) internal pure returns (uint256)
```

_Multiplies two precise units, and then truncates by the full scale, rounding up the result_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to multiplication |
| y | uint256 | Right hand input to multiplication |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the two inputs and then dividing by the shared          scale unit, rounded up to the closest base unit. |

### divPrecisely

```solidity
function divPrecisely(uint256 x, uint256 y) internal pure returns (uint256)
```

_Precisely divides two units, by first scaling the left hand operand. Useful
     for finding percentage weightings, i.e. 8e18/10e18 = 80% (or 8e17)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| x | uint256 | Left hand input to division |
| y | uint256 | Right hand input to division |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Result after multiplying the left operand by the scale, and         executing the division on the right hand input. |

### abs

```solidity
function abs(int256 x) internal pure returns (uint256)
```

## IPair

### getReserves

```solidity
function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)
```

### swap

```solidity
function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes data) external
```

## DexSwap

### swap

```solidity
function swap(uint256 amountIn, address fromToken, address toToken, address pairToken) internal returns (uint256)
```

Swap directly through a Pair

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountIn | uint256 | input amount |
| fromToken | address | address |
| toToken | address | address |
| pairToken | address | Pair used for swap |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | output amount |

### getAmountOut

```solidity
function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256)
```

Given an input amount of an asset and pair reserves, returns maximum output amount of the other asset

_Assumes swap fee is 0.30%_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amountIn | uint256 | input asset |
| reserveIn | uint256 | size of input asset reserve |
| reserveOut | uint256 | size of output asset reserve |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | maximum output amount |

### sortTokens

```solidity
function sortTokens(address tokenA, address tokenB) internal pure returns (address, address)
```

Given two tokens, it'll return the tokens in the right order for the tokens pair

_TokenA must be different from TokenB, and both shouldn't be address(0), no validations_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenA | address | address |
| tokenB | address | address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | sorted tokens |
| [1] | address |  |

## ICOFIMoney

### getPoints

```solidity
function getPoints(address _account, address[] _cofi) external view returns (uint256 pointsTotal)
```

## PointToken

█▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author The Stoa Corporation Ltd.
    @title  Point Token Facet
    @notice Merely provides ERC20 representation and therefore ensures Points are viewable in browser wallet.
            Mint, burn, and transfer methods are effectively renounced.

### constructor

```solidity
constructor(string _name, string _symbol, address _app, address[] _cofi) public
```

### app

```solidity
address app
```

### cofi

```solidity
address[] cofi
```

### admin

```solidity
mapping(address => uint8) admin
```

### balanceOf

```solidity
function balanceOf(address _account) public view returns (uint256)
```

NOTE This contract does not include 'mint'/'burn' functions as does not have a token supply.
            By extension, 'transfer' and 'transferFrom' will not execute.

### setCofi

```solidity
function setCofi(address[] _cofi) external
```

### setApp

```solidity
function setApp(address _app) external
```

### setAdmin

```solidity
function setAdmin(address _account, uint8 _enabled) external
```

### isAdmin

```solidity
modifier isAdmin()
```

## Vault

### constructor

```solidity
constructor(string _name, string _symbol, address _underlying) public
```

## ERC4626

_Implementation of the ERC4626 "Tokenized Vault Standard" as defined in
https://eips.ethereum.org/EIPS/eip-4626[EIP-4626].

This extension allows the minting and burning of "shares" (represented using the ERC20 inheritance) in exchange for
underlying "assets" through standardized {deposit}, {mint}, {redeem} and {burn} workflows. This contract extends
the ERC20 standard. Any additional extensions included along it would affect the "shares" token represented by this
contract and not the "assets" token which is an independent contract.

[CAUTION]
====
In empty (or nearly empty) ERC-4626 vaults, deposits are at high risk of being stolen through frontrunning
with a "donation" to the vault that inflates the price of a share. This is variously known as a donation or inflation
attack and is essentially a problem of slippage. Vault deployers can protect against this attack by making an initial
deposit of a non-trivial amount of the asset, such that price manipulation becomes infeasible. Withdrawals may
similarly be affected by slippage. Users can protect against this attack as well as unexpected slippage in general by
verifying the amount received is as expected, using a wrapper that performs these checks such as
https://github.com/fei-protocol/ERC4626#erc4626router-and-base[ERC4626Router].

Since v4.9, this implementation uses virtual assets and shares to mitigate that risk. The `_decimalsOffset()`
corresponds to an offset in the decimal representation between the underlying asset's decimals and the vault
decimals. This offset also determines the rate of virtual shares to virtual assets in the vault, which itself
determines the initial exchange rate. While not fully preventing the attack, analysis shows that the default offset
(0) makes it non-profitable, as a result of the value being captured by the virtual shares (out of the attacker's
donation) matching the attacker's expected gains. With a larger offset, the attack becomes orders of magnitude more
expensive than it is profitable. More details about the underlying math can be found
xref:erc4626.adoc#inflation-attack[here].

The drawback of this approach is that the virtual shares do capture (a very small) part of the value being accrued
to the vault. Also, if the vault experiences losses, the users try to exit the vault, the virtual shares and assets
will cause the first user to exit to experience reduced losses in detriment to the last users that will experience
bigger losses. Developers willing to revert back to the pre-v4.9 behavior just need to override the
`_convertToShares` and `_convertToAssets` functions.

To learn more, check out our xref:ROOT:erc4626.adoc[ERC-4626 guide].
====

_Available since v4.7.__

### constructor

```solidity
constructor(contract IERC20 asset_) internal
```

_Set the underlying asset contract. This must be an ERC20-compatible contract (ERC20 or ERC777)._

### decimals

```solidity
function decimals() public view virtual returns (uint8)
```

_Decimals are computed by adding the decimal offset on top of the underlying asset's decimals. This
"original" value is cached during construction of the vault contract. If this read operation fails (e.g., the
asset has not been created yet), a default of 18 is used to represent the underlying asset's decimals.

See {IERC20Metadata-decimals}._

### asset

```solidity
function asset() public view virtual returns (address)
```

_See {IERC4626-asset}._

### totalAssets

```solidity
function totalAssets() public view virtual returns (uint256)
```

_See {IERC4626-totalAssets}._

### convertToShares

```solidity
function convertToShares(uint256 assets) public view virtual returns (uint256)
```

_See {IERC4626-convertToShares}._

### convertToAssets

```solidity
function convertToAssets(uint256 shares) public view virtual returns (uint256)
```

_See {IERC4626-convertToAssets}._

### maxDeposit

```solidity
function maxDeposit(address) public view virtual returns (uint256)
```

_See {IERC4626-maxDeposit}._

### maxMint

```solidity
function maxMint(address) public view virtual returns (uint256)
```

_See {IERC4626-maxMint}._

### maxWithdraw

```solidity
function maxWithdraw(address owner) public view virtual returns (uint256)
```

_See {IERC4626-maxWithdraw}._

### maxRedeem

```solidity
function maxRedeem(address owner) public view virtual returns (uint256)
```

_See {IERC4626-maxRedeem}._

### previewDeposit

```solidity
function previewDeposit(uint256 assets) public view virtual returns (uint256)
```

_See {IERC4626-previewDeposit}._

### previewMint

```solidity
function previewMint(uint256 shares) public view virtual returns (uint256)
```

_See {IERC4626-previewMint}._

### previewWithdraw

```solidity
function previewWithdraw(uint256 assets) public view virtual returns (uint256)
```

_See {IERC4626-previewWithdraw}._

### previewRedeem

```solidity
function previewRedeem(uint256 shares) public view virtual returns (uint256)
```

_See {IERC4626-previewRedeem}._

### deposit

```solidity
function deposit(uint256 assets, address receiver) public virtual returns (uint256)
```

_See {IERC4626-deposit}._

### mint

```solidity
function mint(uint256 shares, address receiver) public virtual returns (uint256)
```

_See {IERC4626-mint}.

As opposed to {deposit}, minting is allowed even if the vault is in a state where the price of a share is zero.
In this case, the shares will be minted without requiring any assets to be deposited._

### withdraw

```solidity
function withdraw(uint256 assets, address receiver, address owner) public virtual returns (uint256)
```

_See {IERC4626-withdraw}._

### redeem

```solidity
function redeem(uint256 shares, address receiver, address owner) public virtual returns (uint256)
```

_See {IERC4626-redeem}._

### _convertToShares

```solidity
function _convertToShares(uint256 assets, enum Math.Rounding rounding) internal view virtual returns (uint256)
```

_Internal conversion function (from assets to shares) with support for rounding direction._

### _convertToAssets

```solidity
function _convertToAssets(uint256 shares, enum Math.Rounding rounding) internal view virtual returns (uint256)
```

_Internal conversion function (from shares to assets) with support for rounding direction._

### _deposit

```solidity
function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual
```

_Deposit/mint common workflow._

### _withdraw

```solidity
function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal virtual
```

_Withdraw/redeem common workflow._

### _decimalsOffset

```solidity
function _decimalsOffset() internal view virtual returns (uint8)
```

