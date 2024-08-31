// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract NFTAccessScheduler is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC721 public nftContract;


    EnumerableSet.AddressSet private whitelistedAddresses;
    mapping(address => bool) public hasAccessed;

    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event NFTContractUpdated(address indexed newNFTContract);

    constructor(address _nftContract, address initalOwner) Ownable(initalOwner) {
        nftContract = IERC721(_nftContract);
    
    }

    modifier onlyNFTOwner(address account) {
        require(nftContract.balanceOf(account) > 0, "Not an NFT holder");
        _;
    }

    function addToWhitelist(address account) external onlyOwner onlyNFTOwner(account) {
        bool added = whitelistedAddresses.add(account);
        require(added, "Address already whitelisted");
        emit AddedToWhitelist(account);
    }

    function removeFromWhitelist(address account) external onlyOwner {
        bool removed = whitelistedAddresses.remove(account);
        require(removed, "Address was not whitelisted");
        emit RemovedFromWhitelist(account);
    }

    function updateNFTContract(address _nftContract) external onlyOwner {
        nftContract = IERC721(_nftContract);
        emit NFTContractUpdated(_nftContract);
    }


    function isWhitelisted(address account) external view returns (bool) {
        return whitelistedAddresses.contains(account);
    }

    function getWhitelistedAddresses() external view returns (address[] memory) {
        return whitelistedAddresses.values();
    }
}
