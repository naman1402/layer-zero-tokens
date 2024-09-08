// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./LZERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NativeToken is LZERC20, ReentrancyGuard {

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    constructor(address _lzEndpoint) LZERC20("NativeToken", "NT", _lzEndpoint) {}

    function sendFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) public payable virtual override nonReentrant {
        _send(_from, _dstChainId, _toAddress, _amount, _refundAddress, _zroPaymentAddress, _adapterParams);
    }

    function _send(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) internal virtual override(LZERC20Core) {
        uint256 messageFee = _debitFromNative(_from,_dstChainId, _toAddress, _amount);
        bytes memory payload = abi.encode(PT_SEND, _toAddress, _amount);

        if(useCustomAdapterParams){
            _checkGasLimit(_dstChainId, PT_SEND, _adapterParams, NO_EXTRA_GAS);
        }
        else{
            require(_adapterParams.length == 0, "LZERC20: invalid adapterParams length");
        }

        _lzSend(_dstChainId, payload, _refundAddress, _zroPaymentAddress, _adapterParams, messageFee);
    }

    function withdraw(uint256 _amount) public {
        require(balanceOf(msg.sender) >= _amount, "NativeToken: insufficient balance");
        _transfer(msg.sender, address(this), _amount);
        payable(msg.sender).transfer(_amount);
        emit Withdrawal(msg.sender, _amount);
    }

    function _debitFromNative(address _from, uint16, bytes memory, uint256 _amount) internal returns (uint messageFee) {
        messageFee = msg.sender == _from ? _debitMsgSender(_amount) : _debitMsgFrom(_from, _amount);
    }

    function _debitMsgSender(uint _amount) internal returns (uint256 messageFee){
        
        uint256 msgSenderBalance = balanceOf(msg.sender);
        if(msgSenderBalance < _amount){
            require(msgSenderBalance + msg.value >= _amount, "NativeToken: insufficient balance");
            uint256 mintAmount = _amount - msgSenderBalance;
            _mint(address(msg.sender), mintAmount);
            messageFee = msg.value - mintAmount;
        }
        else{
            messageFee = msg.value;
        }
        _transfer(msg.sender, address(this), _amount);
        return messageFee;
    } 

    function _debitMsgFrom(address _from, uint256 _amount) internal returns (uint256 messageFee){
        uint256 msgFromBalance = balanceOf(_from);
        if(msgFromBalance < _amount){
            require(msgFromBalance + msg.value >= _amount, "NativeToken: insufficient balance");
            uint256 mintAmount = _amount - msgFromBalance;
            _mint(address(msg.sender), mintAmount);
            _transfer(msg.sender, address(this), mintAmount);
            _amount = msgFromBalance;
            messageFee = msg.value - mintAmount;
        }
        else{
            messageFee = msg.value;
        }

        _spendAllowance(_from, msg.sender, _amount);
        _transfer(_from, address(this), _amount);
        return messageFee;
    }

    function _creditTo(uint16, address _toAddress, uint256 _amount) internal override(LZERC20) returns (uint256) {
        _burn(address(this), _amount);
        (bool success, ) = _toAddress.call{value: _amount}("");
        require(success, "NativeToken: transfer failed");
        return _amount;
    }

    
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }
    
    receive() external payable {
        deposit();
    }

    
}