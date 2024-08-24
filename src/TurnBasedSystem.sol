// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {NFTWhitelist} from "./NFTWhitelist.sol";

contract TurnBasedSystem is NFTWhitelist {
    struct PlayerTurn {
        address player;
        uint256 startTime;
        uint256 endTime;
    }

    PlayerTurn public currentTurn;
    mapping(address => uint256) public lastTurnTime;
    mapping(address => uint256) public consecutiveSkippedTurns;

    uint256 public turnDuration;
    uint256 public turnTimeThreshold;
    uint256 public maxConsecutiveSkips;

    address[] public playerQueue;

    event TurnStarted(address player, uint256 startTime, uint256 endTime);
    event TurnSkipped(address player, address skipper);
    event PlayerPenalized(address player, uint256 consecutiveSkips);


    constructor(uint256 _turnDuration, uint256 _turnTimeThreshold, uint256 _maxConsecutiveSkips, address _owner, address _nftContract) NFTWhitelist(_nftContract, _owner) {
        turnDuration = _turnDuration;
        turnTimeThreshold = _turnTimeThreshold;
        maxConsecutiveSkips = _maxConsecutiveSkips;
    }

    modifier onlyDuringTurn(address player) {
        require(currentTurn.player == player, "Not your turn");
        require(block.timestamp >= currentTurn.startTime && block.timestamp < currentTurn.endTime, "Turn expired");
        _;
    }

    function startNextTurn() public onlyNFTOwner(msg.sender){
        require(block.timestamp >= currentTurn.endTime || block.timestamp >= currentTurn.startTime + turnTimeThreshold, "Current turn not finished or threshold not reached");
        
        address nextPlayer = getNextEligiblePlayer();
        currentTurn = PlayerTurn(nextPlayer, block.timestamp, block.timestamp + turnDuration);
        lastTurnTime[nextPlayer] = block.timestamp;
        
        // consecutive skipped turns for the new player
        consecutiveSkippedTurns[nextPlayer] = 0;
        
        emit TurnStarted(nextPlayer, currentTurn.startTime, currentTurn.endTime);
    }

    function skipTurn() public onlyNFTOwner(msg.sender) {
        require(msg.sender != currentTurn.player, "Cannot skip your own turn");
        require(block.timestamp >= currentTurn.startTime + turnTimeThreshold, "Turn time threshold not reached");
        
        address skippedPlayer = currentTurn.player;
        consecutiveSkippedTurns[skippedPlayer]++;
        if (consecutiveSkippedTurns[skippedPlayer] > maxConsecutiveSkips) {
            _penalizePlayer(skippedPlayer);
        }
        
        emit TurnSkipped(skippedPlayer, msg.sender);
        startNextTurn();
    }

    function _penalizePlayer(address player) internal {
        // Implement penalty logic here, e.g., remove from queue or apply other penalties
        for (uint i = 0; i < playerQueue.length; i++) {
            if (playerQueue[i] == player) {
                playerQueue[i] = playerQueue[playerQueue.length - 1];
                playerQueue.pop();
                break;
            }
        }
        emit PlayerPenalized(player, consecutiveSkippedTurns[player]);
    }

    function getNextEligiblePlayer() internal view returns (address) {
        require(playerQueue.length > 0, "No players in queue");
        for (uint i = 0; i < playerQueue.length; i++) {
            if (lastTurnTime[playerQueue[i]] == 0 || block.timestamp - lastTurnTime[playerQueue[i]] >= turnDuration) {
                return playerQueue[i];
            }
        }
        return playerQueue[0]; // If no eligible player, return the first in queue
    }

    function joinQueue() external {
        require(!isInQueue(msg.sender), "Already in queue");
        playerQueue.push(msg.sender);
    }

    function isInQueue(address player) public view returns (bool) {
        for (uint i = 0; i < playerQueue.length; i++) {
            if (playerQueue[i] == player) return true;
        }
        return false;
    }

    function setTurnDuration(uint256 _turnDuration) external onlyOwner {
        turnDuration = _turnDuration;
    }

    function setTurnTimeThreshold(uint256 _turnTimeThreshold) external onlyOwner {
        turnTimeThreshold = _turnTimeThreshold;
    }

    function setMaxConsecutiveSkips(uint256 _maxConsecutiveSkips) external onlyOwner {
        maxConsecutiveSkips = _maxConsecutiveSkips;
    }
}
