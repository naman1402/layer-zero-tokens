// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@layerzerolabs/lz-evm-sdk-v1-0.7/contracts/interfaces/ILayerZeroUserApplicationConfig.sol";
import "@layerzerolabs/lz-evm-sdk-v1-0.7/contracts/interfaces/ILayerZeroReceiver.sol";
import "@layerzerolabs/lz-evm-sdk-v1-0.7/contracts/interfaces/ILayerZeroEndpoint.sol";
import "../Lib/BytesLib.sol";


// @notice ILayerZeroUserApplicationConfig is the interface used to configure various parameters that a user application interacting with laye zero can customize
// major function: setConfig(), setSendVersion(), setReceiveVersion(), forceResumeReceive() 

// @notice ILayerZeroReceiver is the interface that defines the function that a contract must implement to receive messages from other chains
// main function: lzReceive() is triggered when a message is delivered to the destination chain, it inlcudes params like _srcChainId, _srcAddress, _payload

// @notice ILayerZeroEndpoint is the central component that facilitates sending and receiving messages between chains, 
// send() is used to transmit messages from one chain to another
// receive() is used to handle incoming messages received from other chains, ensures message are delivered reliably and securely to the ILayerZeroReceiver contract


/**
 * LzReceiver is an abstract contract tha represents a generic ILayerZeroReceiver implementation
 * */ 
abstract contract LzApp is Ownable, ILayerZeroUserApplicationConfig, ILayerZeroReceiver {

    using BytesLib for bytes;

    ILayerZeroEndpoint public immutable lzEndpoint;
    // represent system or contract that pre-validates transactions before they are sent to LayerZero
    address public precrime;
    // chainId to trusted remote contract address
    mapping(uint16 => bytes) public trustedRemoteLookup;
    // stores min gas for different types of transactions on destination chains, chain -> message type -> gas
    mapping(uint16 => mapping(uint16 => uint256)) public minDstGasLookup;
    // stores payload size for each limitation chain
    mapping(uint16 => uint256) public payloadSizeLimitLookup;

    uint256 public constant DEFAULT_PAYLOAD_SIZE_LIMIT = 10000;

    constructor(address _lzEndpoint) {
        lzEndpoint = ILayerZeroEndpoint(_lzEndpoint);
    }

    
    // @dev this function originally from ILayerZeroReceiver.sol, 
    // this function is called by the LayerZero protocol when a message is sent from one chain to another and needs to be processed by the destination chain
    // handles incoming messages from other chains
    // @param id of source chain, address of contract on source chain, nonce (to verify the correct order of messages), data being sent
    // lzEndpoint must call this function
    // message must be from trusted remote source (verify using internal mapping and params [_srcAddress])

    function lzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) public virtual override {

        require(msg.sender == address(lzEndpoint), "LzApp: INVALID_SENDER");
        bytes memory trustedRemote = trustedRemoteLookup[_srcChainId];
        require(_srcAddress.length == trustedRemote.length && keccak256(_srcAddress) == keccak256(trustedRemote), "LzApp: srcAddress is not trusted");

        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    // @notice this function is called by lzReceive() to handle the incoming message
    // Must be implemented by child contracts
    function _blockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual;

    // ensures that destination chain is trusted and payload size is within limit
    // Calling Endpoint.send() to send messages to dst chains
    function _lzSend(uint16 _dstChainId, bytes memory _payload, address payable _refundAddress, address _zroPaymentAddress, bytes memory _adapterParams, uint _nativeFee) internal virtual {

        bytes memory trustedRemote = trustedRemoteLookup[_dstChainId];
        require(trustedRemote.length > 0, "LzApp: UNTRUSTED_REMOTE");
        _checkPayloadSize(_dstChainId, _payload.length);
        lzEndpoint.send{value: _nativeFee}(_dstChainId, trustedRemote, _payload, _refundAddress, _zroPaymentAddress, _adapterParams);
    }

    // @notice ensures that payload size is within the limit for the destination chain
    // if no limit is set, it uses a default payload size limit
    // if payload size exceeds the limit, it reverts with an error message
    function _checkPayloadSize(uint16 _dstChainId, uint256 _payloadSize) internal view virtual {

        uint payloadSizeLimit = payloadSizeLimitLookup[_dstChainId];
        if(payloadSizeLimit == 0) {
            payloadSizeLimit = DEFAULT_PAYLOAD_SIZE_LIMIT;
        }
        require(_payloadSize <= payloadSizeLimit, "LzApp: PAYLOAD_SIZE_EXCEEDED");
    }

    // @notice checks if the provided gas limit is sufficient for the transaction
    // minDstGasLookup[_dstChainId][_type] retrieves the minimum gas limit for the given destination chain and message type
    // ensures that the provided gas limit is greater than or equal to the minimum gas limit plus any additional gas required for the transaction
    function _checkGasLimit(uint16 _dstChainId, uint16 _type, bytes memory _adapterParams, uint _extraGas) internal view virtual {
        uint256 providedGasLimit = _getGasLimit(_adapterParams);
        uint256 minGasLimit = minDstGasLookup[_dstChainId][_type];
        require(minGasLimit > 0, "LzApp: MIN_GAS_LIMIT_NOT_SET");
        require(providedGasLimit >= minGasLimit + _extraGas, "LzApp: INSUFFICIENT_GAS");
    }

    // @notice extracts the gas limit from the adapter params
    // uses low-level assembly to extract the gas limit from the first 34 bytes of the adapter params
    function _getGasLimit(bytes memory _adapterParams) internal pure virtual returns (uint gasLimit) {
        require(_adapterParams.length >= 34, "LzApp: INVALID_ADAPTER_PARAMS_LENGTH");
        assembly {
            gasLimit := mload(add(_adapterParams, 34))
        }
    }

    function getConfig(uint16 _version, uint16 _chainId, address, uint _configType) external view returns (bytes memory) {
        return lzEndpoint.getConfig(_version, _chainId, address(this), _configType);
    }

    // ================== ILayerZeroUserApplicationConfig ================== 

    // @notice set configuration for the LayerZero messaging library of the specified version
    function setConfig(uint16 _version, uint16 _chainId, uint _configType, bytes calldata _config) external override onlyOwner {
        lzEndpoint.setConfig(_version, _chainId, _configType, _config);
    }


    // @notice set the send() LayerZero messaging library version to _version
    function setSendVersion(uint16 _version) external override onlyOwner {
        lzEndpoint.setSendVersion(_version);
    }

    // @notice set the lzReceive() LayerZero messaging library version to _version
    function setReceiveVersion(uint16 _version) external override onlyOwner {
        lzEndpoint.setReceiveVersion(_version);
    }

    // @notice only when the UA needs to resume the message flow in blocking mode and clear the stored payloads
    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external override onlyOwner {
        lzEndpoint.forceResumeReceive(_srcChainId, _srcAddress);
    }

    function setTrustedRemote(uint16 _remoteChainId, bytes calldata _path) external onlyOwner {
        trustedRemoteLookup[_remoteChainId] = _path;
    }

    function setTrustedRemoteAddress(uint16 _remoteChainId, bytes calldata _remoteAddress) external onlyOwner{
        trustedRemoteLookup[_remoteChainId] = abi.encodePacked(_remoteAddress, address(this));
    }

    function getTrustedRemoteAddress(uint16 _remoteChainId) external view returns (bytes memory) {
        bytes memory path = trustedRemoteLookup[_remoteChainId];
        require(path.length > 0, "LzApp: UNTRUSTED_REMOTE");
        return path.slice(0, path.length - 20);
    }

    function setPrecrime(address _precrime) external onlyOwner {
        precrime = _precrime;
    }

    function setMinDstGas(uint16 _dstChainId, uint16 _packetType, uint _minGas) external onlyOwner { 
        minDstGasLookup[_dstChainId][_packetType] = _minGas;
    }

    function setPayloadSizeLimit(uint16 _dstChainId, uint _size) external onlyOwner {
        payloadSizeLimitLookup[_dstChainId] = _size;
    }

    function isTrustedRemote(uint16 _srcChainId, bytes calldata _srcAddress) external view returns (bool) {
        bytes memory trustedSource = trustedRemoteLookup[_srcChainId];
        return keccak256(trustedSource) == keccak256(_srcAddress);
    }
    
}
