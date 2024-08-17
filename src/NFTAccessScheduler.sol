// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTAccessScheduler is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    IERC721 public nftContract;
    uint256 public accessInterval;
    uint256 public roundEndTime;
    uint256 private currentIndex;

    EnumerableSet.AddressSet private whitelistedAddresses;
    mapping(address => bool) public hasAccessed;
    address[] public currentRound;

    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event NFTContractUpdated(address indexed newNFTContract);
    event AccessIntervalUpdated(uint256 newInterval);
    event RoundEnded(address[] newRoundOrder);

    constructor(address _nftContract, uint256 _accessInterval) {
        nftContract = IERC721(_nftContract);
        accessInterval = _accessInterval;
        roundEndTime = block.timestamp.add(accessInterval);
        currentIndex = 0;
    }

    modifier onlyNFTOwner(address account) {
        require(nftContract.balanceOf(account) > 0, "Not an NFT holder");
        _;
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

    function updateAccessInterval(uint256 _accessInterval) external onlyOwner {
        accessInterval = _accessInterval;
        roundEndTime = block.timestamp.add(accessInterval);
        emit AccessIntervalUpdated(_accessInterval);
    }

    function isWhitelisted(address account) external view returns (bool) {
        return whitelistedAddresses.contains(account);
    }

    function endRound() external onlyOwner {
        require(block.timestamp >= roundEndTime, "Current round not ended");
        currentRound = _shuffle(whitelistedAddresses.values());
        for (uint256 i = 0; i < currentRound.length; i++) {
            hasAccessed[currentRound[i]] = false;
        }
        roundEndTime = block.timestamp.add(accessInterval);
        currentIndex = 0;
        emit RoundEnded(currentRound);
    }

    function accessPool() external {
        require(whitelistedAddresses.contains(msg.sender), "Not whitelisted");
        require(!hasAccessed[msg.sender], "Already accessed this round");
        require(block.timestamp <= roundEndTime, "Round ended");

        hasAccessed[msg.sender] = true;
        _moveToNextTurn();
    }

    function _moveToNextTurn() internal {
        currentIndex = currentIndex.add(1);
        if (currentIndex >= currentRound.length) {
            currentIndex = 0;
        }
    }

    function _shuffle(address[] memory array) internal view returns (address[] memory) {
        for (uint256 i = 0; i < array.length; i++) {
            uint256 n = i + uint256(keccak256(abi.encodePacked(block.timestamp))) % (array.length - i);
            address temp = array[n];
            array[n] = array[i];
            array[i] = temp;
        }
        return array;
    }
}
