// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../LZ_APP/NonBlockingLzApp.sol";
import "./interfaces/ILZERC721Core.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract LZERC721Core is NonBlockingLzApp, ERC165, ReentrancyGuard, ILZERC721Core {

    // keep track of the stored credit (partial transfer of NFTs) which were interrupted
    struct StoredCredit{
        uint16 srcChainId;
        address toAddress;
        uint256 index;
        bool creditsRemain;
    }

    /// @dev minGasToTransferAndStore is the minimum gas required for transferring and storing NFTs
    /// @dev dstChainIdToBatchLimit is the number of tokens that can be transferred in a batch per destination chain
    /// @dev dstChainIdToTransferGas is the gas required for transferring tokens to destination chain
    /// @dev storedCredits stored credit of unfinished transfers using hashed payload as the key 
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

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(ILZERC721Core).interfaceId || super.supportsInterface(interfaceId);
    }

    // for single NFT transfer, it is converted into uint256[](1) array and calls the estimateSendBatchFee function
    function estimateSendFee(
        uint16 _dstChainId,
        bytes memory _toAddress,
        uint _tokenId,
        bool _useZro,
        bytes memory _adapterParams
    ) public view virtual override returns (uint256 nativeFee, uint256 zroFee) {
        return estimateSendBatchFee(_dstChainId, _toAddress, _toSingletonArray(_tokenId), _useZro, _adapterParams);
    }

    /// @notice estimateSendBatchFee is used to estimate the fee for sending a batch of NFTs
    /// @param dstChainId is the destination chain id
    /// @param _toAddress is the address of the receiver on the destination chain
    /// @param _tokenId is the tokenId of the NFT to be sent
    /// @param _useZro is a boolean to use zro payment
    /// @param _adapterParams is the adapter parameters for the LayerZero adapter
    /// @return nativeFee is the native fee for the transaction
    /// @return zroFee is the zro fee for the transaction
    /// encode the toAddress and tokenId into a bytes memory and call the estimateFees function of the lzEndpoint
    /// main operation is done by the endpoint contract (mock)
    function estimateSendBatchFee(
        uint16 dstChainId, 
        bytes memory _toAddress, 
        uint256[] memory _tokenId, 
        bool _useZro,
        bytes memory _adapterParams
    ) public view virtual override returns (uint256 nativeFee, uint256 zroFee) {
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
    ) public payable virtual override {
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
    ) public payable virtual override {
        _send(_from, _dstChainId, _toAddress, _tokenIds, _refundAddress, _zroPaymentAddress, _adapterParams);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////// CORE FUNCTIONS ////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // needs the ability to iterate and stop if the minGasToTransferAndStore is not met
    // srcChain has the ability to transfer more chainIds
    /// @notice _creditTill is the internal function to credit the NFTs to the receiver
    /// @param _srcChainId is the source chain id
    /// @param _toAddress is the address of the receiver
    /// @param _startIndex is the start index of the tokenIds to be credited
    /// @param _tokenIds is the tokenIds of the NFTs to be credited
    /// @return the nextIndex to indicate how many NFTs were credited
    /// before crediting NFT to the receiver, it checks if the gas left is less than minGasToTransferAndStore
    /// if so, it breaks the loop and returns the current index
    /// otherwise, it credits the NFT to the receiver and increments the index
    function _creditTill(uint16 _srcChainId, address _toAddress, uint256 _startIndex, uint256[] memory _tokenIds) internal returns (uint256) {

        uint256 i =_startIndex;
        while(i < _tokenIds.length) {
            if(gasleft() < minGasToTransferAndStore) break;

            _creditTo(_srcChainId, _toAddress, _tokenIds[i]);
            i++;
        }

        return i;
    }

    /// ACTION TAKEN WHEN A MESSAGE IS RECEIVED 
    /// @notice _nonblockingLzReceive is the internal function to receive a batch of NFTs (NonBlockingLzApp virtual function)
    /// decode the payload to get the toAddress and tokenIds
    /// uses assembly to get the toAddress (address) from the bytes memory
    /// calls the _creditTill function to credit the NFTs to the receiver and return the nextIndex to indicate how many NFTs were credited
    /// stores the remaining NFTs (nextIndex < tokenIds.length) in the storedCredits mapping using the payload hash as the key
    /// emits the ReceiveFromChain event
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 /*_nonce*/, bytes memory _payload) internal virtual override {

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

    /// @notice _send is the internal function to send a batch of NFTs
    /// @param _from is the address of the sender
    /// @param _dstChainId is the destination chain id
    /// @param _toAddress is the address of the receiver on the destination chain
    /// @param _tokenIds is the tokenIds of the NFTs to be sent
    /// @param _refundAddress is the address of the refund address
    /// @param _zroPaymentAddress is the address of the zro payment address
    /// @param _adapterParams is the adapter parameters for the LayerZero adapter
    /// checks the tokendIds length and compare it with the dstChainIdToBatchLimit[_dstChainId]
    /// iterates through the tokenIds and calls the _debitFrom function (implemented in the child contract) to debit the NFTs from the sender
    /// encodes the toAddress and tokenIds into a bytes memory and calls the _checkGasLimit function to check the gas limit
    /// @dev calls the _lzSend function to send the NFTs to the destination chain (lzApp contract)
    /// emits the SendToChain event
    function _send(
        address _from, 
        uint16 _dstChainId, 
        bytes memory _toAddress, 
        uint256[] memory _tokenIds, 
        address payable _refundAddress, 
        address _zroPaymentAddress, 
        bytes memory _adapterParams
    ) internal virtual {
        require(_tokenIds.length > 0);
        require(_tokenIds.length == 1 || _tokenIds.length <= dstChainIdToBatchLimit[_dstChainId], "LZERC721Core: batch size exceeds dst batch limit");

        for(uint256 i = 0; i < _tokenIds.length; i++) {
            _debitFrom(_from, _dstChainId, _toAddress, _tokenIds[i]);
        }

        bytes memory payload = abi.encode(_toAddress, _tokenIds);
        _checkGasLimit(_dstChainId, FUNCTION_TYPE_SEND, _adapterParams, dstChainIdToTransferGas[_dstChainId] * _tokenIds.length);
        _lzSend(_dstChainId, payload, _refundAddress, _zroPaymentAddress, _adapterParams, msg.value);
        emit SendToChain(_from, _dstChainId, _toAddress, _tokenIds);
    }

    /// @notice clearCredits is called by relayers to clear the credits of unfinished transfers
    /// @param _payload is the payload of the transfer that was interrupted
    /// first checks if the credits have already been cleared (creditRemain is false)
    /// then decodes the _payload to get the tokenIds
    /// @notice calls the _creditTill() function to continue the transfer
    // _creditTill() is the function that credits the NFT from index till either gas runs out or all the NFTs are credited
    function clearCredits(bytes memory _payload) external virtual nonReentrant{
        bytes32 payloadHash = keccak256(_payload);
        require(storedCredits[payloadHash].creditsRemain, "LZERC721Core: credits have already been cleared");
        (, uint256[] memory tokenIds) = abi.decode(_payload, (bytes, uint256[]));


        uint256 nextIndex = _creditTill(storedCredits[payloadHash].srcChainId, storedCredits[payloadHash].toAddress, storedCredits[payloadHash].index, tokenIds);
        require(nextIndex > storedCredits[payloadHash].index, "LZERC721Core: credits have already been cleared");


        if(nextIndex == tokenIds.length) {
            delete storedCredits[payloadHash];
            emit CreditCleared(payloadHash);
        } else {
            storedCredits[payloadHash] = StoredCredit(storedCredits[payloadHash].srcChainId, storedCredits[payloadHash].toAddress, nextIndex, true);
        }
    }

   /**
    * ONLY OWNER FUNCTION
    */ 
    function setMinDstGasToTransferAndStore(uint256 _minGas) external onlyOwner {
        require(_minGas > 0);
        minGasToTransferAndStore = _minGas;
        emit SetMinDstGasToTransferAndStore(_minGas);
    }

    

    function setDstChainIdToTransferGas(uint16 _dstChainId, uint256 _dstChainIdToTransferGas) external onlyOwner {
        require(_dstChainIdToTransferGas > 0);
        dstChainIdToTransferGas[_dstChainId] = _dstChainIdToTransferGas;
        emit SetDstChainIdToTransferGas(_dstChainId, _dstChainIdToTransferGas);
    }



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

   // HELPER FUNCTION
    function _toSingletonArray(uint256 element) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }

}

