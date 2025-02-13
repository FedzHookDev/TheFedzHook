// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface ITimeSlotSystem {

    struct Player {
        bool isRegistered;
    }

    event NewRoundStarted(uint256 startTime);
    event PlayerRegistered(address player, uint256 slots);
    event PlayerUnregistered(address player);
    event SlotsShuffled(uint256 random);
    event RoundEnded(uint256 endTime, uint256 roundNumber);

    function getCurrentPlayer() external view returns (address);
    function canPlayerAct(address player) external view returns (bool);
}
