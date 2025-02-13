// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {TheFedz} from "./TheFedz.sol";
import {ITimeSlotSystem} from "./interfaces/ITimeSlotSystem.sol";

contract TimeSlotSystem is ITimeSlotSystem, Ownable {

    uint256 public slotDuration;
    uint256 public roundDuration;
    uint256 public roundStartTime;
    uint256 public totalSlots;
    uint256 public currentRoundNumber;

    TheFedz public nftContract;

    mapping(address => Player) public players;
    address[] public playerList;
    uint256[] slots;

    constructor(uint256 _slotDuration, uint256 _roundDuration, address _owner, address _nftContract) Ownable(_owner) {
        slotDuration = _slotDuration;
        roundDuration = _roundDuration;
        nftContract = TheFedz(_nftContract);
        roundStartTime = 0;
        totalSlots = 0;
    }

    function startNewRound(uint256 random) onlyOwner external {
        require(roundStartTime == 0 || block.timestamp >= roundStartTime + roundDuration, "Current round not finished");
        require(nftContract.totalSupply() > 0, "No players registered");

        _updatePlayerSlots(random);
        if (roundStartTime > 0) {
            emit RoundEnded(roundStartTime + roundDuration, currentRoundNumber);
        }
        roundStartTime = block.timestamp;
        currentRoundNumber++;
        emit NewRoundStarted(roundStartTime);
    }

    function getCurrentPlayer() public view returns (address) {
        uint256 currentSlot = (block.timestamp - roundStartTime) / slotDuration;
        return nftContract.ownerOf(slots[currentSlot]);
    }

    function canPlayerAct(address player) public view returns (bool) {
        require(roundStartTime > 0, "No active round");
        require(block.timestamp < roundStartTime + roundDuration, "Round has ended");
        return getCurrentPlayer() == player;
    }

    function isRoundActive() public view returns (bool) {
        return roundStartTime > 0 && block.timestamp < roundStartTime + roundDuration;
    }

    function getRoundTimeLeft() public view returns (uint256) {
        if (roundStartTime == 0 || block.timestamp >= roundStartTime + roundDuration) {
            return 0;
        }
        return (roundStartTime + roundDuration) - block.timestamp;
    }

    function setSlotDuration(uint256 _slotDuration) external onlyOwner {
        slotDuration = _slotDuration;
    }

    function setRoundDuration(uint256 _roundDuration) external onlyOwner {
        roundDuration = _roundDuration;
    }

    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = TheFedz(_nftContract);
    }

    function _updatePlayerSlots(uint256 random) internal {
        uint256 totalSupply = nftContract.totalSupply();
        uint256[] memory nonShuffledSlots = new uint256[](totalSupply);
        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 tokenId = nftContract.tokenByIndex(i);
            nonShuffledSlots[i] = tokenId;
        }
        slots = _shuffleSlots(random, nonShuffledSlots);
        emit SlotsShuffled(random);
    }

    function _shuffleSlots(uint256 random, uint256[] memory slots) internal pure returns(uint256[] memory) {
        // Fisher-Yates shuffle
        uint256 totalSlots = slots.length;
        for (uint256 i = totalSlots - 1; i > 0; i--) {
            uint256 j = random % (i + 1);
            uint256 temp = slots[i];
            slots[i] = slots[j];
            slots[j] = temp;
        }
        return slots;
    }
}
