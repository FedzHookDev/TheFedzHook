// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface ITimeSlotSystem {

    event Restart(uint256 slotDuration, uint256 startsAt);
    event NextRoundAnnouncement(uint256 roundNumber, uint256 random, uint256 slotDuration, uint256 startsAt, uint256[] slots);
    event RoundStarted(uint256 roundNumber, uint256 currentSlot, uint256 startsAt, uint256 slotDuration, uint256 playersCount);

    function getCurrentPlayer() external returns (address);
}
