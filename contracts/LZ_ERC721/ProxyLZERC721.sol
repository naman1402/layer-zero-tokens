// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./LZERC721Core.sol";

/// @notice ProxyLZERC721 is a contract that is used to proxy the LZERC721Core contract
/// Instead of inheriting the ERC721 contract like the LZERC721 contract and creating a custom NFT contract, 
// this contract directly uses the ERC721 contract using `token`
// because of this, the debit and credit function can directly call token.safeTransferFrom and transfer the NFT between accounts
contract ProxyLZERC721 is LZERC721Core, IERC721Receiver {

    using ERC165Checker for address;

    IERC721 public immutable token;

    constructor(uint256 _minGasToTransfer, address _lzEndpoint, address _proxyToken) LZERC721Core(_minGasToTransfer, _lzEndpoint) Ownable(msg.sender) {
        require(_proxyToken.supportsInterface(type(IERC721).interfaceId), "ProxyLZERC721: Proxy token does not implement IERC721");
        token = IERC721(_proxyToken);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    function _debitFrom(address _from, uint16, bytes memory, uint256 _tokenId) internal virtual override {
        require(_from == _msgSender(), "ProxyLZERC721: Debit from must be called by the token owner");
        token.safeTransferFrom(_from, address(this), _tokenId);
    }
    function _creditTo(uint16, address _toAddress, uint256 _tokenId) internal virtual override {
        token.safeTransferFrom(address(this), _toAddress, _tokenId);
    }

    /// @notice this function is designed to handle the receipt of an ERC721 token
    /// operator is the address that initiated the transfer
    /// if the operator is not the token contract, it returns 0
    /// else returns magic value (IERC721Receiver.onERC721Received.selector)
    /// @notice this function is typically called by safeTransferFrom, so basically when _debitFrom or _creditTo is called -> token.safeTransferFrom is also called
    /// which triggers this function and returns the function selector of IERC721Receiver.onERC721Received
    function onERC721Received(address operator, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        if(operator != address(token)) return bytes4(0);
        return IERC721Receiver.onERC721Received.selector;
    }
    
}

