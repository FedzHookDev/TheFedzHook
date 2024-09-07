// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract NFTWhitelist is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC721 public nftContract;
    EnumerableSet.AddressSet private whitelistedAddresses;

    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event NFTContractUpdated(address indexed newNFTContract);
    error NotNftHolder(address account);

    constructor(address _nftContract, address initalOwner) Ownable(initalOwner) {
        nftContract = IERC721(_nftContract);
    }

    modifier onlyNFTOwner(address account) {
        if(!(nftContract.balanceOf(account) > 0)){
            revert NotNftHolder(account);
        }
        _;
    }

    function isNftHolder(address account) public view returns (bool) {
        return nftContract.balanceOf(account) > 0;
    }

    function addToWhitelist(address account) external onlyOwner onlyNFTOwner(account) {
        whitelistedAddresses.add(account);
        emit AddedToWhitelist(account);
    }

    function removeFromWhitelist(address account) external onlyOwner {
        whitelistedAddresses.remove(account);
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
