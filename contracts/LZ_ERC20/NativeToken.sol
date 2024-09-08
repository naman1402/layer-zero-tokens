// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./LZERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NativeToken is LZERC20, ReentrancyGuard {

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    constructor(address _lzEndpoint) LZERC20("NativeToken", "NT", _lzEndpoint) {}

    // @notice this function is used to send native tokens to the destination chain
    // _from is the address of the user sending the tokens
    // _dstChainId is the id of the destination chain
    // _toAddress is the address of the user on the destination chain
    // _amount is the amount of tokens to be sent
    // _refundAddress is the address to which the refund will be sent if any
    // _zroPaymentAddress is the address to which the zro payment will be sent
    // _adapterParams is the adapter parameters
    function sendFrom(address _from, uint16 _dstChainId, bytes calldata _toAddress, uint256 _amount, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) public payable virtual override nonReentrant {
        _send(_from, _dstChainId, _toAddress, _amount, _refundAddress, _zroPaymentAddress, _adapterParams);
    }

    // Internal function called by the sendFrom()
    // get messagefee depending on the _from and _amount (msg.value)
    // if custom params are used, then check the gas limit (LzApp function)
    // _lzSend() is a function of LzApp contract, ensures that destination chain is trusted and payload size is within limit
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

    // @notice this function is used to withdraw native tokens from the contract
    // pay with native tokens and get eth in return
    function withdraw(uint256 _amount) public {
        require(balanceOf(msg.sender) >= _amount, "NativeToken: insufficient balance");
        _transfer(msg.sender, address(this), _amount);
        payable(msg.sender).transfer(_amount);
        emit Withdrawal(msg.sender, _amount);
    }

    // calls _debitMsgSender or _debitMsgFrom based on the sender of the message (if _from is msg.sender or not)
    function _debitFromNative(address _from, uint16, bytes memory, uint256 _amount) internal returns (uint messageFee) {
        messageFee = msg.sender == _from ? _debitMsgSender(_amount) : _debitMsgFrom(_from, _amount);
    }

    // if the sendFrom() is called by msg.sender then this function is called - sendFrom() -> _send() -> _debitNative() -> _debitMsgSender()
    // checks msg.sender native token balance 
    // if balance is less than the amount to be sent, IF the _amount is greater than balance + msg.value then function will revert
    // the _from already has msgSenderBalance, so number of token that will be minted are `amount - balance` 
    // tokens are minted to msg.sender (_from)  and fee is the extra ether in msg.value (after deducting minted tokens amount)
    // if the _amount is less then balance, no need to mint, directly the fee will be msg.value
    // transferring the _amount token to this contract and returning the fee
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

    // Similar to the _debitMsgSender, it is called when _from is not msg.sender, sendFrom() -> _send() -> _debitNative() -> _debitMsgFrom()
    // calculate the balance of _from, if amount is more than balance then we will have to mint the amount, else no need to mint
    // function wil revert is _amount > balance + msg.value
    // req token = _amount - balance, mint these token to address(msg.sender) and transfer the minted amount to this contract
    // deduct the msg.value by the minted amount and return the fee (extra msg.value sent)
    // handle approval, _from will allow msg.sender to spend _amount, 
    // then transfer _amount to this contract and return messageFee
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

    // burns the amount of tokens being received on the source chain
    // transfer eth to the address _toAddress
    function _creditTo(uint16, address _toAddress, uint256 _amount) internal override(LZERC20) returns (uint256) {
        _burn(address(this), _amount);
        (bool success, ) = _toAddress.call{value: _amount}("");
        require(success, "NativeToken: transfer failed");
        return _amount;
    }

    
    // @notice this function is used to deposit native tokens into the contract
    // pay with eth and get native tokens in return
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    // if someone sends ether to this contract, deposit() is called
    // deposit() will mint the amount of native tokens to the msg.sender
    receive() external payable {
        deposit();
    }

    
}