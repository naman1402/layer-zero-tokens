// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ILZERC721Core is IERC165 {

    event CreditCleared(bytes32 indexed payloadHash);
    event SendToChain(address indexed from, uint16 indexed dstChainId, bytes indexed toAddress, uint256[] tokenIds); 
    event CreditStored(bytes32 indexed hashedPayload, bytes indexed payload);
    event ReceiveFromChain(uint16 indexed srcChainId, bytes indexed srcAddress, address indexed toAddress, uint256[] tokenIds);
    event SetMinDstGasToTransferAndStore(uint256 indexed minGas);
    event SetDstChainIdToTransferGas(uint16 indexed chainId, uint256 indexed dstChainIdToTransferGas);
    event SetDstChainIdToBatchLimit(uint16 indexed chainId, uint256 indexed chainIdToBatchLimit);


    function clearCredits(bytes memory _payload) external;
    function sendToChain(uint16 _dstChainId, address _toAddress, uint256[] memory _tokenIds) external;

    function sendFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _tokenId, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) external payable;
    function sendBatchFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256[] calldata _tokenIds, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) external payable;
    function estimateSendFee(uint16 _dstChainId, bytes calldata _toAddress, uint256 _tokenId, bool _useZro, bytes calldata _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee);
    function estimateSendBatchFee(uint16 _dstChainId, bytes calldata _toAddress, uint256[] calldata _tokenIds, bool _useZro, bytes calldata _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee);
}

