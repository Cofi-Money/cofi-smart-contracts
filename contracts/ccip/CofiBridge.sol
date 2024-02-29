// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "./utils/Withdraw.sol";
import {ERC20Token} from "../token/mock/ERC20Token.sol";
import "../diamond/interfaces/IERC4626.sol";

/**

    █▀▀ █▀█ █▀▀ █
    █▄▄ █▄█ █▀░ █

    @author Sam Goodenough, The Stoa Corporation Ltd.
    @title  Cofi Bridge
    @notice Source contract for bridging cofi tokens to a supported detination chain.
    @dev    There is a one-to-many relationship between source (bridge) and destination
            (unbridge) contracts.
    @dev    Although caller can pass fee, it is advised to maintain a small amount of
            ETH at this address to account for minor wei discrepancies.
 */

contract CofiBridge is Withdraw, CCIPReceiver {
    enum PayFeesIn {
        Native,
        LINK
    }

    address immutable i_link;

    event MessageSent(bytes32 messageId);
    event CallSuccessful();

    // Errors if the user has not provided enough ETH.
    error InsufficientFee();
    // Reverts if the trasnmitter (on destination chain) is not authorized.
    error NotAuthorizedTransmitter();

    // Added bridge metadata
    bool public mandateFee;
    uint256 public gasLimit;

    // E.g., coUSD => wcoUSD.
    /// @dev Cofi rebasing tokens need to be wrapped before bridging, as rebasing is not
    ///      supported cross-chain.
    mapping(address => IERC4626) public vault;

    // srcAsset => Chain Selector => destShare. E.g., wcoUSD => Polygon (MATIC) => matcoUSD.
    mapping(address => mapping(uint64 => address)) public destShare;

    // destShare => srcAsset. E.g., matcoUSD => wcoUSD.
    /// @dev When bridged back, indicated which cofi token to finalise the redemption for.
    mapping(address => address) public srcAsset;

    // Contract responsible for minting/burning shares on destination chain.
    mapping(uint64 => address) public receiver;

    // Access control.
    mapping(address => bool) public authorizedTransmitter;
    mapping(address => bool) public authorized;

    /// @dev See Chainlink CCIP docs for explanation of Router, Chain Selector, etc.
    constructor(
        address _router,
        address _link,
        // Set initial destination params.
        address _cofi,
        address _vault,
        uint64  _destChainSelector,
        address _destShare,
        address _receiver
    )   CCIPReceiver(_router)
    {
        i_link = _link;
        LinkTokenInterface(i_link).approve(i_router, type(uint256).max);
        vault[_cofi] = IERC4626(_vault);
        destShare[_cofi][_destChainSelector] = _destShare;
        receiver[_destChainSelector] = _receiver;
        authorizedTransmitter[_receiver] = true;
        IERC20(_cofi).approve(_vault, type(uint256).max);
        mandateFee = true;
        gasLimit = 200_000;
        authorized[msg.sender] = true;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender], "CofiBridge: Caller not authorized");
        _;
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                            Admin Setters
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets whether an account has authorized status.
    function setAuthorized(
        address _account,
        bool    _authorized
    )   external onlyAuthorized
    {
        authorized[_account] = _authorized;
    }

    /// @notice Indicates whether a tx originating from an account on a
    ///         foreign chain is authorized as a correspondent transmitter.
    function setAuthorizedTransmitter(
        address _account,
        bool    _authorized
    )   external onlyAuthorized
    {
        authorizedTransmitter[_account] = _authorized;
    }

    /// @notice Sets the ERC4626-vault for wrapping and unwrapping cofi tokens
    ///         upon bridging and un-bridging, respectively.
    function setVault(
        address _cofi,
        address _vault
    )   external onlyAuthorized
    {
        vault[_cofi] = IERC4626(_vault);
        IERC20(_cofi).approve(_vault, type(uint256).max);
    }

    /// @notice Sets the address of the destination share token on the foreign chain.
    ///         E.g., coUSD => matwcoUSD.
    ///         I.e., the foreign contract to mint destination share tokens.
    /// @param _destChainSelector Chainlink chain selector for the target chain.
    function setDestShare(
        address _cofi,
        uint64  _destChainSelector,
        address _destShare
    )   external onlyAuthorized
    {
        destShare[_cofi][_destChainSelector] = _destShare;
    }

    /// @notice Sets the receiver contract on the destination/foreign chain ('CofiUnbridge.sol').
    /// @param _authorizedTransmitter Indicates whether the receiver contract is eligible
    ///                               to transmit txs to this contract (e.g., 'unbridge()').
    function setReceiver(
        uint64  _destChainSelector,
        address _receiver,
        bool    _authorizedTransmitter
    )   external onlyAuthorized
    {
        receiver[_destChainSelector] = _receiver;
        authorizedTransmitter[_receiver] = _authorizedTransmitter;
    }

    /// @notice Indicates whether the end-user is mandated to pay a fee for bridging or
    ///         if this fee is paid from this contract's pre-existing balance.
    function setMandateFee(
        bool _enabled
    )   external
    {
        mandateFee = _enabled;
    }

    /// @notice Sets the gas limit for executing cross-chain txs.
    function setGasLimit(
        uint256 _gasLimit
    )   external
    {
        gasLimit = _gasLimit;
    }

    /*//////////////////////////////////////////////////////////////
                        Transmitter Logic
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Bridging function for cofi tokens.
     * @param _cofi               The cofi token to bridge (e.g., coUSD).
     * @param _destChainSelector  Chainlink chain selector of the target chain.
     * @param _amount             The amount of cofi tokens to bridge.
     * @param _destSharesReceiver The account receiving share tokens on the destination chain.
     */
    function bridge(
        address _cofi,
        uint64  _destChainSelector,
        uint256 _amount,
        address _destSharesReceiver
    )   external payable
        returns (uint256 shares)
    {
        /// @dev If active, requires the caller sending sufficient ETH. This fee value
        ///      can be retrieved in advance by calling 'getFeeETH()'.
        if (mandateFee) {
            if (
                msg.value < getFeeETH(
                    _cofi,
                    _destChainSelector,
                    _amount,
                    _destSharesReceiver
                )
            ) revert InsufficientFee();
        }
        // Transfer cofi tokens to this address first.
        IERC20(_cofi).transferFrom(msg.sender, address(this), _amount);

        // Wrap cofi tokens into shares and store at this address.
        shares = vault[_cofi].deposit(_amount, address(this));

        // Mint corresponding shares on destination chain.
        _mint(
            _destChainSelector,
            destShare[_cofi][_destChainSelector],
            _destSharesReceiver,
            shares
        );
    }

    function _mint(
        uint64 _destChainSelector,
        address _share,
        address _recipient,
        uint256 _amount
    )   internal
    {
        // Prepare cross-chain tx body.
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver[_destChainSelector]),
            data: abi.encodeWithSignature(
                "mint(address,address,uint256)", // Function to call on receiver contract.
                _share,
                _recipient,
                _amount
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_router).getFee(
            _destChainSelector,
            message
        );

        bytes32 messageId = IRouterClient(i_router).ccipSend{value: fee}(
            _destChainSelector,
            message
        );

        emit MessageSent(messageId);
    }

    /// @notice Returns the estimated fee in wei required for bridging op.
    /// @notice Pass same args as if were doing actual bridging op.
    function getFeeETH(
        address _cofi,
        uint64  _destChainSelector,
        uint256 _amount,
        address _destSharesReceiver
    )   public view
        returns (uint256 fee)
    {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver[_destChainSelector]),
            data: abi.encodeWithSignature(
                "mint(address,address,uint256)",
                destShare[_cofi][_destChainSelector],
                _destSharesReceiver,
                _amount
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: gasLimit, strict: false})
            ),
            feeToken: address(0)
        });

        return IRouterClient(i_router).getFee(
            _destChainSelector,
            message
        );
    }

    /*//////////////////////////////////////////////////////////////
                            Receiver Logic
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Receiver functions, only triggered by Chainlink router contract.
     * @param _cofi           The cofi token to redeem.
     * @param _shares         The number of shares to redeem (e.g., wcoUSD => coUSD).
     * @param _assetsReceiver The account receiving cofi tokens.
     */
    function redeem(
        address _cofi,
        uint256 _shares,
        address _assetsReceiver
    )   public onlyRouter
        returns (uint256 assets)
    {
        assets = vault[_cofi].redeem(_shares, _assetsReceiver, address(this));
    }


    function _ccipReceive(
        Client.Any2EVMMessage memory message
    )   internal override
    {
        address sender = abi.decode(message.sender, (address));
        if (!authorizedTransmitter[sender]) revert NotAuthorizedTransmitter();
        // Calls the function at this address.
        (bool success, ) = address(this).call(message.data);
        require(success);
        emit CallSuccessful();
    }

    /*//////////////////////////////////////////////////////////////
                    Testing - Transmitter & Receiver
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Tests whether a function successfully executes cross-chain without bridging tokens.
     * @param _ping Number should appear in receiver contract if successful.
     */
    function doPing(
        uint256 _ping,
        address _receiver,
        uint64  _chainSelector
    )   external payable
    {
        if (mandateFee) {
            if (msg.value < getFeeETHPing(_ping, _receiver, _chainSelector)) {
                revert InsufficientFee();
            }
        }

        _doPing(_ping, _receiver, _chainSelector);
    }

    function _doPing(
        uint256 _ping,
        address _receiver,
        uint64  _chainSelector
    )   internal
    {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: abi.encodeWithSignature("doPing(uint256)", _ping),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit, strict: false})),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_router).getFee(
            _chainSelector,
            message
        );

        bytes32 messageId = IRouterClient(i_router).ccipSend{value: fee}(
            _chainSelector,
            message
        );

        emit MessageSent(messageId);
    }

    /// @dev Fee amount is unique for each function that executes a cross-chain tx.
    function getFeeETHPing(
        uint256 _pong,
        address _receiver,
        uint64  _chainSelector
    )   public view
        returns (uint256 fee)
    {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: abi.encodeWithSignature(
                "doPing(uint256)",
                _pong
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit, strict: false})),
            feeToken: address(0)
        });

        return IRouterClient(i_router).getFee(
            _chainSelector,
            message
        );
    }
}