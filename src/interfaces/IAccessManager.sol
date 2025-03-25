// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IAccessManager {

    event NextRoundAnnouncement(uint256 roundNumber, uint256 random, uint256 slotDuration, uint256 startsAt, uint256[] turnOrder);

    error NotAllowed(address caller);

}
