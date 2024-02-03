// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { PercentageMath } from "../4626-wrappers/libs/PercentageMath.sol";

contract LoanExample is ERC20 {
    using PercentageMath for uint256;

    // Equifax credit score.
    uint256 constant SUBPAR_THRESHOLD = 439;
    uint256 constant FAIR_THRESHOLD = 531;
    uint256 constant GOOD_THRESHOLD = 671;
    uint256 constant EXCELLENT_THRESHOLD = 811;

    struct Account {
        uint256 outstanding;
        uint256 creditScore;
        uint256 deadline;
        bool    active;
    }

    mapping(address => Account) account;

    uint8 private _decimals;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 decimals_
    )   ERC20(_name, _symbol) {
        _decimals = decimals_;
    }

    // Need to set credit score first.
    function getLoanTerms(
        address _account
    )   public view returns (uint256 maxBorrow, uint256 apr, uint256 deadline) {
        if (account[_account].creditScore < SUBPAR_THRESHOLD) {
            // Cannot borrow.
            return (0, 0, 0);
        } else if (account[_account].creditScore < FAIR_THRESHOLD) {
            // Can borrow up to $1,000 at 20% APR for 30 days.
            return (1_000 * 10**uint256(_decimals), 2000, block.timestamp + 30 days);
        } else if (account[_account].creditScore < GOOD_THRESHOLD) {
            // Can borrow up to $5,000 at 10% APR for 90 days.
            return (5_000 * 10**uint56(_decimals), 1000, block.timestamp + 90 days);
        } else if (account[_account].creditScore < EXCELLENT_THRESHOLD) {
            // Can borrow up to $10,000 at 5% APR for 1 year.
            return (10_000 * 10**uint256(_decimals), 500, block.timestamp + 365 days);
        } else {
            // Can borrow up to $20,000 at 2% APR for 2 years.
            return (20_000 * 10**uint256(_decimals), 200, block.timestamp + 730 days);
        }
    }

    function borrow(uint256 _amount) external returns (uint256 newOutstanding) {
        (uint256 maxBorrow, , uint256 deadline) = getLoanTerms(msg.sender);
        require(_amount + account[msg.sender].outstanding <= maxBorrow, "Exceeds borrow limit");
        account[msg.sender].outstanding += _amount;
        // If deadline is not already set.
        if (account[msg.sender].deadline == 0) {
            account[msg.sender].deadline = deadline;
        }
        account[msg.sender].active = true;
        _mint(msg.sender, _amount);
        return account[msg.sender].outstanding;
    }

    function simulateOneYearElapsed() external returns (uint256 newOutstanding) {
        account[msg.sender].outstanding = account[msg.sender].outstanding.percentMul(
            10_000 + enquireApr(msg.sender)
        );
        return account[msg.sender].outstanding;
    }

    function repay(uint256 _amount) external returns (uint256 newOutstanding) {
        require(account[msg.sender].outstanding > 0, "No active loan");
        if (_amount > account[msg.sender].outstanding) {
            _amount = account[msg.sender].outstanding;
        }
        _burn(msg.sender, _amount);
        account[msg.sender].outstanding -= _amount;
        if (account[msg.sender].outstanding == 0) {
            account[msg.sender].deadline = 0;
            account[msg.sender].active = false;
        }
        return account[msg.sender].outstanding;
    }

    function mint(address _to, uint _amount) external {
        _mint(_to, _amount);
    }

    function burn(address _from, uint _amount) external {
        _burn(_from, _amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function setCreditScore(address _account, uint256 _creditScore) external {
        // Verification API reads user's credit score record and sets in this contract.
        account[_account].creditScore = _creditScore;
    }

    function getOutstanding(address _account) external view returns (uint256) {
        return account[_account].outstanding;
    }

    function getCreditScore(address _account) external view returns (uint256) {
        return account[_account].creditScore;
    }

    function getDeadline(address _account) external view returns (uint256) {
        return account[_account].deadline;
    }

    function getActive(address _account) external view returns (bool) {
        return account[_account].active;
    }

    function enquireMaxBorrow(address _account) public view returns (uint256 maxBorrow) {
        (maxBorrow, , ) = getLoanTerms(_account);
    }

    function enquireApr(address _account) public view returns (uint256 apr) {
        (, apr, ) = getLoanTerms(_account);
    }

    function enquireDeadline(address _account) public view returns (uint256 deadline) {
        (, , deadline) = getLoanTerms(_account);
    }
}