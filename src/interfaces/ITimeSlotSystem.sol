// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface ITimeSlotSystem {

    struct Player {
        bool isRegistered;
        uint256 slots;
        uint256[] actionWindows;
    }

    event NewRoundStarted(uint256 startTime);
    event PlayerRegistered(address player, uint256 slots);
    event PlayerUnregistered(address player);
    event SlotsShuffled();
    event RoundEnded(uint256 endTime, uint256 roundNumber);

    function getCurrentPlayer() external view returns (address);

    function isPlayerActive(address player) external view returns (bool);

    function canPlayerAct(address player) external view returns (bool);

    function getNextActionWindow(address player) external view returns (uint256 startTime, uint256 endTime);

    function getAllActionWindows(address player) external view returns (uint256[] memory startTimes, uint256[] memory endTimes);
}
