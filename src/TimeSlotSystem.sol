// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


contract TimeSlotSystem is Ownable {
    struct Player {
        bool isRegistered;
        uint256 index;
    }

    uint256 public slotDuration;
    uint256 public roundDuration;
    uint256 public roundStartTime;
    uint256 public playerCount;

    IERC721 public nftContract;

    mapping(address => Player) public players;
    address[] public playerList;

    uint256 private nonce;

    event NewRoundStarted(uint256 startTime);
    event PlayerRegistered(address player);
    event PlayerUnregistered(address player);
    event PlayerOrderShuffled();

    modifier onlyNFTOwner(address account) {
        require(nftContract.balanceOf(account) > 0, "Not an NFT holder");
        _;
    }

    constructor(uint256 _slotDuration, uint256 _roundDuration, address _owner, address _nftContract) Ownable(_owner) {
        slotDuration = _slotDuration;
        roundDuration = _roundDuration;
        nftContract = IERC721(_nftContract);
        roundStartTime = 0;
        playerCount = 0;
        nonce = 0;
    }

    function registerPlayer() external onlyNFTOwner(msg.sender){
        require(!players[msg.sender].isRegistered, "Player already registered");
        players[msg.sender] = Player(true, playerCount);
        playerList.push(msg.sender);
        playerCount++;
        emit PlayerRegistered(msg.sender);
    }

    function unregisterPlayer() external onlyNFTOwner(msg.sender){
        require(players[msg.sender].isRegistered, "Player not registered");
        uint256 indexToRemove = players[msg.sender].index;
        address lastPlayer = playerList[playerCount - 1];

        playerList[indexToRemove] = lastPlayer;
        players[lastPlayer].index = indexToRemove;

        playerList.pop();
        delete players[msg.sender];
        playerCount--;
        
        emit PlayerUnregistered(msg.sender);
    }

    function startNewRound() external {
        require(playerCount > 0, "No players registered");
        roundStartTime = block.timestamp;
        shufflePlayers();
        emit NewRoundStarted(roundStartTime);
    }

    function shufflePlayers() private {
        for (uint256 i = playerCount - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % (i + 1);
            nonce++;

            address temp = playerList[i];
            playerList[i] = playerList[j];
            playerList[j] = temp;

            players[playerList[i]].index = i;
            players[playerList[j]].index = j;
        }
        emit PlayerOrderShuffled();
    }

    function getCurrentPlayer() public view returns (address) {
        require(roundStartTime > 0, "No active round");
        uint256 elapsedTime = (block.timestamp - roundStartTime) % roundDuration;
        uint256 currentIndex = (elapsedTime / slotDuration) % playerCount;
        return playerList[currentIndex];
    }

    function canPlayerAct(address player) public view returns (bool) {
        require(roundStartTime > 0, "No active round");
        require(players[player].isRegistered, "Player not registered");
        
        uint256 elapsedTime = (block.timestamp - roundStartTime) % roundDuration;
        uint256 currentIndex = (elapsedTime / slotDuration) % playerCount;
        
        return playerList[currentIndex] == player;
    }

    function getNextActionWindow(address player) public view returns (uint256 startTime, uint256 endTime) {
        require(roundStartTime > 0, "No active round");
        require(players[player].isRegistered, "Player not registered");

        uint256 playerIndex = players[player].index;
        uint256 currentRoundTime = (block.timestamp - roundStartTime) % roundDuration;
        uint256 nextSlotStart = ((currentRoundTime / slotDuration) + 1) * slotDuration; 
        if (nextSlotStart >= roundDuration) {
            // Next action window is in the next round
            startTime = roundStartTime + roundDuration + (playerIndex * slotDuration);
        } else {
            startTime = roundStartTime + nextSlotStart + (playerIndex * slotDuration);
            if (startTime >= roundStartTime + roundDuration) {
                startTime -= roundDuration;
            }
        }

        endTime = startTime + slotDuration;
    }

    function setSlotDuration(uint256 _slotDuration) external onlyOwner {
        slotDuration = _slotDuration;
    }

    function setRoundDuration(uint256 _roundDuration) external onlyOwner {
        roundDuration = _roundDuration;
    }
}
