// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface ITimeSlotSystem {

    event Restart(uint256 slotDuration, uint256 startsAt);

    function getCurrentPlayer() external view returns (address);
}