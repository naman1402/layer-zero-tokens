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
    address public precrime;
    mapping(uint16 => bytes) public trustedRemoteLookup;
    mapping(uint16 => mapping(uint16 => uint256)) public minDstGasLookup;
    mapping(uint16 => uint) public payloadSizeLimitLookup;

    uint256 public constant DEFAULT_PAYLOAD_SIZE_LIMIT = 10000;

    constructor(address _lzEndpoint) {
        lzEndpoint = ILayerZeroEndpoint(_lzEndpoint);
    }

    
    // @dev this function originally from ILayerZeroReceiver.sol, 
    // this function is called by the LayerZero protocol when a message is sent from one chain to another and needs to be processed by the destination chain
    function lzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) public virtual override {

        require(msg.sender == address(lzEndpoint), "LzApp: INVALID_SENDER");
        bytes memory trustedRemote = trustedRemoteLookup[_srcChainId];
        require(_srcAddress.length == trustedRemote.length && keccak256(_srcAddress) == keccak256(trustedRemote), "LzApp: INVALID_TUPLE");

        _blockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    function _blockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual;

    function _lzSend(uint16 _dstChainId, bytes memory _payload, address payable _refundAddress, address _zroPaymentAddress, bytes memory _adapterParams, uint _nativeFee) internal virtual {

        bytes memory trustedRemote = trustedRemoteLookup[_dstChainId];
        require(trustedRemote.length > 0, "LzApp: UNTRUSTED_REMOTE");
        _checkPayloadSize(_dstChainId, _payload.length);
        lzEndpoint.send{value: _nativeFee}(_dstChainId, trustedRemote, _payload, _refundAddress, _zroPaymentAddress, _adapterParams);
    }

    function _checkPayloadSize(uint16 _dstChainId, uint256 _payloadSize) internal view virtual {

        uint payloadSizeLimit = payloadSizeLimitLookup[_dstChainId];
        if(payloadSizeLimit == 0) {
            payloadSizeLimit = DEFAULT_PAYLOAD_SIZE_LIMIT;
        }
        require(_payloadSize <= payloadSizeLimit, "LzApp: PAYLOAD_SIZE_EXCEEDED");
    }

    function _checkGasLimit(uint16 _dstChainId, uint16 _type, bytes memory _adapterParams, uint _extraGas) internal view virtual {
        uint256 providedGasLimit = _getGasLimit(_adapterParams);
        uint256 minGasLimit = minDstGasLookup[_dstChainId][_type];
        require(minGasLimit > 0, "LzApp: MIN_GAS_LIMIT_NOT_SET");
        require(providedGasLimit >= minGasLimit + _extraGas, "LzApp: INSUFFICIENT_GAS");
    }

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
