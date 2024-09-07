// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ILZERC20Core is IERC165 {
    
    function estimateSendFee(uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount, bool _useZro, bytes calldata _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee);
    function sendFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) external payable;
    function circulatingSupply() external view returns (uint256);
    function token() external view returns (address);

    event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes _toAddress, uint256 indexed _amount);
    event ReceiveFromChain(uint16 indexed _srcChainId, address indexed _to, uint256 _amount);
    event SetUseCustomAdapterParams(bool _useCustomAdapterParams);
}
