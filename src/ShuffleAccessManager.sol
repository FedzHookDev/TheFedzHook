// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ITheFedz} from "./interfaces/ITheFedz.sol";
import {IAccessManager} from "./interfaces/IAccessManager.sol";
import {ITimeSlotSystem} from "./interfaces/ITimeSlotSystem.sol";

import {InfinteRandomLibrary} from "./InfinteRandomLibrary.sol";
import {ArrayNFTLibrary} from "./ArrayNFTLibrary.sol";
import {RoundLibrary} from "./RoundLibrary.sol";
import {RoundsIterator} from "./RoundsIterator.sol";


contract ShuffleAccessManager is ITimeSlotSystem, IAccessManager, RoundsIterator, Ownable {

    using InfinteRandomLibrary for bytes32;
    using ArrayNFTLibrary for ITheFedz;
    using RoundLibrary for RoundLibrary.Round;

    ITheFedz public nftContract;
    bytes32 public randomSeed;

    constructor(address _owner, address _nftContract) Ownable(_owner) {
        nftContract = ITheFedz(_nftContract);
        randomSeed = blockhash(block.number-1);
    }

    modifier onlyAllowedToUnlock() {
        if (_getPlayerByTimestamp(block.timestamp) != msg.sender) {
            revert NotAllowed(msg.sender);
        }
        _;
    }

    function isLocked() external view returns (bool) {
        return _isLocked();
    }

    function unlockRound() external onlyAllowedToUnlock {
        _unlockRound();
        (uint256 random, uint256[] memory slots) = _prepareNextRound();
        _setNextRound(slots);
        emit NextRoundAnnouncement(nextRound.number, random, nextRound.slotDuration, nextRound.startsAt, slots);
    }

    function getCurrentPlayer() external view returns (address res) {
        if (_isLocked()) {
            return address(0);
        }
        return _getCurrentPlayer();
    }

    function getPlayerByTimestamp(uint256 timestamp) public view returns (address) {
        return _getPlayerByTimestamp(timestamp);
    }

    ////////////////////////
    // Admin functions
    ///////////////////////
    function restart(uint256 startsAt, uint256 slotDuration) external onlyOwner {
        _restart(startsAt, slotDuration);
    }

    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = ITheFedz(_nftContract);
    }

    ////////////////////////////////
    // Internal functions
    ///////////////////////////////
    function _restart(uint256 startsAt, uint256 slotDuration) internal {
        (uint256 random, uint256[] memory slots) = _prepareNextRound();
        uint256 roundNumber = _restart(startsAt, slotDuration, slots);
        emit NextRoundAnnouncement(roundNumber, random, slotDuration, startsAt, slots);
    }

    function _getPlayerByTimestamp(uint256 timestamp) internal view returns (address) {
        uint tokenIdTurn = _getSlotValueByTimestamp(timestamp);
        return tokenIdTurn > 0 ? nftContract.ownerOf(tokenIdTurn) : address(0);
    }

    function _getCurrentPlayer() internal view returns (address) {
        return _getPlayerByTimestamp(block.timestamp);
    }

    function _prepareNextRound() internal returns (uint256 random, uint256[] memory slots) {
        random = randomSeed.gen(round.number+1);
        slots = nftContract.toArrayWithShuffle(random);
    }
}
