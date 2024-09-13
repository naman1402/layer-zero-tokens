// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "erc721a/contracts/IERC721A.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./LZERC721Core.sol";
import "./interfaces/ILZERC721Core.sol";

/// @notice ERC721A is the optimized ERC721 contract for reducing gas fees during minting particularly for batch minting multiple NFTs at once

contract LZERC721A is LZERC721Core, ERC721A, ERC721A__IERC721Receiver {

    constructor(string memory _name, string memory _symbol, uint256 _minGasToTransfer, address _lzEndpoint)  
    ERC721A(_name, _symbol) 
    LZERC721Core(_minGasToTransfer, _lzEndpoint) Ownable(msg.sender) {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(LZERC721Core, ERC721A) returns (bool) {
        return interfaceId == type(ILZERC721Core).interfaceId || super.supportsInterface(interfaceId);
    }

    function _debitFrom(address _from, uint16, bytes memory, uint256 _tokenId) internal virtual override(LZERC721Core) {
        safeTransferFrom(_from, address(this), _tokenId);
    }
    function _creditTo(uint16, address _toAddress, uint256 _tokenId) internal virtual override {
        require(ownerOf(_tokenId) != address(0), "LZERC721A: Token not found");
        safeTransferFrom(address(this), _toAddress, _tokenId);
    }

    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        return ERC721A__IERC721Receiver.onERC721Received.selector;
    }
    
}

