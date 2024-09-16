// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {MockERC721} from "./MockERC721.sol";

contract TimeSlotSystem is Ownable {
    struct Player {
        bool isRegistered;
        uint256 slots;
        uint256[] actionWindows;
    }

    uint256 public slotDuration;
    uint256 public roundDuration;
    uint256 public roundStartTime;
    uint256 public totalSlots;
    uint256 public currentRoundNumber;

    MockERC721 public nftContract;

    mapping(address => Player) public players;
    address[] public playerList;

    uint256 private nonce;

    event NewRoundStarted(uint256 startTime);
    event PlayerRegistered(address player, uint256 slots);
    event PlayerUnregistered(address player);
    event SlotsShuffled();
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
                unregisterPlayer(owner);
            }
        }
    }

    function unregisterPlayer(address player) public {
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
        shuffleSlots();
        emit NewRoundStarted(roundStartTime);
    }

    function shuffleSlots() private {
        uint256[] memory allSlots = new uint256[](totalSlots);
        for (uint256 i = 0; i < totalSlots; i++) {
            allSlots[i] = i;
        }

        // Fisher-Yates shuffle
        for (uint256 i = totalSlots - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % (i + 1);
            nonce++;

            uint256 temp = allSlots[i];
            allSlots[i] = allSlots[j];
            allSlots[j] = temp;
        }

        uint256 slotIndex = 0;
        for (uint256 i = 0; i < playerList.length; i++) {
            address player = playerList[i];
            uint256 playerSlots = players[player].slots;
            delete players[player].actionWindows; // Clear existing action windows
            players[player].actionWindows = new uint256[](playerSlots);

            for (uint256 j = 0; j < playerSlots; j++) {
                players[player].actionWindows[j] = allSlots[slotIndex];
                slotIndex++;
            }
        }

        emit SlotsShuffled();
    }


    function getCurrentPlayer() public view returns (address) {
        require(roundStartTime > 0, "No active round");
        require(block.timestamp >= roundStartTime, "Round has not started");
        require(block.timestamp < roundStartTime + roundDuration, "Round has ended");

        uint256 currentSlot = (block.timestamp - roundStartTime) / slotDuration;

        for (uint256 i = 0; i < playerList.length; i++) {
            address player = playerList[i];
            if (players[player].isRegistered) {
                for (uint256 j = 0; j < players[player].actionWindows.length; j++) {
                    if (players[player].actionWindows[j] == currentSlot) {
                        return player;
                    }
                }
            }
        }

        revert("No player found for current time");
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

        uint256 currentSlot = (block.timestamp - roundStartTime) / slotDuration;

        for (uint256 i = 0; i < players[player].actionWindows.length; i++) {
            if (players[player].actionWindows[i] > currentSlot) {
                startTime = roundStartTime + (players[player].actionWindows[i] * slotDuration);
                endTime = startTime + slotDuration;
                if (endTime > roundStartTime + roundDuration) {
                    endTime = roundStartTime + roundDuration;
                }
                return (startTime, endTime);
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

        for (uint256 i = 0; i < playerSlots; i++) {
            startTimes[i] = roundStartTime + (players[player].actionWindows[i] * slotDuration);
            endTimes[i] = startTimes[i] + slotDuration;
            if (endTimes[i] > roundStartTime + roundDuration) {
                endTimes[i] = roundStartTime + roundDuration;
            }
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
