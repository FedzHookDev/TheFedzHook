// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {TheFedz} from "./TheFedz.sol";
import {ITimeSlotSystem} from "./interfaces/ITimeSlotSystem.sol";
import {console} from "forge-std/console.sol";

contract TimeSlotSystem is ITimeSlotSystem, Ownable {


    event NewRoundStarted(uint256 startTime);
    event PlayerRegistered(address player, uint256 slots);
    event PlayerUnregistered(address player);
    event SlotsShuffled(uint256 random);
    event RoundEnded(uint256 endTime, uint256 roundNumber);

    uint256 public slotDuration;
    uint256 public roundDuration;
    uint256 public roundStartTime;
    uint256 public totalSlots;
    // uint256 public currentRoundNumber;
    uint256 public initialRoundStartsAt;

    uint256 public nextRoundStartAt;

    TheFedz public nftContract;

    uint256 randomSeed;
    uint256[] slots;
    uint256 lastShuffleTime;

    bool locked;

    constructor(address _owner, address _nftContract) Ownable(_owner) {
        nftContract = TheFedz(_nftContract);
    }

    modifier onlyWhenNotLocked() {
        require(!locked, "Shuffle is locked");
        _;
    }

    function restart(uint256 _random, uint256 _slotDuration, uint256 _nextRoundStartAt) external onlyOwner {
        randomSeed = _random;
        slotDuration = _slotDuration;
        nextRoundStartAt = _nextRoundStartAt;
        _restart();
    }

    function lockNextShuffle(bool _locked) external onlyOwner {
        locked = _locked;
    }

    function shuffle() external onlyWhenNotLocked {
        _updatePlayerSlots();
    }

    function _restart() internal {
        // require(roundStartTime == 0 || block.timestamp >= roundStartTime + roundDuration, "Current round not finished");
        require(nftContract.totalSupply() > 0, "No players registered");
        _updatePlayerSlots();
        if (roundStartTime > 0) {
            // emit RoundEnded(roundStartTime + roundDuration, currentRoundNumber);
        }
        emit NewRoundStarted(roundStartTime);
    }

    function getCurrentPlayer() public view returns (address) {
        uint256 currentSlot = ((block.timestamp - roundStartTime) / slotDuration) % slots.length;
        return nftContract.ownerOf(slots[currentSlot]);
    }

    function canPlayerAct(address player) public view returns (bool) {
        // require(roundStartTime > 0, "No active round");
        // require(block.timestamp < roundStartTime + roundDuration, "Round has ended");

        // // slots[2] == 0
        // if (block.timestamp >= nextRoundStartAt) {
        //     _shuffleSlots();
        // }
        // // slots[2] == Bob

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

    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = TheFedz(_nftContract);
    }
    // function _updatePlayerSlots() internal {
    // _updateTrunsOrder();
    function _updatePlayerSlots() internal {
        uint256 roundEndsAt = roundStartTime + roundDuration;
        if (block.timestamp < roundEndsAt) {
            return;
        }
        uint256 totalSupply = nftContract.totalSupply();
        uint256[] memory nonShuffledSlots = new uint256[](totalSupply);
        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 tokenId = nftContract.tokenByIndex(i);
            nonShuffledSlots[i] = tokenId;
        }
        if (roundStartTime == 0) {
            roundStartTime = initialRoundStartsAt;
        } else {
            roundStartTime += roundDuration;
        }
        randomSeed = uint256(keccak256(abi.encodePacked(randomSeed)));
        require(block.timestamp >= roundStartTime, "Round not started");
        roundDuration = nonShuffledSlots.length * slotDuration;
        // slots = _shuffleSlots(random, nonShuffledSlots);
        // emit SlotsShuffled(random);
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
