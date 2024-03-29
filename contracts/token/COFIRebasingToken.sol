// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SafeMath } from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import { Address } from '@openzeppelin/contracts/utils/Address.sol';
import { ERC20Permit } from './utils/draft-ERC20Permit.sol';
import { StableMath } from './utils/StableMath.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.

    @title  COFI Rebasing Token Contract
    @notice Rebasing ERC20 contract.
 */

/**
 * NOTE that this is an ERC20 token but the invariant that the sum of
 * balanceOf(x) for all x is not >= totalSupply(). This is a consequence of the
 * rebasing design. Any integrations should be aware.
 */

contract COFIRebasingToken is ERC20Permit, ReentrancyGuard, Ownable2Step {
    using SafeMath for uint256;
    using StableMath for uint256;
    using StableMath for int256;

    event TotalSupplyUpdatedHighres(
        uint256 totalSupply,
        uint256 rebasingCredits,
        uint256 rebasingCreditsPerToken
    );

    enum RebaseOptions {
        NotSet,
        OptOut,
        OptIn
    }

    /*//////////////////////////////////////////////////////////////
                            DATA STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 private constant MAX_SUPPLY = ~uint128(0); // (2^128) - 1
    uint256 private constant RESOLUTION_INCREASE = 1e9;

    uint256 public _totalSupply;

    /// @dev '_allowances' has moved to base 'draft-ERC20Permit.sol' contract.

    uint256 private _rebasingCredits;
    uint256 private _rebasingCreditsPerToken;
    uint256 public nonRebasingSupply;

    mapping(address => uint256) public _creditBalances;
    mapping(address => uint256) public nonRebasingCreditsPerToken;
    mapping(address => uint256) public isUpgraded;
    mapping(address => RebaseOptions) public rebaseState;

    address app;

    mapping(address => uint8) private admin;
    mapping(address => uint8) private frozen;
    // Manually prevent an account from opting in to rebases.
    mapping(address => uint8) private rebaseLock;
    uint8 paused;

    // Used to track the total amount of yield earned via rebases for accounts.
    mapping(address => int256) public yieldExcl;

    // How much of the user's balance is non-transferable.
    mapping(address => uint256) public locked;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) ERC20Permit(_name) {
        admin[msg.sender] = 1;
        _rebasingCreditsPerToken = 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                            TOKEN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @return The total supply of tokens.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @return Low resolution rebasingCreditsPerToken.
     */
    function rebasingCreditsPerToken() public view returns (uint256) {
        return _rebasingCreditsPerToken / RESOLUTION_INCREASE;
    }

    /**
     * @return Low resolution total number of rebasing credits.
     */
    function rebasingCredits() public view returns (uint256) {
        return _rebasingCredits / RESOLUTION_INCREASE;
    }

    /**
     * @return High resolution rebasingCreditsPerToken.
     */
    function rebasingCreditsPerTokenHighres() public view returns (uint256) {
        return _rebasingCreditsPerToken;
    }

    /**
     * @return High resolution total number of rebasing credits.
     */
    function rebasingCreditsHighres() public view returns (uint256) {
        return _rebasingCredits;
    }

    /**
     * @dev     Gets the balance of the specified address.
     * @param   _account Address to query the balance of.
     * @return  A uint256 representing the amount of base units owned by the
     *          specified address.
     */
    function balanceOf(address _account) public view override returns (uint256) {
        return _creditBalances[_account] == 0 ?
            0 :
            _creditBalances[_account].divPrecisely(_creditsPerToken(_account));
    }

    /**
     * @notice Returns the transferable balance of an account.
     */
    function freeBalanceOf(address _account) public view returns (uint256) {
        return balanceOf(_account).sub(locked[_account]) < 0 ?
            0 :
            balanceOf(_account).sub(locked[_account]);
    }

    /**
     * @notice  Locks an amount of tokens at the holder's address.
     */
    function lock(
        address _account,
        uint256 _amount
    ) external onlyApp returns (bool) {
        
        _amount >= freeBalanceOf(_account) ?
            locked[_account] = balanceOf(_account) :
            locked[_account] = locked[_account].add(_amount);
        return true;
    }

    function unlock(
        address _account,
        uint256 _amount
    ) external onlyApp returns (bool) {

        locked[_account] = _amount >= locked[_account] ?
            0 :
            locked[_account].sub(_amount);
        return true;
    }

    /**
     * @notice Returns the number of tokens from an amount of credits.
     * @param _amount The amount of credits to convert to tokens.
     */
    function creditsToBal(uint256 _amount) external view returns (uint256) {
        return _amount.divPrecisely(_rebasingCreditsPerToken);
    }

    /**
     * @dev Gets the credits balance of the specified address.
     * @dev Backwards compatible with old low res credits per token.
     * @param _account  The address to query the balance of.
     * @return          (uint256, uint256) Credit balance and credits per token of the
     *                  address.
     */
    function creditsBalanceOf(address _account) public view returns (uint256, uint256) {
        uint256 cpt = _creditsPerToken(_account);
        if (cpt == 1e27) {
            // For a period before the resolution upgrade, we created all new
            // contract accounts at high resolution. Since they are not changing
            // as a result of this upgrade, we will return their true values
            return (_creditBalances[_account], cpt);
        } else {
            return (
                _creditBalances[_account] / RESOLUTION_INCREASE,
                cpt / RESOLUTION_INCREASE
            );
        }
    }

    /**
     * @dev Gets the credits balance of the specified address.
     * @param _account  The address to query the balance of.
     * @return          (uint256, uint256, bool) Credit balance, credits per token of the
     *                  address, and isUpgraded.
     */
    function creditsBalanceOfHighres(
        address _account
    ) public view returns (uint256, uint256, bool) {
        return (
            _creditBalances[_account],
            _creditsPerToken(_account),
            isUpgraded[_account] == 1
        );
    }

    /**
     * @dev Transfer tokens to a specified address.
     * @param _to       The address to transfer to.
     * @param _value    The amount to be transferred.
     * @return          True on success.
     */
    function transfer(
        address _to,
        uint256 _value
    ) public override isValidTransfer(_value, msg.sender, _to) returns (bool) {

        _executeTransfer(msg.sender, _to, _value);

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * @param _from     The address you want to send tokens from.
     * @param _to       The address you want to transfer to.
     * @param _value    The amount of tokens to be transferred.
     * @return          True on success.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public override isValidTransfer(_value, _from, _to) returns (bool) {
        if (_from != msg.sender || _allowances[_from][msg.sender] != type(uint256).max) {
            _allowances[_from][msg.sender] = _allowances[_from][msg.sender].sub(_value);
        }

        _executeTransfer(_from, _to, _value);

        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @notice  Redeem function, only callable from Diamond, to return tokens.
     * @dev     Skips approval check.
     * @param _from     The address to redeem tokens from.
     * @param _to       The receiver of the tokens (usually the fee collector).
     * @param _value    The amount of tokens to redeem.
     * @return          True on success.
     */
    function redeem(
        address _from,
        address _to,
        uint256 _value
    ) external onlyApp returns (bool) {
        // Ignore 'paused' check, as this is covered by 'redeemEnabled' in Diamond.

        _executeTransfer(_from, _to, _value);

        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @param _from     The address you want to send tokens from.
     * @param _to       The address you want to transfer to.
     * @param _value    Amount of tokens to transfer
     */
    function _executeTransfer(
        address _from,
        address _to,
        uint256 _value
    ) internal {
        if (msg.sender != app) {
            require(
                _value <= balanceOf(_from).sub(locked[_from]),
                'COFIRebasingToken: Transfer amount exceeds balance and amount locked'
            );
        }
        bool isNonRebasingTo = _isNonRebasingAccount(_to);
        bool isNonRebasingFrom = _isNonRebasingAccount(_from);

        // Logic to track yield.
        yieldExcl[_from] += int256(_value);
        yieldExcl[_to] -= int256(_value);

        // Credits deducted and credited might be different due to the
        // differing creditsPerToken used by each account
        uint256 creditsCredited = _value.mulTruncate(_creditsPerToken(_to));
        uint256 creditsDeducted = _value.mulTruncate(_creditsPerToken(_from));

        _creditBalances[_from] = _creditBalances[_from].sub(
            creditsDeducted,
            'COFIRebasingToken: Transfer amount exceeds balance'
        );
        _creditBalances[_to] = _creditBalances[_to].add(creditsCredited);

        if (isNonRebasingTo && !isNonRebasingFrom) {
            // Transfer to non-rebasing account from rebasing account, credits
            // are removed from the non rebasing tally
            nonRebasingSupply = nonRebasingSupply.add(_value);
            // Update rebasingCredits by subtracting the deducted amount
            _rebasingCredits = _rebasingCredits.sub(creditsDeducted);
        } else if (!isNonRebasingTo && isNonRebasingFrom) {
            // Transfer to rebasing account from non-rebasing account
            // Decreasing non-rebasing credits by the amount that was sent
            nonRebasingSupply = nonRebasingSupply.sub(_value);
            // Update rebasingCredits by adding the credited amount
            _rebasingCredits = _rebasingCredits.add(creditsCredited);
        }
    }

    /**
     * @dev Function to check the amount of tokens that _owner has allowed to
     *      `_spender`.
     * @param   _owner The address which owns the funds.
     * @param   _spender The address which will spend the funds.
     * @return  The number of tokens still available for the _spender.
     */
    function allowance(
        address _owner,
        address _spender
    ) public view override returns (uint256) {
        return _allowances[_owner][_spender];
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens
     *      on behalf of msg.sender. This method is included for ERC20
     *      compatibility. `increaseAllowance` and `decreaseAllowance` should be
     *      used instead.
     *
     *      Changing an allowance with this method brings the risk that someone
     *      may transfer both the old and the new allowance - if they are both
     *      greater than zero - if a transfer transaction is mined before the
     *      later approve() call is mined.
     * @param _spender  The address which will spend the funds.
     * @param _value    The amount of tokens to be spent.
     */
    function approve(
        address _spender,
        uint256 _value
    ) public override returns (bool) {
        _allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner has allowed to
     *      `_spender`.
     *      This method should be used instead of approve() to avoid the double
     *      approval vulnerability described above.
     * @param _spender      The address which will spend the funds.
     * @param _addedValue   The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(
        address _spender,
        uint256 _addedValue
    ) public override returns (bool) {
        _allowances[msg.sender][_spender] = _allowances[msg.sender][_spender]
            .add(_addedValue);

        emit Approval(msg.sender, _spender, _allowances[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner has allowed to
            `_spender`.
     * @param _spender          The address which will spend the funds.
     * @param _subtractedValue  The amount of tokens to decrease the allowance
     *                          by.
     */
    function decreaseAllowance(
        address _spender,
        uint256 _subtractedValue
    ) public override returns (bool) {
        uint256 oldValue = _allowances[msg.sender][_spender];
        if (_subtractedValue >= oldValue) {
            _allowances[msg.sender][_spender] = 0;
        } else {
            _allowances[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }

        emit Approval(msg.sender, _spender, _allowances[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Mints new tokens, increasing totalSupply.
     */
    function mint(address _account, uint256 _amount) external onlyApp {
        // Ignore 'paused' check, as this is covered by 'mintEnabled' in Diamond.
        require(frozen[_account] == 0, 'COFIRebasingToken: Recipient account is frozen');
        _mint(_account, _amount);
    }

    /**
     * @dev Additional function for opting the account in after minting.
     */
    function mintOptIn(address _account, uint256 _amount) external onlyApp {
        // Ignore 'paused' check, as this is covered by 'mintEnabled' in Diamond.
        require(frozen[_account] == 0, 'COFIRebasingToken: Recipient account is frozen');
        _mint(_account, _amount);

        if (_isNonRebasingAccount(_account)) {
            rebaseOptInExternal(_account);
        }
    }

    /**
     * @dev Creates `_amount` tokens and assigns them to `_account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address _account, uint256 _amount) internal override nonReentrant {
        require(_account != address(0), 'COFIRebasingToken: Mint to the zero address');

        bool isNonRebasingAccount = _isNonRebasingAccount(_account);

        uint256 creditAmount = _amount.mulTruncate(_creditsPerToken(_account));
        _creditBalances[_account] = _creditBalances[_account].add(creditAmount);

        yieldExcl[_account] -= int256(_amount); 

        // If the account is non rebasing and doesn't have a set creditsPerToken
        // then set it i.e. this is a mint from a fresh contract
        if (isNonRebasingAccount) {
            nonRebasingSupply = nonRebasingSupply.add(_amount);
        } else {
            _rebasingCredits = _rebasingCredits.add(creditAmount);
        }

        _totalSupply = _totalSupply.add(_amount);

        require(_totalSupply < MAX_SUPPLY, 'COFIRebasingToken: Max supply');

        emit Transfer(address(0), _account, _amount);
    }

    /**
     * @dev Burns tokens, decreasing totalSupply.
     *      When an account burns tokens without redeeming, the amount burned is
     *      essentially redistributed to the remaining holders upon the next rebase.
     */
    function burn(address _account, uint256 _amount) external onlyApp {
        require(paused == 0, 'COFIRebasingToken: Token paused');
        _burn(_account, _amount);
    }

    /**
     * @dev Destroys `_amount` tokens from `_account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `_account` cannot be the zero address.
     * - `_account` must have at least `_amount` tokens.
     */
    function _burn(address _account, uint256 _amount) internal override nonReentrant {
        require(_account != address(0), 'COFIRebasingToken: Burn from the zero address');
        if (_amount == 0) {
            return;
        }

        bool isNonRebasingAccount = _isNonRebasingAccount(_account);
        uint256 creditAmount = _amount.mulTruncate(_creditsPerToken(_account));
        uint256 currentCredits = _creditBalances[_account];

        yieldExcl[_account] += int256(_amount);

        // Remove the credits, burning rounding errors
        if (
            currentCredits == creditAmount || currentCredits - 1 == creditAmount
        ) {
            // Handle dust from rounding
            _creditBalances[_account] = 0;
        } else if (currentCredits > creditAmount) {
            _creditBalances[_account] = _creditBalances[_account].sub(
                creditAmount
            );
        } else {
            revert('COFIRebasingToken: Remove exceeds balance');
        }

        // Remove from the credit tallies and non-rebasing supply
        if (isNonRebasingAccount) {
            nonRebasingSupply = nonRebasingSupply.sub(_amount);
        } else {
            _rebasingCredits = _rebasingCredits.sub(creditAmount);
        }

        _totalSupply = _totalSupply.sub(_amount);

        emit Transfer(_account, address(0), _amount);
    }

    /**
     * @dev Get the credits per token for an account. Returns a fixed amount
     *      if the account is non-rebasing.
     * @param _account Address of the account.
     */
    function _creditsPerToken(address _account) internal view returns (uint256) {
        if (nonRebasingCreditsPerToken[_account] != 0) {
            return nonRebasingCreditsPerToken[_account];
        } else {
            return _rebasingCreditsPerToken;
        }
    }

    /**
     * @dev Is an account using rebasing accounting or non-rebasing accounting?
     *      Also, ensure contracts are non-rebasing if they have not opted in.
     * @param _account Address of the account.
     */
    function _isNonRebasingAccount(address _account) internal returns (bool) {
        bool isContract = Address.isContract(_account);
        if (isContract && rebaseState[_account] == RebaseOptions.NotSet) {
            _ensureRebasingMigration(_account);
        }
        return nonRebasingCreditsPerToken[_account] > 0;
    }

    /**
     * @dev Ensures internal account for rebasing and non-rebasing credits and
     *      supply is updated following deployment of frozen yield change.
     */
    function _ensureRebasingMigration(address _account) internal {
        if (nonRebasingCreditsPerToken[_account] == 0) {
            if (_creditBalances[_account] == 0) {
                // Since there is no existing balance, we can directly set to
                // high resolution, and do not have to do any other bookkeeping
                nonRebasingCreditsPerToken[_account] = 1e27;
            } else {
                // Migrate an existing account:

                // Set fixed credits per token for this account
                nonRebasingCreditsPerToken[_account] = _rebasingCreditsPerToken;
                // Update non rebasing supply
                nonRebasingSupply = nonRebasingSupply.add(balanceOf(_account));
                // Update credit tallies
                _rebasingCredits = _rebasingCredits.sub(
                    _creditBalances[_account]
                );
            }
        }
    }

    /**
     * @dev Add a contract address to the non-rebasing exception list. The
     * address's balance will be part of rebases and the account will be exposed
     * to upside and downside.
     */
    function rebaseOptIn() public nonReentrant {
        require(rebaseLock[msg.sender] == 0, 'COFIRebasingToken: Account locked out of rebases');
        require(frozen[msg.sender] == 0, 'COFIRebasingToken: Account is frozen');
        require(paused == 0, 'COFIRebasingToken: Token paused');
        require(_isNonRebasingAccount(msg.sender), 'COFIRebasingToken: Account has not opted out');

        // Convert balance into the same amount at the current exchange rate
        uint256 newCreditBalance = _creditBalances[msg.sender]
            .mul(_rebasingCreditsPerToken)
            .div(_creditsPerToken(msg.sender));

        // Decreasing non rebasing supply
        nonRebasingSupply = nonRebasingSupply.sub(balanceOf(msg.sender));

        _creditBalances[msg.sender] = newCreditBalance;

        // Increase rebasing credits, totalSupply remains unchanged so no
        // adjustment necessary
        _rebasingCredits = _rebasingCredits.add(_creditBalances[msg.sender]);

        rebaseState[msg.sender] = RebaseOptions.OptIn;

        // Delete any fixed credits per token
        delete nonRebasingCreditsPerToken[msg.sender];
    }

    /**
     * @dev Add a contract address to the non-rebasing exception list. The
     * address's balance will be part of rebases and the account will be exposed
     * to upside and downside.
     */
    function rebaseOptInExternal(address _account) public onlyAuthorized nonReentrant {
        /// @dev Leave out require statements above in case admin needs to override these.
        require(_isNonRebasingAccount(_account), 'COFIRebasingToken: Account has not opted out');

        // Convert balance into the same amount at the current exchange rate
        uint256 newCreditBalance = _creditBalances[_account]
            .mul(_rebasingCreditsPerToken)
            .div(_creditsPerToken(_account));

        // Decreasing non rebasing supply
        nonRebasingSupply = nonRebasingSupply.sub(balanceOf(_account));

        _creditBalances[_account] = newCreditBalance;

        // Increase rebasing credits, totalSupply remains unchanged so no
        // adjustment necessary
        _rebasingCredits = _rebasingCredits.add(_creditBalances[_account]);

        rebaseState[_account] = RebaseOptions.OptIn;

        // Delete any fixed credits per token
        delete nonRebasingCreditsPerToken[_account];
    }

    /**
     * @dev Explicitly mark that an address is non-rebasing.
     */
    function rebaseOptOut() public nonReentrant {
        require(!_isNonRebasingAccount(msg.sender), 'COFIRebasingToken: Account has not opted in');

        // Increase non rebasing supply
        nonRebasingSupply = nonRebasingSupply.add(balanceOf(msg.sender));
        // Set fixed credits per token
        nonRebasingCreditsPerToken[msg.sender] = _rebasingCreditsPerToken;

        // Decrease rebasing credits, total supply remains unchanged so no
        // adjustment necessary
        _rebasingCredits = _rebasingCredits.sub(_creditBalances[msg.sender]);

        // Mark explicitly opted out of rebasing
        rebaseState[msg.sender] = RebaseOptions.OptOut;
    }

    /**
     * @dev Explicitly mark that an address is non-rebasing.
     */
    function rebaseOptOutExternal(address _account) public onlyAuthorized nonReentrant {
        require(!_isNonRebasingAccount(_account), 'COFIRebasingToken: Account has not opted in');

        // Increase non rebasing supply
        nonRebasingSupply = nonRebasingSupply.add(balanceOf(_account));
        // Set fixed credits per token
        nonRebasingCreditsPerToken[_account] = _rebasingCreditsPerToken;

        // Decrease rebasing credits, total supply remains unchanged so no
        // adjustment necessary
        _rebasingCredits = _rebasingCredits.sub(_creditBalances[_account]);

        // Mark explicitly opted out of rebasing
        rebaseState[_account] = RebaseOptions.OptOut;
    }

    /**
     * @dev Modify the supply without minting new tokens. This uses a change in
     *      the exchange rate between "credits" and tokens to change balances.
     * @param _newTotalSupply New total supply of tokens.
     */
    function changeSupply(uint256 _newTotalSupply) external onlyApp nonReentrant {
        require(_totalSupply > 0, 'COFIRebasingToken: Cannot increase 0 supply');

        if (_totalSupply == _newTotalSupply) {
            emit TotalSupplyUpdatedHighres(
                _totalSupply,
                _rebasingCredits,
                _rebasingCreditsPerToken
            );
        }

        _totalSupply = _newTotalSupply > MAX_SUPPLY
            ? MAX_SUPPLY
            : _newTotalSupply;

        _rebasingCreditsPerToken = _rebasingCredits.divPrecisely(
            _totalSupply.sub(nonRebasingSupply)
        );

        require(_rebasingCreditsPerToken > 0, 'COFIRebasingToken: Invalid change in supply');

        _totalSupply = _rebasingCredits
            .divPrecisely(_rebasingCreditsPerToken)
            .add(nonRebasingSupply);

        emit TotalSupplyUpdatedHighres(
            _totalSupply,
            _rebasingCredits,
            _rebasingCreditsPerToken
        );
    }

    /**
     * @notice  Returns the amount of yield earned by ignoring account
     *          balance changes resulting from mint/burn/transfer.
     *
     * @dev yieldExcl[_account]:
     *      Increases for outgoing amount (transfer 1,000) = 1,000.
     *      - E.g., burning 1,000 from = +1,000.
     *      Decreases for incoming amount (receive 1,000) = -1,000.
     *      - E.g., minting 1,000 to = -1,000.
     *
     * @dev Rebases usually introduce a very minor wei discrepancy
     *      between yield earned and token balance. Account for this
     *      by returning either 0 or a valid uint256.
     */
    function getYieldEarned(address _account) external view returns (uint256) {
        if (yieldExcl[_account] == 0) {
            return 0;
        }
        else if (yieldExcl[_account] > 0) {
            return yieldExcl[_account].abs() < balanceOf(_account) ?
                0 : balanceOf(_account).add(yieldExcl[_account].abs());
        } else {
            return yieldExcl[_account].abs() > balanceOf(_account) ?
                0 : balanceOf(_account).sub(yieldExcl[_account].abs());
        }
    }

    /**
     * @dev     Helper function to convert credit balance to token balance.
     * @param   _creditBalance The credit balance to convert.
     * @return  assets The amount converted to token balance.
     */
    function convertToAssets(uint _creditBalance) public view returns (uint assets) {
        assets = _creditBalance == 0
            ? 0
            : _creditBalance.divPrecisely(_rebasingCreditsPerToken);
    }

    /**
     * @dev     Helper function to convert token balance to credit balance.
     * @param   _tokenBalance The token balance to convert.
     * @return  credits The amount converted to credit balance.
     */
    function convertToCredits(uint _tokenBalance) public view returns (uint credits) {
        credits = _tokenBalance == 0
            ? 0
            : _tokenBalance.mulTruncate(_rebasingCreditsPerToken);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN - SETTERS
    //////////////////////////////////////////////////////////////*/

    function setAdmin(
        address _account,
        uint8 _enabled
    ) external onlyAuthorized returns (bool) {
        admin[_account] = _enabled;

        return true;
    }

    /**
     * @dev     If freezing, first ensure account is opted out of rebases.
     * @return  bool Indicating true if frozen.
     */
    function setFrozen(
        address _account,
        uint8 _enabled
    ) external onlyAuthorized returns (bool) {
        require(
            _isNonRebasingAccount(_account),
            'COFIRebasingToken: Account must be opted out before freezing'
        );
        frozen[_account] = _enabled;

        return true;
    }

    function setPaused(uint8 _enabled) external onlyAuthorized returns (bool) {
        paused = _enabled;

        return true;
    }

    function setRebaseLock(
        address _account,
        uint8 _enabled
    ) external onlyAuthorized returns (bool) {
        rebaseLock[_account] = _enabled;

        return true;
    }

    function setApp(address _app) external onlyAuthorized returns (bool) {
        app = _app;

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Verifies that the caller is the Diamond (app) contract.
     */
    modifier onlyApp() {
        require(app == msg.sender, 'COFIRebasingToken: Caller is not Diamond');
        _;
    }

    /**
     * @dev Verifies that the caller is Owner or Admin.
     */
    modifier onlyAuthorized() {
        require(
            admin[msg.sender] == 1 || msg.sender == owner(),
            'COFIRebasingToken: Caller is not authorized'
        );
        _;
    }

    /**
     * @dev Verifies that the transfer is valid by running checks.
     */
    modifier isValidTransfer(uint256 _value, address _from, address _to) {
        require(_to != address(0), 'COFIRebasingToken: Transfer to zero address');
        require(paused == 0, 'COFIRebasingToken: Token paused');
        require(_value <= balanceOf(_from), 'COFIRebasingToken: Transfer greater than balance');
        require(frozen[_from] == 0, 'COFIRebasingToken: Sender account is frozen');
        require(frozen[_to] == 0, 'COFIRebasingToken: Recipient account is frozen');
        _;
    }
}