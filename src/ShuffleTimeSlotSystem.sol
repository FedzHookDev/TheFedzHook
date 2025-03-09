// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {TheFedz} from "./TheFedz.sol";
import {ITimeSlotSystem} from "./interfaces/ITimeSlotSystem.sol";

import {console} from "forge-std/console.sol";

contract ShuffleTimeSlotSystem is ITimeSlotSystem, Ownable {

    struct Round {
        uint256 startsAt;
        uint256 slotDuration;
        uint256 random;
        uint[] slots;
    }

    TheFedz public nftContract;

    Round public round;
    Round public nextRound;

    uint256 public roundCounter;
    bytes32 public randomSeed;

    constructor(address _owner, address _nftContract) Ownable(_owner) {
        nftContract = TheFedz(_nftContract);
        randomSeed = keccak256(abi.encodePacked(blockhash(block.number-1)));
    }

    function restart(uint256 _startsAt) external onlyOwner {
        restart(_startsAt, round.slotDuration);
    }

    function restart(uint256 _startsAt, uint256 _slotDuration) public onlyOwner {
        require(_startsAt >= block.timestamp, "Invalid start time");
        emit Restart(_slotDuration, _startsAt);
        nextRound.slotDuration = _slotDuration;
        nextRound.startsAt = _startsAt;
        (uint256 roundNumber, uint256 random) = shuffleSlotsForNextRound();
        emit NextRoundAnnouncement(roundNumber, random, nextRound.slotDuration, nextRound.startsAt, nextRound.slots);
    }

    function getCurrentPlayer() public returns (address) {
        if (nextRound.startsAt > 0 && block.timestamp >= nextRound.startsAt) {
            round = nextRound;
            uint256 currentSlot = currentSlot();
            emit RoundStarted(roundCounter, currentSlot, round.startsAt, round.slotDuration, round.slots.length);
            uint256 slotsLeft = round.slots.length - currentSlot;
            nextRound.startsAt = block.timestamp + slotsLeft * round.slotDuration;
            nextRound.slotDuration = round.slotDuration;
            (uint256 roundNumber, uint256 random) = shuffleSlotsForNextRound();
            emit NextRoundAnnouncement(roundNumber, random, nextRound.slotDuration, nextRound.startsAt, nextRound.slots);
        }
        return getPlayerByTimestamp(block.timestamp);
    }

    function getPlayerByTimestamp(uint256 timestamp) public view returns (address) {
        uint tokenIdTurn = getTokenIdByTimestamp(timestamp);
        return tokenIdTurn > 0 ? nftContract.ownerOf(tokenIdTurn) : address(0);
    }

    function getTokenIdByTimestamp(uint256 timestamp) public view returns (uint256) {
        if (!isActiveOn(timestamp)) {
            return 0;
        }
        uint256 totalTurns = nftContract.totalSupply(); // totalPlayers
        if (totalTurns == 0) {
            return 0;
        }
        uint256 currentSlot = ((timestamp - round.startsAt) / round.slotDuration) % totalTurns;
        uint256 currentPlayerIdx = round.slots[currentSlot];
        // currentSlot -> actualSlot by random
        uint256 tokenId = nftContract.tokenByIndex(currentPlayerIdx);
        return tokenId;
    }

    function currentSlot() public view returns (uint256) {
        return slotByTimestamp(block.timestamp);
    }

    function slotByTimestamp(uint256 timestamp) public view returns (uint256) {
        return ((timestamp - round.startsAt) / round.slotDuration) % nftContract.totalSupply();
    }

    function roundStartedAt() public view returns (uint256) {
        return nextRound.startsAt > 0 && block.timestamp >= nextRound.startsAt ? nextRound.startsAt : round.startsAt;
    }

    function nextRoundStartAt() public view returns (uint256) {
        if (nextRound.startsAt > block.timestamp) {
            return nextRound.startsAt;
        }
        return 0;
    }

    function nextSlotDuration() public view returns (uint256) {
        return nextRound.slotDuration;
    }

    function isStarted() public view returns (bool) {
        return isActiveOn(block.timestamp);
    }

    function isActiveOn(uint timestamp) public view returns (bool) {
        if (nextRound.startsAt > 0 && timestamp >= nextRound.startsAt) {
            return true;
        }
        if (round.startsAt > 0 && timestamp >= round.startsAt) {
            return true;
        }
        return false;
    }

    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = TheFedz(_nftContract);
    }

    function shuffleSlotsForNextRound() internal returns (uint256 roundNumber, uint256 random) {
        uint256 totalSlots = nftContract.totalSupply();
        roundNumber = ++roundCounter;
        random = uint256(keccak256(abi.encodePacked(randomSeed, roundNumber)));
        // Fisher-Yates shuffle
        nextRound.slots = new uint[](totalSlots);
        for (uint256 i = 0; i < totalSlots-1; i++) {
            nextRound.slots[i] = nftContract.tokenByIndex(i);
        }
        for (uint256 i = totalSlots - 1; i > 0; i--) {
            uint256 j = random % (i + 1);
            uint256 temp = nextRound.slots[i];
            nextRound.slots[i] = nextRound.slots[j];
            nextRound.slots[j] = temp;
        }
    }
}
