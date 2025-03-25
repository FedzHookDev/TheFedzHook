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
        
    RoundLibrary.Round round;
    RoundLibrary.Round nextRound;

    struct RoundDescriptor {
        uint256 roundNumber;
        uint256 slotDuration;
        uint256 startsAt;
        uint256 playersCount;
    }

    function rounds() external view returns (RoundDescriptor memory current, RoundDescriptor memory next) {
        current = _describe(_currentRound());
        next = _describe(_nextRound());
    }

    function _currentRound() internal view returns (RoundLibrary.Round memory) {
        return nextRound.startsAt == 0 || block.timestamp < nextRound.startsAt ? round : nextRound;
    }

    function _nextRound() internal view returns (RoundLibrary.Round memory next) {
        if (nextRound.startsAt > 0 && block.timestamp < nextRound.startsAt) {
            return nextRound;
        }
    }

    function _restart(uint256 startsAt, uint256 slotDuration, uint256[] memory slots) internal returns (uint256) {
        require(startsAt >= block.timestamp, "Invalid start time");
        require((startsAt - round.startsAt) % slotDuration == 0, "Invalid start time: not aligned with slot duration");
        nextRound.init(slots, startsAt, slotDuration);
        return nextRound.number;
    }

    function _setNextRound(uint256[] memory slots) internal returns (RoundLibrary.Round memory nextRoundMem) {
        nextRoundMem = round.nextRound(slots);
        nextRound = nextRoundMem;
        return nextRoundMem;
    }

    function _isLocked() internal view returns (bool) {
        return nextRound.startsAt > 0 && block.timestamp >= nextRound.startsAt;
    }

    function _unlockRound() internal {
        require(_isLocked(), "Round is not locked");
        round = nextRound;
        delete nextRound;
    }

    function _getSlotValueByTimestamp(uint256 timestamp) internal view returns (uint256 val) {
        RoundLibrary.Round memory r = _getRoundByTimestamp(timestamp);
        val = r.valueByTimestamp(timestamp);
    }

    function _getCurrentRound() internal view returns (RoundLibrary.Round memory) {
        return _getRoundByTimestamp(block.timestamp);
    }

    function _getRoundByTimestamp(uint timestamp) internal view returns (RoundLibrary.Round memory) {
        return nextRound.startsAt == 0 || timestamp < nextRound.startsAt ? round : nextRound;
    }

    function _describe(RoundLibrary.Round memory r) internal view returns (RoundDescriptor memory d) {
        d.roundNumber = r.number;
        d.slotDuration = r.slotDuration;
        d.startsAt = r.startsAt;
        d.playersCount = r.slots.length;
    }
}
