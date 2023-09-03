// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import './interfaces/yearn/IVaultWrapper.sol';
import { VaultAPI, IYearnRegistry } from './interfaces/yearn/VaultAPI.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';
import { FixedPointMathLib } from './libs/FixedPointMathLib.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import 'hardhat/console.sol';

/**
 * @author RobAnon
 * @author 0xTraub
 * @author 0xTinder
 * @notice a contract for providing Yearn V2 contracts with an ERC-4626-compliant interface
 *         Developed for Resonate.
 * @dev The initial deposit to this contract should be made immediately following deployment
 */
contract YearnV2 is ERC4626, IVaultWrapper, Ownable2Step, ReentrancyGuard {

    using FixedPointMathLib for uint;
    using SafeERC20 for IERC20;

    /// NB: If this is deployed on non-Mainnet chains
    ///     Then this address may be different
    IYearnRegistry public registry = IYearnRegistry(0x50c1a2eA0a861A967D9d0FFE2AE4012c2E053804);

    VaultAPI public yVault;

    address public immutable token;
    /// Decimals for native token
    uint8 public immutable _decimals;

    /// Necessary to prevent precision manipulation
    uint private constant MIN_DEPOSIT = 1E3;

    address flushReceiver;

    mapping(address => uint8) authorized;

    uint8 authorizedEnabled;

    constructor(VaultAPI _vault)
        ERC20(
            string(abi.encodePacked('COFI Wrapped ', _vault.name())),
            string(abi.encodePacked('cw', _vault.symbol()))
        )
        ERC4626(
            IERC20(_vault.token()) // OZ contract retrieves decimals from asset
        )
    {
        yVault = _vault;
        token = yVault.token();
        _decimals = uint8(_vault.decimals());
    }

    function vault() external view returns (address) {
        return address(yVault);
    }

    /// @dev Verify that current Yearn vault is latest with Yearn registry. If not, migrate funds automatically
    function migrate() external {
        address newVault = registry.latestVault(token);
        // Check if active yVault is latest yVault
        if(newVault != address(yVault)) {
            // If it is not, migrate the assets to the new yVault
            IERC20 tokenContract = IERC20(token);
            
            // Update storage
            VaultAPI oldVault = yVault;
            yVault = VaultAPI(newVault);

            // Withdraw all assets from old vault
            uint assets = oldVault.withdraw(type(uint).max);
            // Approve deposits to new yVault
            tokenContract.safeApprove(newVault, assets);

            // Redeposit assets into target vault
            yVault.deposit(assets);
        }  
    }

    // NB: this number will be different from this token's totalSupply
    function vaultTotalSupply() external view returns (uint256) {
        return yVault.totalSupply();
    }

    /*//////////////////////////////////////////////////////////////
                            COFI ACCESS
    //////////////////////////////////////////////////////////////*/

    /// @param _account The account to provide authorization for.
    /// @param _enabled Whether the account has authorization.
    function setAuthorized(
        address _account,
        uint8   _enabled
    )   external onlyOwner
        returns (bool)
    {
        authorized[_account] = _enabled;
        return true;
    }

    function setAuthorizedEnabled(
        uint8 _enabled
    )   external onlyOwner
        returns (bool)
    {
        authorizedEnabled = _enabled;
        return true;
    }

    function setFlushReceiver(
        address _receiver
    )   external onlyOwner
        returns (bool)
    {
        flushReceiver = _receiver;
        return true;
    }

    /// @notice Useful for manual rewards reinvesting (executed by receiver).
    ///         where there is a lack of a trusted price feed.
    ///
    /// @param _token           The ERC20 token to recover.
    function recoverERC20(
        IERC20 _token
    )   external onlyOwner
    {
        _token.safeTransfer(msg.sender, _token.balanceOf(address(this)));
    }

    /*//////////////////////////////////////////////////////////////
                      DEPOSIT/WITHDRAWAL LOGIC
  //////////////////////////////////////////////////////////////*/

    function deposit(
        uint256 assets, 
        address receiver
    ) public override nonReentrant onlyAuthorized returns (uint256 shares) {

        if(assets < MIN_DEPOSIT) {
            revert MinimumDepositNotMet();
        }

        (assets, shares) = _deposit(assets, receiver, msg.sender);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(
        uint256 shares, 
        address receiver
    ) public override nonReentrant onlyAuthorized returns (uint256 assets) {
        // No need to check for rounding error, previewMint rounds up.
        assets = previewMint(shares); 

        uint expectedShares = shares;
        (assets, shares) = _deposit(assets, receiver, msg.sender);

        if(assets < MIN_DEPOSIT) {
            revert MinimumDepositNotMet();
        }

        if(shares != expectedShares) {
            revert NotEnoughAvailableAssetsForAmount();
        }

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address _owner
    ) public override nonReentrant onlyAuthorized returns (uint256 shares) {

        if(assets == 0) {
            revert NonZeroArgumentExpected();
        }

        (assets, shares) = _withdraw(
            assets,
            receiver,
            _owner
        );

        emit Withdraw(msg.sender, receiver, _owner, assets, shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address _owner
    ) public override nonReentrant onlyAuthorized returns (uint256 assets) {
        
        if(shares == 0) {
            revert NonZeroArgumentExpected();
        }

        (assets, shares) = _redeem(
            shares,
            receiver,
            _owner
        );

        emit Withdraw(msg.sender, receiver, _owner, assets, shares);
    }

    function harvest() public returns (uint256 deposited) {
        if (IERC20(asset()).balanceOf(address(this)) > 0) {
            (deposited, ) = _flush(IERC20(asset()).balanceOf(address(this)));
        } else return 0;
    }

    /*//////////////////////////////////////////////////////////////
                          ACCOUNTING LOGIC
  //////////////////////////////////////////////////////////////*/

    function totalAssets() public view override returns (uint256) {
        return convertYearnSharesToAssets(yVault.balanceOf(address(this)));
    }

    function convertToShares(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        uint supply = totalSupply();
        uint localAssets = convertYearnSharesToAssets(yVault.balanceOf(address(this)));
        return supply == 0 ? assets : assets.mulDivDown(supply, localAssets); 
    }

    function convertToAssets(uint256 shares)
        public
        view
        override
        returns (uint assets)
    {
        uint supply = totalSupply();
        uint localAssets = convertYearnSharesToAssets(yVault.balanceOf(address(this)));
        return supply == 0 ? shares : shares.mulDivDown(localAssets, supply);
    }

    function getFreeFunds() public view virtual returns (uint256) {
        uint256 lockedFundsRatio = (block.timestamp - yVault.lastReport()) * yVault.lockedProfitDegradation();
        uint256 _lockedProfit = yVault.lockedProfit();

        uint256 DEGRADATION_COEFFICIENT = 10 ** 18;
        uint256 lockedProfit = lockedFundsRatio < DEGRADATION_COEFFICIENT ? 
            _lockedProfit - (lockedFundsRatio * _lockedProfit / DEGRADATION_COEFFICIENT)
            : 0; // hardcoded DEGRADATION_COEFFICIENT        
        return yVault.totalAssets() - lockedProfit;
    }

    
    function previewDeposit(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        return convertToShares(assets);
    }

    function previewWithdraw(uint256 assets)
        public
        view
        override
        returns (uint256)
    {
        uint supply = totalSupply();
        uint localAssets = convertYearnSharesToAssets(yVault.balanceOf(address(this)));
        return supply == 0 ? assets : assets.mulDivUp(supply, localAssets); 
    }

    function previewMint(uint256 shares)
        public
        view
        override
        returns (uint256)
    {
        uint supply = totalSupply();
        uint localAssets = convertYearnSharesToAssets(yVault.balanceOf(address(this)));
        return supply == 0 ? shares : shares.mulDivUp(localAssets, supply);
    }

    function previewRedeem(uint256 shares)
        public
        view
        override
        returns (uint256)
    {
        return convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSIT/WITHDRAWAL LIMIT LOGIC
  //////////////////////////////////////////////////////////////*/

    function maxDeposit(address)
        public
        view
        override
        returns (uint256)
    {
        return yVault.availableDepositLimit();
    }

    function maxMint(address _account)
        public
        view
        override
        returns (uint256)
    {
        return maxDeposit(_account)/ yVault.pricePerShare();
    }

    function maxWithdraw(address _owner)
        public
        view
        override
        returns (uint256)
    {
        return convertToAssets(this.balanceOf(_owner));
    }

    function maxRedeem(address _owner) public view override returns (uint256) {
        return this.balanceOf(_owner);
    }

     function _deposit(
        uint256 amount,
        address receiver,
        address depositor
    ) internal returns (uint256 deposited, uint256 mintedShares) {
        VaultAPI _vault = yVault;
        IERC20 _token = IERC20(token);

        if (amount == type(uint256).max) {
            amount = Math.min(
                _token.balanceOf(depositor),
                _token.allowance(depositor, address(this))
            );
        }

        _token.safeTransferFrom(depositor, address(this), amount);

        _token.safeApprove(address(_vault), amount);

        uint256 beforeBal = _token.balanceOf(address(this));

        mintedShares = previewDeposit(amount);
        _vault.deposit(amount, address(this));

        uint256 afterBal = _token.balanceOf(address(this));
        deposited = beforeBal - afterBal;

        // afterDeposit custom logic
        _mint(receiver, mintedShares);
    }

     function _flush(
        uint256 amount
    ) internal returns (uint256 deposited, uint256 mintedShares) {
        VaultAPI _vault = yVault;
        IERC20 _token = IERC20(token);

        _token.safeApprove(address(_vault), amount);

        uint256 beforeBal = _token.balanceOf(address(this));

        mintedShares = previewDeposit(amount);
        _vault.deposit(amount, address(this));

        uint256 afterBal = _token.balanceOf(address(this));
        deposited = beforeBal - afterBal;

        // afterDeposit custom logic
        _mint(flushReceiver, mintedShares);
    }

    function _withdraw(
        uint256 amount,
        address receiver,
        address sender
    ) internal returns (uint256 assets, uint256 shares) {
        VaultAPI _vault = yVault;

        shares = previewWithdraw(amount); 
        uint yearnShares = convertAssetsToYearnShares(amount);

        assets = _doWithdrawal(shares, yearnShares, sender, receiver, _vault);

        if(assets < amount) {
            revert NotEnoughAvailableSharesForAmount();
        }
    }

    function _redeem(
        uint256 shares, 
        address receiver,
        address sender
    ) internal returns (uint256 assets, uint256 sharesBurnt) {
        VaultAPI _vault = yVault;
        uint yearnShares = convertSharesToYearnShares(shares);
        assets = _doWithdrawal(shares, yearnShares, sender, receiver, _vault);    
        sharesBurnt = shares;
    }

    function _doWithdrawal(
        uint shares,
        uint yearnShares,
        address sender,
        address receiver,
        VaultAPI _vault
    ) private returns (uint assets) {
        if (sender != msg.sender) {
            uint currentAllowance = allowance(sender, msg.sender);
            if(currentAllowance < shares) {
                revert SpenderDoesNotHaveApprovalToBurnShares();
            }
            _approve(sender, msg.sender, currentAllowance - shares);
        }

        if (shares > balanceOf(sender)) {
            revert NotEnoughAvailableSharesForAmount();
        }

        if(yearnShares == 0 || shares == 0) {
            revert NoAvailableShares();
        }

        _burn(sender, shares);
        // withdraw from vault and get total used shares
        assets = _vault.withdraw(yearnShares, receiver, 0);
    }

    ///
    /// VIEW METHODS
    ///

    function convertAssetsToYearnShares(uint assets) internal view returns (uint yShares) {
        uint256 supply = yVault.totalSupply();
        return supply == 0 ? assets : assets.mulDivUp(supply, getFreeFunds());
    }

    function convertYearnSharesToAssets(uint yearnShares) internal view returns (uint assets) {
        uint supply = yVault.totalSupply();
        return supply == 0 ? yearnShares : yearnShares * getFreeFunds() / supply;
    }

    function convertSharesToYearnShares(uint shares) internal view returns (uint yShares) {
        uint supply = totalSupply(); 
        return supply == 0 ? shares : shares.mulDivUp(yVault.balanceOf(address(this)), supply);
    }

    function allowance(address _owner, address spender) public view virtual override(ERC20, IERC20) returns (uint256) {
        return super.allowance(_owner,spender);
    }

    function balanceOf(address account) public view virtual override(ERC20, IERC20) returns (uint256) {
        return super.balanceOf(account);
    }

    function name() public view virtual override(ERC20, IERC20Metadata) returns (string memory) {
        return super.name();
    }

    function symbol() public view virtual override(ERC20, IERC20Metadata) returns (string memory) {
        return super.symbol();
    }

    function totalSupply() public view virtual override(ERC20, IERC20) returns (uint256) {
        return super.totalSupply();
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdmin() {
        require(
            msg.sender == owner() || authorized[msg.sender] > 0,
            'YearnV2ERC4626Wrapper: Caller not admin'
        );
        _;
    }

    /// @dev Add to prevent operation outside of app context.
    modifier onlyAuthorized() {
        if (authorizedEnabled > 0) {
            require(
                authorized[msg.sender] == 1,
                'YearnV2ERC4626Wrapper: Caller not authorized'
            );
        }
        _;
    }
}