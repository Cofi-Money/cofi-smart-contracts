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