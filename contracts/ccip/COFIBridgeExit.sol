// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "./utils/Withdraw.sol";
import {ERC20Token} from "../token/mock/ERC20Token.sol";
import "hardhat/console.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
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

    // Testing
    address public testDestShare;
    uint256 public ping;

    // COFI vars
    struct SourceAsset {
        address asset; // E.g., coUSDeth.
        uint64 chainSelector; // E.g., ETH_CHAIN_SELECTOR.
    }
    // E.g., wcoUSDeth-OP => SourceAsset.
    mapping(address => SourceAsset) srcAsset;
    mapping(uint64 => address) public receiver;

    // Access
    mapping(address => bool) public authorizedTransmitter;
    mapping(address => bool) public authorized;

    constructor(
        address _router,
        address _link,
        // Set initial source params.
        address _destShare,
        address _srcAsset,
        uint64 _srcChainSelector
        // Set seperately.
        // address _receiver
    ) CCIPReceiver(_router) {
        i_link = _link;
        LinkTokenInterface(i_link).approve(i_router, type(uint256).max);
        srcAsset[_destShare].asset = _srcAsset;
        srcAsset[_destShare].chainSelector = _srcChainSelector;
        testDestShare = _destShare;
        // receiver[_srcChainSelector] = _receiver;
        mandateFee = true;
        gasLimit = 200_000;
        authorized[msg.sender] = true;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender], "Caller not authorized");
        _;
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                        Admin Setters & Getters
    //////////////////////////////////////////////////////////////*/

    function setAuthorized(
        address _account,
        bool _authorized
    ) external onlyAuthorized {
        authorized[_account] = _authorized;
    }

    function setAuthorizedTransmitter(
        address _account,
        bool _authorized
    ) external onlyAuthorized {
        authorizedTransmitter[_account] = _authorized;
    }

    function setSourceAsset(
        address _destShare,
        uint64 _srcChainSelector,
        address _srcAsset
    ) external onlyAuthorized {
        /// @dev Opt to link to asset in case source vault changes.
        srcAsset[_destShare].asset = _srcAsset;
        srcAsset[_destShare].chainSelector = _srcChainSelector;
    }

    function setReceiver(
        uint64 _destChainSelector,
        address _receiver,
        bool _authorizedTransmitter
    ) external onlyAuthorized {
        receiver[_destChainSelector] = _receiver;
        authorizedTransmitter[_receiver] = _authorizedTransmitter;
    }

    function setMandateFee(
        bool _enabled
    ) external {
        mandateFee = _enabled;
    }

    function setGasLimit(
        uint256 _gasLimit
    ) external {
        gasLimit = _gasLimit;
    }

    function getSourceAsset(
        address _destShare
    ) external view returns (address) {
        return srcAsset[_destShare].asset;
    }

    function getSourceChainSelector(
        address _destShare
    ) external view returns (uint64) {
        return srcAsset[_destShare].chainSelector;
    }

    /*//////////////////////////////////////////////////////////////
                            Transmitter
    //////////////////////////////////////////////////////////////*/

    function exit(
        address _destShare,
        uint256 _amount,
        address _srcAssetsReceiver
    ) external payable {
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
        uint64 _srcChainSelector,
        address _asset,
        address _recipient,
        uint256 _amount
    ) internal {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver[_srcChainSelector]),
            data: abi.encodeWithSignature("redeem(address,uint256,address)", _asset, _amount, _recipient),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit, strict: false})),
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
                                Receiver
    //////////////////////////////////////////////////////////////*/

    // Do mint test beforehand.
    function mint(
        address _destShare,
        address _destSharesReceiver,
        uint256 _amount
    ) public {
        ERC20Token(_destShare).mint(_destSharesReceiver, _amount);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
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
        uint64 _chainSelector
    ) external payable {
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
        uint64 _chainSelector
    ) internal {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: abi.encodeWithSignature("doPong(uint256)", _pong),
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
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit, strict: false})),
            feeToken: address(0)
        });

        return IRouterClient(i_router).getFee(
            _chainSelector,
            message
        );
    }

    function doPing(
        uint256 _ping
    ) public {
        ping = _ping;
    }

    /*//////////////////////////////////////////////////////////////
                            Testing - Local
    //////////////////////////////////////////////////////////////*/

    /// @notice "Bridging" back arbitrarily minted destination shares will fail if insufficient
    /// source shares do not reside at bridge entry contract.
    function getShares(
        uint256 _amount
    ) external {
        ERC20Token(testDestShare).mint(msg.sender, _amount);
    }

    function testBurn(
        uint256 _amount
    ) external {
        ERC20Token(testDestShare).burn(msg.sender, _amount);
    }
}
