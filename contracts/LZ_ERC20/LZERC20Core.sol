// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../LZ_APP/NonBlockingLzApp.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../Lib/BytesLib.sol";
import "./interfaces/ILZERC20Core.sol";


// @notice this contract inherits from NonBlockingLzApp, which stores hash of failed messages and retrying failed messages
// this contract focuses on ensuring ERC20 tokens can be transferred between different chains in a non-blocking manner

abstract contract LZERC20Core is NonBlockingLzApp, ERC165, ILZERC20Core {

    using BytesLib for bytes;
    
    uint256 public constant NO_EXTRA_GAS = 0;
    uint16 public constant PT_SEND = 0;
    bool public useCustomAdapterParams;

    constructor(address _endpoint) NonBlockingLzApp(_endpoint) {}

    // checks if the contract supports a specific interface
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(ILZERC20Core).interfaceId || super.supportsInterface(interfaceId);
    }

    // this function estimates the fee for sending a message to a specific chain,
    /// @param _useZro check whether to use LayerZero native ZRO token for fees
    /// @param _adapterParams additional parameters for gas or fee handling
    function estimateSendFee(uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount, bool _useZro, bytes calldata _adapterParams) public view virtual override returns (uint256 nativeFee, uint256 zroFee) {
        bytes memory payload = abi.encode(PT_SEND, _toAddress, _amount);
        return lzEndpoint.estimateFees(_dstChainId, address(this), payload, _useZro, _adapterParams);
    }

    // function that facilitates the sending of tokens to a specified destination chain
    // @param _from address of the sender
    // @param _dstChainId ID of the destination chain
    // @param _toAddress address of the recipient on the destination chain
    // @param _amount amount of tokens to send
    // @param _refundAddress address to receive refunds for any unused gas
    // @param _zroPaymentAddress address to receive ZRO payments for LayerZero fees
    // @param _adapterParams additional parameters for gas or fee handling
    // this function calls the _send function to perform the actual send operation, which is implemented by the child contract
    function sendFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) public payable virtual override {
        _send(_from, _dstChainId, _toAddress, _amount, _refundAddress, _zroPaymentAddress, _adapterParams);
    }

    // @notice inherited from NonBlockingLzApp, this function is called when a message is received
    // @param _srcChainId ID of the source chain
    // @param _srcAddress address of the sender on the source chain
    // @param _nonce sequence number of the message
    // @param _payload contains the data sent from the source chain
    // using assembly to decode the first 32 bytes of the payload to get the packet type
    // if packet type is PT_SEND which mean it is a token transfer, it calls the _sendAck function to process the packet or else revert for other packet type
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual override {
        uint16 packetType;
        assembly {
            packetType := mload(add(_payload, 32))
        }

        if(packetType == PT_SEND){
            _sendAck(_srcChainId, _srcAddress, _nonce, _payload);
        } else {
            revert("LZERC20Core: invalid packet type");
        }
    }

    // extended or modified by child contracts to perform the actual send operation
    function _send(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) internal virtual{}

    // called when message containing token transfer is successfully received
    // decoces the rec payload into AddressByte and amount
    // calls _creditTo to update the token balance of the recipient on the source chain
    // emits a ReceiveFromChain event to indicate the transfer
    function _sendAck(uint16 _srcChainId, bytes memory, uint64, bytes memory _payload) internal virtual {
        (, bytes memory toAddressBytes, uint amount) = abi.decode(_payload, (uint16, bytes, uint256));
        address to = toAddressBytes.toAddress(0);
        amount = _creditTo(_srcChainId, to, amount);
        emit ReceiveFromChain(_srcChainId, to, amount);
    }

    // if custom adapter params are used, it checks if the gas limit is set correctly  
    // (LzApp contract function _checkGasLimit)
    function _checkAdapterParams(uint16 _dstChaindId, uint16 _pkType, bytes memory _adapterParams, uint256 _extraGas) internal virtual {
        if(useCustomAdapterParams){
            _checkGasLimit(_dstChaindId, _pkType, _adapterParams, _extraGas);
        } else {
            require(_adapterParams.length == 0, "LZERC20Core: _adapterParams must be empty");
        }
    }

    // can only be called by the owner of the contract
    // sets the useCustomAdapterParams flag to the value of the _useCustomAdapterParams parameter
    function setUseCustomAdapterParams(bool _useCustomAdapterParams) public virtual onlyOwner {
        useCustomAdapterParams = _useCustomAdapterParams;
        emit SetUseCustomAdapterParams(_useCustomAdapterParams);
    }

    // function to be implemented by child contracts to debit tokens from the sender
    function _debitFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount) internal virtual returns (uint256);

    // function to be implemented by child contracts to credit tokens to the recipient  
    function _creditTo(uint16 _srcChainId, address _toAddress, uint256 _amount) internal virtual returns (uint256);
}