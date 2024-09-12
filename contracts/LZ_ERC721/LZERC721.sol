// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/ILZERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./LZERC721Core.sol";

contract LZERC721 is LZERC721Core, ILZERC721, ERC721 {

    constructor(
        string memory _name,
        string memory _symbol,
        uint _minGasToTransfer,
        address _lzEndpoint
    ) ERC721(_name, _symbol) LZERC721Core(_minGasToTransfer, _lzEndpoint) Ownable(msg.sender) {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(LZERC721Core, ERC721, IERC165) returns (bool) {
        return interfaceId == type(ILZERC721).interfaceId || super.supportsInterface(interfaceId);
    }

    function _debitFrom(address _from, uint16 _dstChainId, bytes memory _toAddress, uint256 _tokenId) internal virtual override {
    }
    function _creditTo(uint16 _srcChainId, address _toAddress, uint256 _tokenId) internal virtual override {
    }



}
