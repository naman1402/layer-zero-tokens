// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../LZ_APP/NonBlockingLzApp.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract LZERC721Core is NonBlockingLzApp, ERC165, ReentrancyGuard {

    struct StoredCredit{
        uint16 srcChainId;
        address toAddress;
        uint256 index;
        bool creditsRemain;
    }

    uint256 public minGasToTransferAndStore;
    mapping(uint16 => uint256) public dstChainIdToBatchLimit;
    mapping(uint16 => uint256) public dstChainIdToTransferGas;
    mapping(bytes32 => StoredCredit) public storedCredits;

    uint16 public constant FUNCTION_TYPE_SEND = 1;
    uint16 public constant FUNCTION_TYPE_RECEIVE = 2;

    constructor(uint256 _minGasToTransferAndStore, address _lzEndpoint) NonBlockingLzApp(_lzEndpoint) {
        require(_minGasToTransferAndStore > 0, "LZERC721Core: minGasToTransferAndStore must be greater than 0");
        minGasToTransferAndStore = _minGasToTransferAndStore;
    }

    function clearCredits(bytes memory _payload) external virtual nonReentrant{}

    function estimateSendFee(
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint _tokenId,
        bool _useZro,
        bytes memory _adapterParams
    ) public view virtual returns (uint256 nativeFee, uint256 zroFee) {
        estimateSendBatchFee(_dstChainId, _toAddress, _toSingletonArray(_tokenId), _useZro, _adapterParams);
    }

    function estimateSendBatchFee(
        uint16 dstChainId, 
        bytes memory _toAddress, 
        uint256[] memory _tokenId, 
        bool _useZro,
        bytes memory _adapterParams
    ) public view virtual returns (uint256 nativeFee, uint256 zroFee) {
        bytes memory payload = abi.encode(_toAddress, _tokenId);
        return lzEndpoint.estimateFees(dstChainId, address(this), payload, _useZro, _adapterParams);
    }

    function sendFrom(
        address _from,
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint _tokenId,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _adapterParams
    ) public payable virtual {
        _send(_from, _dstChainId, _toAddress, _toSingletonArray(_tokenId), _refundAddress, _zroPaymentAddress, _adapterParams);
    }
    function sendBatchFrom(
        address _from, 
        uint16 _dstChainId, 
        bytes memory _toAddress, 
        uint256[] memory _tokenIds, 
        address payable _refundAddress, 
        address _zroPaymentAddress, 
        bytes memory _adapterParams
    ) public payable virtual {
        _send(_from, _dstChainId, _toAddress, _tokenIds, _refundAddress, _zroPaymentAddress, _adapterParams);
    }

    function _send(
        address _from, 
        uint16 _dstChainId, 
        bytes memory _toAddress, 
        uint256[] memory _tokenIds, 
        address payable _refundAddress, 
        address _zroPaymentAddress, 
        bytes memory _adapterParams
    ) internal virtual {}

    event CreditStored(bytes32 indexed hashedPayload, bytes indexed payload);
    event ReceiveFromChain(uint16 indexed srcChainId, bytes indexed srcAddress, address indexed toAddress, uint256[] tokenIds);
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal virtual override {

        (bytes memory toAddressinBytes, uint[] memory tokenIds) = abi.decode(_payload, (bytes, uint256[]));
        address toAddress;
        assembly {
            toAddress := mload(add(toAddressinBytes, 20))
        }

        uint256 nextIndex = _creditTill(_srcChainId, toAddress, 0, tokenIds);
        if(nextIndex < tokenIds.length) {

            bytes32 hashedPayload = keccak256(_payload);
            storedCredits[hashedPayload] = StoredCredit(_srcChainId, toAddress, nextIndex, true);
            emit CreditStored(hashedPayload, _payload);
        }

        emit ReceiveFromChain(_srcChainId, _srcAddress, toAddress, tokenIds);
    }

    // needs the ability to iterate and stop if the minGasToTransferAndStore is not met
    // srcChain has the ability to transfer more chainIds
    function _creditTill(uint16 _srcChainId, address _toAddress, uint256 _startIndex, uint256[] memory _tokenIds) internal returns (uint256) {

        uint256 i =_startIndex;
        while(i < _tokenIds.length) {
            if(gasleft() < minGasToTransferAndStore) break;

            _creditTo(_srcChainId, _toAddress, _tokenIds[i]);
            i++;
        }

        return i;
    }

   /**
    * ONLY OWNER FUNCTION
    */ 
    event SetMinDstGasToTransferAndStore(uint256 indexed minGas);
    
    function setMinDstGasToTransferAndStore(uint256 _minGas) external onlyOwner {
        require(_minGas > 0);
        minGasToTransferAndStore = _minGas;
        emit SetMinDstGasToTransferAndStore(_minGas);
    }

    event SetDstChainIdToTransferGas(uint16 indexed chainId, uint256 indexed dstChainIdToTransferGas);

    function setDstChainIdToTransferGas(uint16 _dstChainId, uint256 _dstChainIdToTransferGas) external onlyOwner {
        require(_dstChainIdToTransferGas > 0);
        dstChainIdToTransferGas[_dstChainId] = _dstChainIdToTransferGas;
        emit SetDstChainIdToTransferGas(_dstChainId, _dstChainIdToTransferGas);
    }

    event SetDstChainIdToBatchLimit(uint16 indexed chainId, uint256 indexed chainIdToBatchLimit);

    function setDstChainIdToBatchLimit(uint16 _chainId, uint256 _chainIdToBatchLimit) external onlyOwner {
        require(_chainIdToBatchLimit > 0);
        dstChainIdToBatchLimit[_chainId] = _chainIdToBatchLimit;
        emit SetDstChainIdToBatchLimit(_chainId, _chainIdToBatchLimit);
    }

    /**
     * VIRTUAL FUNCTION
    */
   function _debitFrom(address _from, uint16 _dstChainId, bytes memory _toAddress, uint256 _tokenId) internal virtual;
   function _creditTo(uint16 _srcChainId, address _toAddress, uint256 _tokenId) internal virtual;
    function _toSingletonArray(uint256 element) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }

}

