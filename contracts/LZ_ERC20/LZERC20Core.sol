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

    function _sendAck(uint16 _srcChainId, bytes memory, uint64, bytes memory _payload) internal virtual {}

    function _debitFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount) internal virtual returns (uint256);

    function _creditTo(uint16 _srcChainId, bytes calldata _toAddress, uint256 _amount) internal virtual returns (uint256);
}