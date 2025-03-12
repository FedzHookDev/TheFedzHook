// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {TheFedz} from "./TheFedz.sol";
import {IAccessManager} from "./interfaces/IAccessManager.sol";
import {TimeSlotLibrary} from "./TimeSlotSystemLibrary.sol";
import {InfinteRandomLibrary} from "./InfinteRandomLibrary.sol";
import {ArrayNFTLibrary} from "./ArrayNFTLibrary.sol";
import {RoundLibrary} from "./RoundLibrary.sol";


abstract contract RoundsIterator {

    using RoundLibrary for RoundLibrary.Round;
        
    RoundLibrary.Round public round;
    RoundLibrary.Round public nextRound;

    function isRoundLocked() external view returns (bool) {
        return _isLocked();
    }

    function getSlotValueByTimestamp(uint256 timestamp) public view returns (uint256 tokenId) {
        if (!isActiveOn(timestamp)) {
            return 0;
        }
        RoundLibrary.Round memory r = _getCurrentRound();
        tokenId = r.currentSlotValue();
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

    function nextSlotDuration() public view returns (uint256) {
        return nextRound.slotDuration;
    }

    function _unlockRound() internal returns (bool affected) {
        affected = _isLocked();
        if (affected) {
            round = nextRound;
            delete nextRound;
        }
    }

    function _getCurrentRound() internal view returns (RoundLibrary.Round memory) {
        return nextRound.startsAt == 0 || block.timestamp < nextRound.startsAt ? round : nextRound;
    }

    function _isLocked() internal view returns (bool) {
        return nextRound.startsAt > 0 && block.timestamp >= nextRound.startsAt;
    }

    function _prepareNextRoundState(uint256 slotDuration, uint256 startsAt, uint256[] memory slots) internal {
        require(startsAt >= block.timestamp, "Invalid start time");
        require((startsAt - round.startsAt) % slotDuration == 0, "Invalid start time: not aligned with slot duration");
        if (round.isRunning()) {
            nextRound = round.nextRound(slots);
        } else {
            nextRound.init(slots, startsAt, slotDuration);
        }
    }

}
