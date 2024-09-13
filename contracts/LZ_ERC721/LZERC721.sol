// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/ILZERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./LZERC721Core.sol";

/// @notice inheriting LZERC721Core which transfers and stors the NFT during cross chain transactions
/// @notice inheriting ERC721 and ILZERC721
contract LZERC721 is LZERC721Core, ILZERC721, ERC721 {

    constructor(
        string memory _name,
        string memory _symbol,
        uint _minGasToTransfer,
        address _lzEndpoint
    ) ERC721(_name, _symbol) LZERC721Core(_minGasToTransfer, _lzEndpoint) Ownable(msg.sender) {}

    /// @notice supportsInterface is used to check for the interfaceId of the contract
    /// @notice overriding the supportsInterface function of LZERC721Core, ERC721 and IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(LZERC721Core, ERC721, IERC165) returns (bool) {
        return interfaceId == type(ILZERC721).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice _debitFrom is used to debit the NFT from the sender
    /// @notice overriding the _debitFrom function of LZERC721Core
    /// it checks the approval of the msgSender and if the owner of NFT is _from or not
    /// then transfers the NFT to the address(this)
    function _debitFrom(address _from, uint16 /*_dstChainId*/, bytes memory /*_toAddress*/, uint256 _tokenId) internal virtual override {

        require(isApprovedForAll(_from, _msgSender()), "ONFT721: send caller is not owner nor approved");
        require(ownerOf(_tokenId) == _from, "LZERC721: transfer caller is not owner");
        _transfer(_from, address(this), _tokenId);

    }

    /// @notice _creditTo is used to credit the NFT to the receiver
    /// makes sure that the NFT exists
    /// if the owner is address(0) then it means that the NFT is not minted yet, so it mints the NFT
    /// else it transfers the NFT to the receiver
    
    function _creditTo(uint16 /*_srcChainId*/, address _toAddress, uint256 _tokenId) internal virtual override {

        // require((ownerOf(_tokenId) != address(0)), "LZERC721: token does not exist");
        // check the existence of the NFT
        if(ownerOf(_tokenId) == address(0)) {
            _safeMint(_toAddress, _tokenId);
        } else {
            transferFrom(address(this), _toAddress, _tokenId);
        }

    }
}
