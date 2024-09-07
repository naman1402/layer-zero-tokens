// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../LZ_APP/NonBlockingLzApp.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../Lib/BytesLib.sol";
import "./interfaces/ILZERC20Core.sol";


abstract contract LZERC20Core is NonBlockingLzApp, ERC165, ILZERC20Core {

    using BytesLib for bytes;
    
    uint256 public constant NO_EXTRA_GAS = 0;
    uint16 public constant PT_SEND = 0;
    bool public useCustomAdapterParams;

    constructor(address _endpoint) NonBlockingLzApp(_endpoint) {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(ILZERC20Core).interfaceId || super.supportsInterface(interfaceId);
    }

    function estimateSendFee(uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount, bool _useZro, bytes calldata _adapterParams) public view virtual override returns (uint256 nativeFee, uint256 zroFee) {
        bytes memory payload = abi.encode(PT_SEND, _toAddress, _amount);
        return lzEndpoint.estimateFees(_dstChainId, address(this), payload, _useZro, _adapterParams);
    }

    function sendFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) public payable virtual override {
        _send(_from, _dstChainId, _toAddress, _amount, _refundAddress, _zroPaymentAddress, _adapterParams);
    }

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

    function _send(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) internal virtual{}

    function _sendAck(uint16 _srcChainId, bytes memory, uint64, bytes memory _payload) internal virtual {
        (, bytes memory toAddressBytes, uint amount) = abi.decode(_payload, (uint16, bytes, uint256));
        address to = toAddressBytes.toAddress(0);
        amount = _creditTo(_srcChainId, to, amount);
        emit ReceiveFromChain(_srcChainId, to, amount);
    }

    function _checkAdapterParams(uint16 _dstChaindId, uint16 _pkType, bytes memory _adapterParams, uint256 _extraGas) internal virtual {
        if(useCustomAdapterParams){
            _checkGasLimit(_dstChaindId, _pkType, _adapterParams, _extraGas);
        } else {
            require(_adapterParams.length == 0, "LZERC20Core: _adapterParams must be empty");
        }
    }

    function setUseCustomAdapterParams(bool _useCustomAdapterParams) public virtual onlyOwner {
        useCustomAdapterParams = _useCustomAdapterParams;
        emit SetUseCustomAdapterParams(_useCustomAdapterParams);
    }

    function _debitFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount) internal virtual returns (uint256);

    function _creditTo(uint16 _srcChainId, address _toAddress, uint256 _amount) internal virtual returns (uint256);
}