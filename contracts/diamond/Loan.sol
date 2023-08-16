// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC4626.sol";

interface IDebtToken {

    function mint(address _account, uint256 _assets) external;

    function burn(address _account, uint256 _assets) external;
}

// To-do:
// * Generalize liquidate() / remove '_account' argument.

contract Loan {

    struct Vault {
        uint256 bal; // [shares]
        uint256 debt; // [assets]
        uint256 deadline;
    }

    // totalSupply - occupied = redeemable.
    struct Collateral {
        uint256 CR;
        uint256 duration;
        // Collateral earmarked for vaults.
        uint256 occupied; // [shares]
        address debt; // [assets]
        address underlying; // [assets]
        address pool;
        Funnel funnel;
    }

    struct Funnel {
        Stake[] stakes;
        // Collateral earmarked for redemptions.
        uint256 loaded; // [assets]
        uint256 loadFromIndex;
    }

    struct Stake {
        uint256 assets;
        address account;
    }

    // E.g., Alice => coUSD => Vault.
    mapping(address => mapping(address => Vault)) vault;
    // E.g., coUSD => Collateral.
    mapping(address => Collateral) collateral;
    // E.g., Alice => coUSD => 1,000.
    mapping(address => mapping(address => uint256)) redeemable; // [assets]

    function deposit(
        address _collateral,
        uint256 _assets
    ) public returns (uint256 shares) {

        // Deposit assets to pool.
        shares = IERC4626(collateral[_collateral].pool).deposit(_assets, address(this));
        // Increase balance by shares received.
        vault[msg.sender][_collateral].bal += shares;
    }

    function withdraw(
        address _collateral,
        uint256 _assets
    ) public returns (uint256 assets) {

        require(
            _assets <= getWithdrawAllowance(msg.sender, _collateral),
            "Amount exceeds withdraw allowance"
        );
        // Get corresponding shares to redeem for withdrawal amount.
        uint256 shares = IERC4626(collateral[_collateral].pool).previewDeposit(_assets);
        // Deduct balance from vault.
        vault[msg.sender][_collateral].bal -= shares;
        // Redeem assets from pool.
        assets = IERC4626(collateral[_collateral].pool).redeem(shares, msg.sender, address(this));
    }

    function borrow(
        address _collateral,
        uint256 _assets
    ) public returns (uint256 deadline) {
        
        require(
            _assets <= getBorrowAllowance(msg.sender, _collateral),
            "Amount exceeds borrow allowance"
        );
        // Set deadline for loan if initiating new.
        if (vault[msg.sender][_collateral].debt == 0) {
            vault[msg.sender][_collateral].deadline =
                block.timestamp + collateral[_collateral].duration;
        }
        deadline = vault[msg.sender][_collateral].deadline;
        // Increase debt of vault.
        vault[msg.sender][_collateral].debt += _assets;
        // Mint tokens to account.
        IDebtToken(collateral[_collateral].debt).mint(msg.sender, _assets);
    }

    function repay(
        address _collateral,
        uint256 _assets
    ) public returns (uint256 outstanding) {
        
        require(vault[msg.sender][_collateral].debt > 0, "Zero debt to repay");
        if (_assets > vault[msg.sender][_collateral].debt) {
            _assets = vault[msg.sender][_collateral].debt;
        }
        // Burn tokens from account.
        IDebtToken(collateral[_collateral].debt).burn(msg.sender, _assets);
        // Reduce debt of vault.
        return vault[msg.sender][_collateral].debt -= _assets;
    }

    function repayWithUnderlying() public {}

    function recycle(
        address _collateral
    ) public returns (uint256 deadline) {

        require(vault[msg.sender][_collateral].debt > 0, "Zero debt to recycle");
        if (
            IERC20(collateral[_collateral].debt).balanceOf(msg.sender) >=
            vault[msg.sender][_collateral].debt
        ) {
            vault[msg.sender][_collateral].deadline =
                block.timestamp + collateral[_collateral].duration;
        }
        return vault[msg.sender][_collateral].deadline;
    }

    function liquidate(
        address _account,
        address _collateral,
        uint256 _deadline
    ) external returns (uint256 liquidated) {

        address[] memory accounts = new address[](1);
        accounts[0] = _account;
        return batchLiquidate(accounts, _collateral, _deadline);
    }

    function batchLiquidate(
        address[] memory _accounts,
        address _collateral,
        uint256 _deadline
    ) public returns (uint256 liquidatedTotal) {

        if (_deadline > block.timestamp) {
            _deadline = block.timestamp;
        }
        uint256 liquidated;
        for(uint i = 0; i < _accounts.length; i++) {
            if(
                // If vault has outstanding debt.
                vault[_accounts[i]][_collateral].debt > 0 ||
                // If vault's deadline has surpassed.
                vault[_accounts[i]][_collateral].deadline < _deadline
            ) {
                // Retrieve debt amount denominated in shares.
                liquidated = IERC4626(collateral[_collateral].pool).previewDeposit(
                    vault[msg.sender][_collateral].debt
                );
                // Reduce account's balance by debt outstanding.
                vault[_accounts[i]][_collateral].bal -= liquidated;
                // Make liquidation amount available for redemptions.
                collateral[_collateral].occupied -= liquidated;
                liquidatedTotal += liquidated;
            }
        }
    }

    /// @notice Stake submission is irreversible.
    function stake(
        address _collateral,
        uint256 _assets
    ) external returns (bool) {

        IDebtToken(collateral[_collateral].debt).burn(msg.sender, _assets);

        Stake memory _stake;
        _stake.assets = _assets;
        _stake.account = msg.sender;
        collateral[_collateral].funnel.stakes.push(_stake);
        return true;
    }

    function loadFunnel(
        address _collateral,
        uint256 _assets
    ) external returns (bool) {

        if(_assets > totalRedeemable(_collateral)) {
            _assets = totalRedeemable(_collateral);
        }
        for(
            uint i = collateral[_collateral].funnel.loadFromIndex;
            i < collateral[_collateral].funnel.stakes.length;
            i++
        ) {
            if (_assets > collateral[_collateral].funnel.stakes[i].assets) {
                // Make full stake amount redeemable.
                redeemable[collateral[_collateral].funnel.stakes[i].account][_collateral]
                    += collateral[_collateral].funnel.stakes[i].assets;
                _assets -= collateral[_collateral].funnel.stakes[i].assets;
            } else {
                // Make partial stake amount redeemable.
                redeemable[collateral[_collateral].funnel.stakes[i].account][_collateral]
                    += _assets;
                // Reduce stake amount to fulfil at most remaining on next execution.
                collateral[_collateral].funnel.stakes[i].assets -= _assets;
                // Ensure to load from this index upon next execution.
                collateral[_collateral].funnel.loadFromIndex = i;
            }
        }
        return true;
    }

    function redeem(
        address _collateral
    ) external {

        IERC4626(collateral[_collateral].pool).redeem(
            // Get shares from redeemable assets.
            IERC4626(collateral[_collateral].pool).previewDeposit(redeemable[msg.sender][_collateral]),
            msg.sender,
            address(this)
        );
        // Reset assets redeemable.
        redeemable[msg.sender][_collateral] = 0;
    }

    function balanceOf(
        address _account,
        address _collateral
    ) public view returns (uint256 assets) {

        return IERC4626(collateral[_collateral].pool).previewRedeem(
            vault[_account][_collateral].bal
        );
    }

    function getWithdrawAllowance(
        address _account,
        address _collateral
    ) public view returns (uint256 allowance) {

        return balanceOf(_account, _collateral) -
            vault[_account][_collateral].debt * collateral[_collateral].CR > 0 ?
                balanceOf(_account, _collateral) -
                    vault[_account][_collateral].debt * collateral[_collateral].CR :
                0;
    }

    function getBorrowAllowance(
        address _account,
        address _collateral
    ) public view returns (uint256 allowance) {
        
        return balanceOf(_account, _collateral) / collateral[_collateral].CR - 
            vault[_account][_collateral].debt > 0 ?
                balanceOf(_account, _collateral) / collateral[_collateral].CR -
                    vault[_account][_collateral].debt :
                0;
    }

    function totalRedeemable(
        address _collateral
    ) public view returns (uint256 assets) {

        return IERC4626(collateral[_collateral].pool).previewRedeem(
            IERC20(collateral[_collateral].pool).totalSupply()
                - collateral[_collateral].occupied
        ) - collateral[_collateral].funnel.loaded;
    }
}