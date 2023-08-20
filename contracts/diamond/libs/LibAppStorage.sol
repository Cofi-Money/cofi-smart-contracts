// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDiamond } from '.././core/libs/LibDiamond.sol';

struct YieldPointsCapture {
    uint256 yield;
    uint256 points;
}

struct RewardStatus {
    uint8   initClaimed;
    uint8   referClaimed;
    uint8   referDisabled;
}

/*//////////////////////////////////////////////////////////////
                    SWAP STRUCT {Update 1}
//////////////////////////////////////////////////////////////*/

struct SwapParams {
    uint256 slippage;
    uint256 wait;
}

/*//////////////////////////////////////////////////////////////
                    LOAN STRUCTS {Update ?}
//////////////////////////////////////////////////////////////*/

// struct Safe {
//     uint256 bal; // [shares]
//     uint256 debt; // [assets]
//     uint256 deadline;
// }

// struct Collateral {
//     uint256 CR;
//     uint256 duration;
//     // Collateral earmarked for vaults.
//     // totalSupply - occupied = redeemable.
//     uint256 occupied; // [shares]
//     address debt; // [assets]
//     address underlying; // [assets]
//     address pool;
//     Funnel funnel;
// }

// struct Funnel {
//     Stake[] stakes;
//     // Collateral earmarked for redemptions.
//     uint256 loaded; // [assets]
//     uint256 loadFromIndex;
// }

// struct Stake {
//     uint256 assets;
//     address account;
// }

// struct RedemptionInfo {
//     uint256 redeemable;
//     uint256 directRedeemAllowance;
// }

struct AppStorage {

    /*//////////////////////////////////////////////////////////////
                        COFI STABLECOIN PARAMS
    //////////////////////////////////////////////////////////////*/

    // E.g., coUSD => (20*10**18) - 1. Applies to underlying token (e.g., USDC).
    mapping(address => uint256) minDeposit;

    // E.g., coUSD => 20*10**18. Applies to underlyingAsset (e.g., DAI).
    mapping(address => uint256) minWithdraw;

    // E.g., coUSD => 10bps. Applies to cofi tokens only.
    mapping(address => uint256) mintFee;

    // E.g., coUSD => 10bps. Applies to cofi tokens only.
    mapping(address => uint256) redeemFee;

    // E.g., coUSD => 1,000bps. Applies to cofi tokens only.
    mapping(address => uint256) serviceFee;

    // E.g., coUSD => 1,000,000bps (100x / 1*10**18 yield earned).
    mapping(address => uint256) pointsRate;

    // E.g., coUSD => 100 USDC. Buffer for migrations. Applies to underlyingAsset.
    /// @dev {Upgrade 1} amends buffer mapping from cofi token to underlying token.
    mapping(address => uint256) buffer;

    // E.g., coUSD => yvDAI; fiETH => maETH; fiBTC => maBTC.
    mapping(address => address) vault;

    // E.g., coUSD => USDC; ETHFI => wETH; BTCFI => wBTC.
    // Need to specify as vault may use different underlying (e.g., USDC-LP).
    mapping(address => address) underlying;

    // E.g., coUSD => 1.
    mapping(address => uint8)   mintEnabled;

    // E.g., coUSD => 1.
    mapping(address => uint8)   redeemEnabled;

    // Decimals of the underlying asset (e.g., USDC => 6).
    mapping(address => uint8)   decimals;

    // E.g., coUSD => 0.
    mapping(address => uint8)   rebasePublic;

    // If rebase operation should harvest vault beforehand.
    mapping(address => uint8)   harvestable;

    /*//////////////////////////////////////////////////////////////
                            REWARDS PARAMS
    //////////////////////////////////////////////////////////////*/

    // Reward for first-time depositors. Setting to 0 deactivates it.
    uint256 initReward;

    // Reward for referrals. Setting to 0 deactivates it.
    uint256 referReward;

    mapping(address => RewardStatus) rewardStatus;

    // Yield points capture (determined via yield earnings from cofi tokens).
    // E.g., Alice => coUSD => YieldPointsCapture.
    mapping(address => mapping(address => YieldPointsCapture)) YPC;

    // External points capture (to yield earnings). Maps to account only (not cofi tokens).
    mapping(address => uint256) XPC;

    /*//////////////////////////////////////////////////////////////
                            ACCESS PARAMS
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint8)   isWhitelisted;

    mapping(address => uint8)   isWhitelister;

    mapping(address => uint8)   isAdmin;

    mapping(address => uint8)   isUpkeep;

    // Gnosis Safe contract.
    address feeCollector;

    address owner;

    address backupOwner;

    uint8 reentrantStatus;

    /*//////////////////////////////////////////////////////////////
                        SWAP PARAMS {Update 1}
    //////////////////////////////////////////////////////////////*/

    // E.g., USDC => DAI => SwapParams.
    mapping(address => mapping(address => SwapParams)) swapParams;

    /*//////////////////////////////////////////////////////////////
                        LOAN PARAMS {Update ?}
    //////////////////////////////////////////////////////////////*/

    // // E.g., Alice => coUSD => Safe.
    // mapping(address => mapping(address => Safe)) safe;

    // // E.g., coUSD => Collateral.
    // mapping(address => Collateral) collateral;

    // // E.g., Alice => coUSD => RedemptionInfo.
    // mapping(address => mapping(address => RedemptionInfo)) redemptionInfo;
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        // bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := 0
        }
    }

    function abs(int256 x_) internal pure returns (uint256) {
        return uint256(x_ >= 0 ? x_ : -x_);
    }
}

contract Modifiers {
    AppStorage internal s;

    modifier isWhitelisted() {
        require(s.isWhitelisted[msg.sender] == 1, 'Caller not whitelisted');
        _;
    }

    modifier minDeposit(uint256 _amount, address _fi) {
        require(
            _amount > s.minDeposit[_fi],
            'Insufficient deposit amount for cofi token'
        );
        _;
    }

    modifier minWithdraw(uint256 _amount, address _fi) {
        require(
            _amount > s.minWithdraw[_fi],
            'Insufficient withdraw amount for cofi token'
        );
        _;
    }

    modifier mintEnabled(address _fi) {
        require(s.mintEnabled[_fi] == 1, 'Mint not enabled for cofi token');
        _;
    }

    modifier redeemEnabled(address _fi) {
        require(s.redeemEnabled[_fi] == 1, 'Redeem not enabled for cofi token');
        _;
    }

    modifier onlyOwner() {
        require(s.owner == msg.sender || s.backupOwner == msg.sender, 'Caller not owner');
        _;
    }
    
    modifier onlyAdmin() {
        require(s.isAdmin[msg.sender] == 1, 'Caller not Admin');
        _;
    }

    modifier onlyWhitelister() {
        require(
            s.isAdmin[msg.sender] == 1 || s.isWhitelister[msg.sender] == 1,
            'Caller not Whitelister');
        _;
    }

    modifier nonReentrant() {
        require(s.reentrantStatus != 2, 'Reentrant call');
        s.reentrantStatus = 2;
        _;
        s.reentrantStatus = 1;
    }
}