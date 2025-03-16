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
        if (!_isAllowed(true, msg.sender)) {
            revert NotAllowed(msg.sender);
        }
        _;
    }

    function isAllowed(address caller) external view returns (bool res) {
        return _isAllowed(false, caller);
    }

    function isAllowed(bool unlockMode, address caller) external view returns (bool res) {
        return _isAllowed(unlockMode, caller);
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

    function unlockRound() external onlyAllowedToUnlock {
        if (_unlockRound()) {
            _prepareNextRoundState(round.slotDuration, round.endsInOrLaterThen());
        }
    }

    ////////////////////////////////
    // Internal functions
    ///////////////////////////////
    function _isAllowed(bool unlockMode, address caller) internal view returns (bool) {
        if (!unlockMode && _isLocked()) {
            return false;
        }
        return _getPlayerByTimestamp(block.timestamp) == caller;
    }

    function _getPlayerByTimestamp(uint256 timestamp) internal view returns (address) {
        uint tokenIdTurn = getSlotValueByTimestamp(timestamp);
        return tokenIdTurn > 0 ? nftContract.ownerOf(tokenIdTurn) : address(0);
    }

    function _restart(uint256 startsAt, uint256 slotDuration) internal {
        _prepareNextRoundState(slotDuration, startsAt);
    }

    function _getCurrentPlayer() internal view returns (address) {
        return _getPlayerByTimestamp(block.timestamp);
    }

    function _prepareNextRoundState(uint256 slotDuration, uint256 startsAt) internal {
        uint256 random = randomSeed.gen(round.number+1);
        uint256[] memory slots = nftContract.toArrayWithShuffle(random);
        _prepareNextRoundState(slotDuration, startsAt, slots);
        emit NextRoundAnnouncement(nextRound.number, random, nextRound.slotDuration, nextRound.startsAt, nextRound.slots);
    }

}
