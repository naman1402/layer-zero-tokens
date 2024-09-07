// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./LZERC20Core.sol";
import "./interfaces/ILZERC20.sol";

contract LZERC20 is LZERC20Core, ERC20, ILZERC20 {
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint
    ) ERC20(_name, _symbol) LZERC20Core(_lzEndpoint) {}

    function supportsInterface(bytes4 interfaceId) public view override(LZERC20Core, IERC165) returns (bool) {
        return interfaceId == type(ILZERC20).interfaceId || super.supportsInterface(interfaceId) || interfaceId == type(IERC20).interfaceId;
    }
    function token() public view override returns (address) {
        return address(this);
    }

    function circulatingSupply() public view override returns (uint256) {
        return totalSupply();
    }


    function _debitFrom(address _from, uint16, bytes calldata, uint256 _amount) internal virtual override returns (uint256) {
        address spender = _msgSender();
        if(_from != spender) _spendAllowance(_from, spender, _amount);
        _burn(_from, _amount);
        return _amount;
    }

    function _creditTo(uint16, address _toAddress, uint256 _amount) internal virtual override returns (uint256) {
        _mint(_toAddress, _amount);
        return _amount;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
