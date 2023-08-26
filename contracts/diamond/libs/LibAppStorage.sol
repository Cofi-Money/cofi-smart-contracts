// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDiamond } from '.././core/libs/LibDiamond.sol';

/*//////////////////////////////////////////////////////////////
                        Reward Types
//////////////////////////////////////////////////////////////*/

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
                        Swap Types
//////////////////////////////////////////////////////////////*/

enum SwapProtocol {
    NonExistent,
    /// @dev + UniswapV2. Uses 'route' mapping.
    VelodromeV2,
    /// @dev Uses 'path' mapping.
    UniswapV3
}

struct Route {
    address mid;
    /// @dev If mid = address(0): [false, false] => [false, X] (i.e., 2nd index does not matter).
    bool[2] stable;
}

struct SwapInfo {
    uint256 slippage;
    uint256 wait;
}

struct Vault {
    address vault;
    uint256 allocation; // Basis points.
}

/*//////////////////////////////////////////////////////////////
                    Loan Types {Update ?}
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
                        COFI Stablecoin Params
    //////////////////////////////////////////////////////////////*/

    // E.g., coUSD => (20 * 10 ** decimals of underlying) - 1.
    // Applies to underlying token (e.g., USDC).
    mapping(address => uint256) minDeposit;

    // E.g., coUSD => 20 * 10 ** decimals of underlying.
    // Applies to underlying token (e.g., wETH).
    mapping(address => uint256) minWithdraw;

    // E.g., coUSD => 10bps. Applies to cofi tokens only.
    mapping(address => uint256) mintFee;

    // E.g., coUSD => 10bps. Applies to cofi tokens only.
    mapping(address => uint256) redeemFee;

    // E.g., coUSD => 1,000bps. Applies to cofi tokens only.
    mapping(address => uint256) serviceFee;

    // E.g., coUSD => 1,000,000bps (i.e., 100 points per 1 coUSD earned).
    mapping(address => uint256) pointsRate;

    // E.g., USDC => 100. Buffer for migrations.
    mapping(address => uint256) buffer;

    // E.g., coUSD => yvDAI.
    mapping(address => address) vault;

    // E.g., coUSD => [yvUSDC, wsoUSDC, yvDAI, wsoDAI].
    mapping(address => Vault[]) vaults;

    // E.g., coUSD => DAI.
    mapping(address => address) underlying;

    // E.g., coUSD => 1.
    mapping(address => uint8)   mintEnabled;

    // E.g., coUSD => 1.
    mapping(address => uint8)   redeemEnabled;

    // Decimals of the underlying asset (e.g., USDC => 6).
    mapping(address => uint8)   decimals;

    // Indicates if rebases can be called by any account. E.g., coUSD => 0.
    mapping(address => uint8)   rebasePublic;

    // Indicated if rebase operation should harvest vault beforehand (e.g., swap reward for want).
    mapping(address => uint8)   harvestable;

    /*//////////////////////////////////////////////////////////////
                            Rewards Params
    //////////////////////////////////////////////////////////////*/

    // Reward for first-time depositors. Setting to 0 deactivates it.
    uint256 initReward;

    // Reward for referrals. Setting to 0 deactivates it.
    uint256 referReward;

    mapping(address => RewardStatus) rewardStatus;

    // Yield points capture (determined via yield earnings from cofi tokens).
    // E.g., Alice => coUSD => YieldPointsCapture.
    mapping(address => mapping(address => YieldPointsCapture)) YPC;

    // External points capture (to yield earnings). E.g., Alice => 10,000.
    mapping(address => uint256) XPC;

    /*//////////////////////////////////////////////////////////////
                            Account Params
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
                            Swap Params
    //////////////////////////////////////////////////////////////*/

    // E.g., USDC => DAI => SwapRouter.
    mapping(address => mapping(address => SwapProtocol)) swapProtocol;

    // E.g., USDC => DAI => Route. UniswapV2 (+ VelodromeV2) compatibility.
    mapping(address => mapping(address => Route)) route;

    // E.g., USDC => DAI => path. UniswapV3 compatibility.
    mapping(address => mapping(address => bytes)) path;

    // E.g., USDC => DAI => SwapInfo.
    mapping(address => mapping(address => SwapInfo)) swapInfo;

    // E.g., wETH => [USDC, DAI, wBTC]. Returns array of tokens it can be swapped to.
    mapping(address => address[]) supportedSwaps;

    // E.g., USDC => Chainlink USDC price oracle.
    mapping(address => address) priceFeed;

    // Applies to swap and wrap operations.
    uint256 defaultSlippage;

    uint256 defaultWait;

    /*//////////////////////////////////////////////////////////////
                        Loan Params {Update ?}
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