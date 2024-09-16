// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {MockERC721} from "./MockERC721.sol";


contract TimeSlotSystem is Ownable {
    struct Player {
        bool isRegistered;
        uint256 slots;
    }

    uint256 public slotDuration;
    uint256 public roundDuration;
    uint256 public roundStartTime;
    uint256 public totalSlots;
    uint256 public currentRoundNumber;


    MockERC721 public nftContract;

    mapping(address => Player) public players;
    // New mapping to store randomized slot order
    mapping(address => uint256[]) private playerSlotOrder;
    address[] public playerList;

    uint256 private nonce;

    event NewRoundStarted(uint256 startTime);
    event PlayerRegistered(address player, uint256 slots);
    event PlayerUnregistered(address player);
    event PlayerOrderShuffled();
    event RoundEnded(uint256 endTime, uint256 roundNumber);

    modifier onlyNFTOwner(address account) {
        require(nftContract.balanceOf(account) > 0, "Not an NFT holder");
        _;
    }

    constructor(uint256 _slotDuration, uint256 _roundDuration, address _owner, address _nftContract) Ownable(_owner) {
        slotDuration = _slotDuration;
        roundDuration = _roundDuration;
        nftContract = MockERC721(_nftContract);
        roundStartTime = 0;
        totalSlots = 0;
        nonce = 0;
    }

    function updatePlayerSlots() public {
        address[] memory owners = nftContract.getAllOwners();
        totalSlots = 0;

        for (uint256 i = 0; i < owners.length; i++) {
            address owner = owners[i];
            uint256 balance = nftContract.balanceOf(owner);

            if (balance > 0) {
                if (!players[owner].isRegistered) {
                    playerList.push(owner);
                }
                players[owner].isRegistered = true;
                players[owner].slots = balance;
                totalSlots += balance;
                emit PlayerRegistered(owner, balance);
            } else if (players[owner].isRegistered) {
                emit PlayerUnregistered(owner); // Player has no NFTs anymore
            }
        }
    }

     function unregisterPlayer(address player) external onlyOwner() {
        require(players[player].isRegistered, "Player not registered");
        totalSlots -= players[player].slots;
        delete players[player];
        
        for (uint256 i = 0; i < playerList.length; i++) {
            if (playerList[i] == player) {
                playerList[i] = playerList[playerList.length - 1];
                playerList.pop();
                break;
            }
        }
        
        emit PlayerUnregistered(player);
    }
    

     function startNewRound() public {
        require(totalSlots > 0, "No players registered");
        require(roundStartTime == 0 || block.timestamp >= roundStartTime + roundDuration, "Current round not finished");
        
        if (roundStartTime > 0) {
            emit RoundEnded(roundStartTime + roundDuration, currentRoundNumber);
        }
        
        updatePlayerSlots();
        roundStartTime = block.timestamp;
        currentRoundNumber++;
        shufflePlayers();
        emit NewRoundStarted(roundStartTime);
    }
    

    function shufflePlayers() private {
        // Shuffle player order
        for (uint256 i = playerList.length - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % (i + 1);
            nonce++;

            address temp = playerList[i];
            playerList[i] = playerList[j];
            playerList[j] = temp;
        }

        // Randomize slot order for each player
        for (uint256 i = 0; i < playerList.length; i++) {
            address player = playerList[i];
            uint256 playerSlots = players[player].slots;
            
            // Create an array of slot indices
            uint256[] memory slotIndices = new uint256[](playerSlots);
            for (uint256 j = 0; j < playerSlots; j++) {
                slotIndices[j] = j;
            }

            // Shuffle the slot indices
            for (uint256 j = playerSlots - 1; j > 0; j--) {
                uint256 k = uint256(keccak256(abi.encodePacked(block.timestamp, player, nonce))) % (j + 1);
                nonce++;

                uint256 temp = slotIndices[j];
                slotIndices[j] = slotIndices[k];
                slotIndices[k] = temp;
            }

            // Store the shuffled slot order
            playerSlotOrder[player] = slotIndices;
        }

        emit PlayerOrderShuffled();
    }


      function getCurrentPlayer() public view returns (address) {
        require(roundStartTime > 0, "No active round");
        require(block.timestamp < roundStartTime + roundDuration, "Round has ended");
        uint256 elapsedTime = (block.timestamp - roundStartTime);
        uint256 currentSlot = (elapsedTime / slotDuration) % totalSlots;
        
        uint256 accumulatedSlots = 0;
        for (uint256 i = 0; i < playerList.length; i++) {
            address player = playerList[i];
            uint256 playerSlots = players[player].slots;
            for (uint256 j = 0; j < playerSlots; j++) {
                if (currentSlot == accumulatedSlots + playerSlotOrder[player][j]) {
                    return player;
                }
            }
            accumulatedSlots += playerSlots;
        }
        revert("No player found for current slot");
    }

    function canPlayerAct(address player) public view returns (bool) {
        require(roundStartTime > 0, "No active round");
        require(block.timestamp < roundStartTime + roundDuration, "Round has ended");
        require(players[player].isRegistered, "Player not registered");
        
        return getCurrentPlayer() == player;
    }

    function getNextActionWindow(address player) public view returns (uint256 startTime, uint256 endTime) {
    require(roundStartTime > 0, "No active round");
    require(players[player].isRegistered, "Player not registered");

    uint256 currentRoundTime = (block.timestamp - roundStartTime);
    uint256 currentSlot = (currentRoundTime / slotDuration) % totalSlots;
    
    uint256 accumulatedSlots = 0;
    for (uint256 i = 0; i < playerList.length; i++) {
        address currentPlayer = playerList[i];
        for (uint256 j = 0; j < players[currentPlayer].slots; j++) {
            if (currentPlayer == player && currentSlot <= accumulatedSlots) {
                startTime = roundStartTime + (accumulatedSlots * slotDuration);
                if (startTime < block.timestamp) {
                    startTime += roundDuration;
                }
                endTime = startTime + slotDuration;
                if (endTime > roundStartTime + roundDuration) {
                    endTime = roundStartTime + roundDuration;
                }
                return (startTime, endTime);
            }
            accumulatedSlots++;
        }
    }
    revert("No upcoming action window found for player");
}

function getAllActionWindows(address player) public view returns (uint256[] memory startTimes, uint256[] memory endTimes) {
        require(roundStartTime > 0, "No active round");
        require(players[player].isRegistered, "Player not registered");

        uint256 playerSlots = players[player].slots;
        startTimes = new uint256[](playerSlots);
        endTimes = new uint256[](playerSlots);

        uint256 accumulatedSlots = 0;
        for (uint256 i = 0; i < playerList.length; i++) {
            address currentPlayer = playerList[i];
            if (currentPlayer == player) {
                for (uint256 j = 0; j < playerSlots; j++) {
                    uint256 slotIndex = accumulatedSlots + playerSlotOrder[player][j];
                    startTimes[j] = roundStartTime + (slotIndex * slotDuration);
                    endTimes[j] = startTimes[j] + slotDuration;
                    if (endTimes[j] > roundStartTime + roundDuration) {
                        endTimes[j] = roundStartTime + roundDuration;
                    }
                }
                break;
            }
            accumulatedSlots += players[currentPlayer].slots;
        }
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
    

    function setSlotDuration(uint256 _slotDuration) external onlyOwner {
        slotDuration = _slotDuration;
    }

    function setRoundDuration(uint256 _roundDuration) external onlyOwner {
        roundDuration = _roundDuration;
    }

    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = MockERC721(_nftContract);
    }
}
