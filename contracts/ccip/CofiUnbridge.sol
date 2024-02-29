// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "./utils/Withdraw.sol";
import {ERC20Token} from "../token/mock/ERC20Token.sol";

/**

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
 */

contract COFIBridgeExit is Withdraw, CCIPReceiver {
    enum PayFeesIn {
        Native,
        LINK
    }

    address immutable i_link;

    event MessageSent(bytes32 messageId);
    event CallSuccessful();

    error InsufficientFee();
    error NotAuthorizedTrasnmitter();

    // Added bridge metadata
    bool public mandateFee;
    uint256 public gasLimit;

    // Cofi vars
    struct SourceAsset {
        address asset; // E.g., coUSD.
        uint64 chainSelector; // E.g., OPTIMISM_CHAIN_SELECTOR.
    }
    // E.g., matwcoUSD (Polygon) => { coUSD (Optimism); OP chain selector }.
    mapping(address => SourceAsset) public srcAsset;
    // E.g., Optimism chain selector => Bridge.sol (Optimism).
    mapping(uint64 => address) public receiver;

    // Access control.
    mapping(address => bool) public authorizedTransmitter;
    mapping(address => bool) public authorized;

    constructor(
        address _router,
        address _link,
        // Set initial source params.
        address _destShare,
        address _srcAsset,
        uint64 _srcChainSelector
        // Need to set 'receiver' seperately as part of deploy script.
        // Leave commented out for reference.
        // address _receiver
    )   CCIPReceiver(_router) {
        i_link = _link;
        LinkTokenInterface(i_link).approve(i_router, type(uint256).max);
        srcAsset[_destShare].asset = _srcAsset;
        srcAsset[_destShare].chainSelector = _srcChainSelector;
        // receiver[_srcChainSelector] = _receiver;
        mandateFee = true;
        gasLimit = 200_000;
        authorized[msg.sender] = true;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender], "CofiUnbridge: Caller not authorized");
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

    /// @notice Sets the address of the source asset for the given destination
    ///         share (e.g., matwcoUSD => coUSD).
    function setSourceAsset(
        address _destShare,
        uint64  _srcChainSelector,
        address _srcAsset
    )   external onlyAuthorized
    {
        /// @dev Opt to link to asset (e.g., coUSD) in case source vault changes.
        srcAsset[_destShare].asset = _srcAsset;
        srcAsset[_destShare].chainSelector = _srcChainSelector;
    }

    /// @notice Sets the receiver contract on the destination/foreign chain ('CofiBridge.sol').
    /// @param _authorizedTransmitter Indicates whether the receiver contract is eligible
    ///                               to transmit txs to this contract (e.g., 'bridge()').
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
    ) external {
        mandateFee = _enabled;
    }

    /// @notice Sets the gas limit for executing cross-chain txs.
    function setGasLimit(
        uint256 _gasLimit
    ) external {
        gasLimit = _gasLimit;
    }

    /*//////////////////////////////////////////////////////////////
                            Transmitter Logic
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Unbridging function for cofi tokens.
     * @param _destShare         The (local) destination share to redeem.
     * @param _amount            The amount of shares to redeem.
     * @param _srcAssetsReceiver The account receiving assets (e.g., coUSD) on the
     *                           destination (source) chain.
     */
    function unbridge(
        address _destShare,
        uint256 _amount,
        address _srcAssetsReceiver
    )   external payable
    {
        if (mandateFee) {
            if (msg.value < getFeeETH(_destShare, _amount, _srcAssetsReceiver)) {
                revert InsufficientFee();
            }
        }
        ERC20Token(_destShare).burn(msg.sender, _amount);

        _burn(
            srcAsset[_destShare].chainSelector,
            srcAsset[_destShare].asset,
            _srcAssetsReceiver,
            _amount
        );
    }

    function _burn(
        uint64  _srcChainSelector,
        address _asset,
        address _recipient,
        uint256 _amount
    ) internal {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver[_srcChainSelector]),
            data: abi.encodeWithSignature(
                "redeem(address,uint256,address)",
                _asset,
                _amount,
                _recipient
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: gasLimit, strict: false})
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_router).getFee(
            _srcChainSelector,
            message
        );

        bytes32 messageId = IRouterClient(i_router).ccipSend{value: fee}(
            _srcChainSelector,
            message
        );

        emit MessageSent(messageId);
    }

    function getFeeETH(
        address _destShare,
        uint256 _amount,
        address _srcAssetReceiver
    ) public view returns (uint256 fee) {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver[srcAsset[_destShare].chainSelector]),
            data: abi.encodeWithSignature(
                "redeem(address,uint256,address)",
                srcAsset[_destShare].asset,
                _amount,
                _srcAssetReceiver
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit, strict: false})),
            feeToken: address(0)
        });

        return IRouterClient(i_router).getFee(
            srcAsset[_destShare].chainSelector,
            message
        );
    }

    /*//////////////////////////////////////////////////////////////
                            Receiver Logic
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Receiver functions, only triggered by Chainlink router contract.
     * @param _destShare          The destination share token to mint.
     * @param _destSharesReceiver The account to mint to.
     * @param _amount             The amount of share tokens to mint.
     */
    function mint(
        address _destShare,
        address _destSharesReceiver,
        uint256 _amount
    )   public onlyRouter
    {
        ERC20Token(_destShare).mint(_destSharesReceiver, _amount);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    )   internal override
    {
        address sender = abi.decode(message.sender, (address));
        if (!authorizedTransmitter[sender]) revert NotAuthorizedTrasnmitter();
        (bool success, ) = address(this).call(message.data);
        require(success);
        emit CallSuccessful();
    }

    /*//////////////////////////////////////////////////////////////
                    Testing - Transmitter & Receiver
    //////////////////////////////////////////////////////////////*/

    function doPong(
        uint256 _pong,
        address _receiver,
        uint64  _chainSelector
    )   external payable
    {
        if (mandateFee) {
            if (msg.value < getFeeETHPong(_pong, _receiver, _chainSelector)) {
                revert InsufficientFee();
            }
        }

        _doPong(_pong, _receiver, _chainSelector);
    }

    function _doPong(
        uint256 _pong,
        address _receiver,
        uint64  _chainSelector
    )   internal
    {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: abi.encodeWithSignature("doPong(uint256)", _pong),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: gasLimit, strict: false})
            ),
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

    function getFeeETHPong(
        uint256 _pong,
        address _receiver,
        uint64 _chainSelector
    ) public view returns (uint256 fee) {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: abi.encodeWithSignature(
                "doPong(uint256)",
                _pong
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: gasLimit, strict: false})
            ),
            feeToken: address(0)
        });

        return IRouterClient(i_router).getFee(
            _chainSelector,
            message
        );
    }
}
