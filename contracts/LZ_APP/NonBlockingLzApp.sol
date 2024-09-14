// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ExcessivelySafeCall} from "../Lib/ExcessivelySafeCall.sol";
import "./LzApp.sol";

error NonBlockingLzApp__CanBeCalledOnlyByThisContract();
error NonBlockingLzApp__InvalidPayload();

abstract contract NonBlockingLzApp is LzApp {

    // making low level call that adds safe call mechanism to the call
    using ExcessivelySafeCall for address;

// Calling LzApp contract in the constructor
    constructor(address _endpoint) LzApp(_endpoint) {}

    // sourceId -> source address -> nonce of the message(uniquely identify) -> hash of the message payload
    mapping(uint16 => mapping(bytes => mapping(uint64 => bytes32))) public failedMessages;

    event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason);
    event RetryMessage(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _payloadHash);

    /// @notice overrides the blocking receive function from LzApp
    /// @param _srcChainId: id of the source chain
    /// @param _srcAddress: address of the source contract
    /// @param _nonce: nonce of the message
    /// @param _payload: payload of the message
    /// @dev this function is used to handle messages that are received from source chains
    // this function calls the nonblockingLzReceive() function to handle the message using excessivlySafeCall() to prevent gas-over consumption
    // if the call fails, it stores the failed message in the failedMessages mapping and emits a MessageFailed event
    function _blockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual override {
        (bool success, bytes memory reason) = address(this).excessivelySafeCall(gasleft(), 150, abi.encodeWithSelector(this.nonblockingLzReceive.selector, _srcChainId, _srcAddress, _nonce, _payload));
        if(!success){
            _storeFailedMessage(_srcChainId, _srcAddress, _nonce, _payload, reason);
        }
    }

    /// @notice stores the hash of the failed message in the failedMessages mapping and emits a MessageFailed event
    // internal function, can be called by other functions in the contract
    function _storeFailedMessage(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload, bytes memory _reason) internal {
        failedMessages[_srcChainId][_srcAddress][_nonce] = keccak256(_payload);
        emit MessageFailed(_srcChainId, _srcAddress, _nonce, _payload, _reason);
    }

    /// @notice called by the _blockingLzReceive() function to handle the incoming message which is called by the lzReceive() function in LzApp contract (overriden by ILayerZeroReceiver)
    /// @param _srcChainId: id of the source chain
    /// @param _srcAddress: address of the source contract
    /// @param _nonce: nonce of the message
    /// @param _payload: payload of the message
    // this function call only be called by this contract ONLY
    // further calling internal function _nonblockingLzReceive()
    function nonblockingLzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) public virtual {
        if(_msgSender() != address(this)) revert NonBlockingLzApp__CanBeCalledOnlyByThisContract();
        _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    // TO BE OVERRIDEN BY THE DERIVED CONTRACTS
    // child contract will define what actions to take when a message arrives 
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual;

    /// @dev payloadHash is the hash of the payload that failed to be processed and is stored in the failedMessages mapping
    // hash must exist (not bytes32(0))
    // payload must match the hash (to prevent replay attacks)
    // the message will be processed again by the _nonblockingLzReceive() function and is removed from the mapping
    // emit RetryMessage event
    function retryMessage(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload) public payable virtual {
        
        bytes32 payloadHash = failedMessages[_srcChainId][_srcAddress][_nonce];
        require(payloadHash != bytes32(0), "LZ_APP: no failed message");
        if(keccak256(_payload) != payloadHash) revert NonBlockingLzApp__InvalidPayload();

        failedMessages[_srcChainId][_srcAddress][_nonce] = bytes32(0);
        _nonblockingLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
        emit RetryMessage(_srcChainId, _srcAddress, _nonce, payloadHash);
    }

}