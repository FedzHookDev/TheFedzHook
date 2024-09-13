// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MockERC721 is ERC721, Ownable {
    using Strings for uint256;

    uint256 private _nextTokenId;
    
    // Mapping from owner address to list of owned token IDs
    mapping(address => uint256[]) private _ownedTokens;

    // Base URI for computing {tokenURI}
    string private _baseTokenURI;

    constructor(string memory name, string memory symbol, address initialOwner, string memory baseTokenURI) 
        ERC721(name, symbol) 
        Ownable(initialOwner)
    {
        _nextTokenId = 1;
        _baseTokenURI = baseTokenURI;
    }

    function mint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _safeMint(to, tokenId);
        _ownedTokens[to].push(tokenId);
        _nextTokenId++;
        return tokenId;
    }

    function mintToContract(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _mint(to, tokenId);
        _ownedTokens[to].push(tokenId);
        _nextTokenId++;
        return tokenId;
    }

    // Function to check if an address is an NFT holder
    function isNFTHolder(address _address) public view returns (bool) {
        return balanceOf(_address) > 0;
    }

    // Function to get all token IDs owned by an address
    function getOwnedTokenIds(address owner) public view returns (uint256[] memory) {
        return _ownedTokens[owner];
    }

    // Override transfer functions to update _ownedTokens
    function _transfer(address from, address to, uint256 tokenId) internal override {
        super._transfer(from, to, tokenId);
        
        // Remove tokenId from previous owner's list
        _removeTokenFromOwnerEnumeration(from, tokenId);

        // Add tokenId to new owner's list
        _ownedTokens[to].push(tokenId);
    }

    // Helper function to remove a token from an owner's list
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256[] storage fromTokens = _ownedTokens[from];
        uint256 lastTokenIndex = fromTokens.length - 1;
        uint256 tokenIndex;

        // Find the index of the token to remove
        for (uint256 i = 0; i <= lastTokenIndex; i++) {
            if (fromTokens[i] == tokenId) {
                tokenIndex = i;
                break;
            }
        }

        // Move the last token to the slot of the token to delete
        if (tokenIndex != lastTokenIndex) {
            fromTokens[tokenIndex] = fromTokens[lastTokenIndex];
        }

        // Remove the last element
        fromTokens.pop();
    }

    // Override _baseURI() to return the base URI for computing {tokenURI}
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // Override tokenURI to return the full URI for a given token ID
    function tokenURI(uint256 tokenId) public view override returns (string memory) {

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    // Function to set the base URI
    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    // Added function to get the next token ID (useful for testing)
    function getNextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

}