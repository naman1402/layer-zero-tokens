// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./LZERC20Core.sol";
import "./interfaces/ILZERC20.sol";

/// @notice this contract inherits from LZERC20Core, ERC20, and implements the ILZERC20 interface
/// @dev this contract is used to transfer ERC20 tokens between different chains using LayerZero
/// this contract combines LayerZero cross chain messaging protocol with standard ERC20 token functionality to create token that can be transferred across chains
contract LZERC20 is LZERC20Core, ERC20 {

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint
    ) ERC20(_name, _symbol) LZERC20Core(_lzEndpoint) Ownable(msg.sender){}

    // function supportsInterface(bytes4 interfaceId) public view override(LZERC20Core, IERC165) returns (bool) {
    //     return interfaceId == type(ILZERC20).interfaceId || super.supportsInterface(interfaceId) || interfaceId == type(IERC20).interfaceId;
    // }

    // this function returns the address of the token
    function token() public view virtual override returns (address) {
        return address(this);
    }

    function circulatingSupply() public view virtual override returns (uint256) {
        return totalSupply();
    }

    // inherited from LZERC20Core, this function is handles debiting debiting of tokens
    // if the spender is not _from, then it updates the allowance of the spender (only way to transfer tokens)
    // burn the tokens from the from address and returns the amount
    function _debitFrom(address _from, uint16, bytes calldata, uint256 _amount) internal virtual override returns (uint256) {
        address spender = _msgSender();
        if(_from != spender) _spendAllowance(_from, spender, _amount);
        _burn(_from, _amount);
        return _amount;
    }

    // inherited from LZERC20Core, this function is handles crediting of tokens
    // mints the tokens to the to address and returns the amount
    function _creditTo(uint16, address _toAddress, uint256 _amount) internal virtual override returns (uint256) {
        _mint(_toAddress, _amount);
        return _amount;
    }

    // ERC20 function to return the number of decimals
    function decimals() public pure virtual override returns (uint8) {
        return 18;
    }
}
