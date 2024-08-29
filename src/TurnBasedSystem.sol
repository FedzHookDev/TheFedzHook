// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {NFTWhitelist} from "./NFTWhitelist.sol";
import {NFTAccessScheduler} from "./NFTAccessScheduler.sol";

contract TurnBasedSystem is NFTAccessScheduler {
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

    // Events
    event TurnStarted(address player, uint256 startTime, uint256 endTime);
    event TurnSkipped(address player, address skipper);
    event PlayerPenalized(address player, uint256 consecutiveSkips);
    event MultiplePlayersSkipped(address[] skippedPlayers, address skipper);



    constructor(uint256 _turnDuration, uint256 _turnTimeThreshold, uint256 _maxConsecutiveSkips,  address _nftContract ,address _owner) NFTAccessScheduler(_nftContract,  _owner) {
        turnDuration = _turnDuration;
        turnTimeThreshold = _turnTimeThreshold;
        maxConsecutiveSkips = _maxConsecutiveSkips;
    }

    modifier onlyDuringTurn(address player) {
        require(currentTurn.player == player, "Not your turn");
        require(block.timestamp >= currentTurn.startTime && block.timestamp < currentTurn.endTime, "Turn expired");
        _;
    }

    function startNextTurn(address sender) public onlyNFTOwner(sender) {
        require(block.timestamp >= currentTurn.endTime || block.timestamp >= currentTurn.startTime + turnTimeThreshold, "Current turn not finished or threshold not reached");
        
        address currentPlayer = currentTurn.player;
        address nextPlayer;
        do {
            nextPlayer = getNextEligiblePlayer();
            if (nextPlayer == currentPlayer) {
                // If we've cycled through all players and come back to the current one,
                // move the current player to the end of the queue and try again
                for (uint i = 0; i < playerQueue.length - 1; i++) {
                    playerQueue[i] = playerQueue[i + 1];
                }
                playerQueue[playerQueue.length - 1] = currentPlayer;
            }
        } while (nextPlayer == currentPlayer);
        
        currentTurn = PlayerTurn(nextPlayer, block.timestamp, block.timestamp + turnDuration);
        lastTurnTime[nextPlayer] = block.timestamp;
        consecutiveSkippedTurns[nextPlayer] = 0;
        
        emit TurnStarted(nextPlayer, currentTurn.startTime, currentTurn.endTime);
}


    function skipTurn(address sender) public onlyNFTOwner(sender) {
        require(sender != currentTurn.player, "Cannot skip your own turn");
        require(block.timestamp >= currentTurn.startTime + turnTimeThreshold, "Turn time threshold not reached");
        
        address skippedPlayer = currentTurn.player;
        consecutiveSkippedTurns[skippedPlayer]++;
        if (consecutiveSkippedTurns[skippedPlayer] > maxConsecutiveSkips) {
            _penalizePlayer(skippedPlayer);
        }
        
        emit TurnSkipped(skippedPlayer, sender);
        
        // Find the next player that isn't the skipped player
        address nextPlayer;
        do {
            nextPlayer = getNextEligiblePlayer();
            if (nextPlayer == skippedPlayer) {
                // Move the skipped player to the end of the queue
                for (uint i = 0; i < playerQueue.length - 1; i++) {
                    if (playerQueue[i] == skippedPlayer) {
                        for (uint j = i; j < playerQueue.length - 1; j++) {
                            playerQueue[j] = playerQueue[j + 1];
                        }
                        playerQueue[playerQueue.length - 1] = skippedPlayer;
                        break;
                    }
                }
            }
        } while (nextPlayer == skippedPlayer);
        
        currentTurn = PlayerTurn(nextPlayer, block.timestamp, block.timestamp + turnDuration);
        lastTurnTime[nextPlayer] = block.timestamp;
        consecutiveSkippedTurns[nextPlayer] = 0;
        
        emit TurnStarted(nextPlayer, currentTurn.startTime, currentTurn.endTime);
    }

    function hasPlayerPlayed(address player) public view returns (bool) {
        return lastTurnTime[player] >= currentTurn.startTime;
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

   function getNextEligiblePlayer() public view returns (address) {
        require(playerQueue.length > 0, "No players in queue");
        for (uint i = 0; i < playerQueue.length; i++) {
            address player = playerQueue[i];
            if (lastTurnTime[player] == 0 || block.timestamp - lastTurnTime[player] >= turnDuration) {
                return player;
            }
        }
        return playerQueue[0]; // If no eligible player, return the first in queue
    }

     function skipInactivePlayers(address sender) public onlyNFTOwner(sender) {
        require(sender != currentTurn.player, "Cannot skip your own turn");
        require(block.timestamp >= currentTurn.startTime + turnTimeThreshold, "Turn time threshold not reached");

        address[] memory skippedPlayers = new address[](playerQueue.length);
        uint256 skippedCount = 0;
        address activePlayer;

        // Skip inactive players and find the next active one
        for (uint256 i = 0; i < playerQueue.length; i++) {
            address player = playerQueue[i];
            if (player == currentTurn.player || lastTurnTime[player] == 0 || block.timestamp - lastTurnTime[player] >= turnDuration) {
                skippedPlayers[skippedCount] = player;
                skippedCount++;
                consecutiveSkippedTurns[player]++;

                if (consecutiveSkippedTurns[player] > maxConsecutiveSkips) {
                    _penalizePlayer(player);
                }

                if (i == playerQueue.length - 1) {
                    // If we've reached the end of the queue, start from the beginning
                    activePlayer = playerQueue[0];
                    break;
                }
            } else {
                activePlayer = player;
                break;
            }
        }

        require(activePlayer != address(0), "No active players found");

        // Resize the skippedPlayers array to the actual number of skipped players
        assembly {
            mstore(skippedPlayers, skippedCount)
        }

        emit MultiplePlayersSkipped(skippedPlayers, sender);

        // Start the turn for the active player
        currentTurn = PlayerTurn(activePlayer, block.timestamp, block.timestamp + turnDuration);
        lastTurnTime[activePlayer] = block.timestamp;
        consecutiveSkippedTurns[activePlayer] = 0;

        emit TurnStarted(activePlayer, currentTurn.startTime, currentTurn.endTime);
    }

    function isPlayerTurn(address player) public view returns (bool) {
        return (
            currentTurn.player == player &&
            block.timestamp >= currentTurn.startTime &&
            block.timestamp < currentTurn.endTime
        );
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

    function getCurrentPlayer() public view returns (address) {
        return currentTurn.player;
    }
}
