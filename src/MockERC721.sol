// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC721 is ERC721, Ownable {
    uint256 private _nextTokenId;

    constructor(string memory name, string memory symbol, address initialOwner) 
        ERC721(name, symbol) 
        Ownable(initialOwner)
    {
        _nextTokenId = 1;
    }

    function mint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _safeMint(to, tokenId);
        _nextTokenId++;
        return tokenId;
    }

    function mintToContract(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _mint(to, tokenId);  // Changed from _safeMint to _mint
        _nextTokenId++;
        return tokenId;
    }

     // Function to check if an address is an NFT holder
    function isNFTHolder(address _address) public view returns (bool) {
        return balanceOf(_address) > 0;
    }

    // Optional: Override _baseURI() if you want to set a base URI for token metadata
    function _baseURI() internal pure override returns (string memory) {
        return "https://example.com/token/";
    }

    // Added function to get the next token ID (useful for testing)
    function getNextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }
}
