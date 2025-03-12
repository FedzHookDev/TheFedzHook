// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {TheFedz} from "./TheFedz.sol";
import {IAccessManager} from "./interfaces/IAccessManager.sol";
import {ITimeSlotSystem} from "./interfaces/ITimeSlotSystem.sol";

import {InfinteRandomLibrary} from "./InfinteRandomLibrary.sol";
import {ArrayNFTLibrary} from "./ArrayNFTLibrary.sol";
import {RoundLibrary} from "./RoundLibrary.sol";
import {RoundsIterator} from "./RoundsIterator.sol";

contract ShuffleAccessManager is ITimeSlotSystem, IAccessManager, RoundsIterator, Ownable {

    using InfinteRandomLibrary for bytes32;
    using ArrayNFTLibrary for TheFedz;
    using RoundLibrary for RoundLibrary.Round;

    TheFedz public nftContract;
    bytes32 public randomSeed;

    constructor(address _owner, address _nftContract) Ownable(_owner) {
        nftContract = TheFedz(_nftContract);
        randomSeed = blockhash(block.number-1);
    }

    modifier onlyAllowed() {
        if (!_isAllowed(msg.sender)) {
            revert NotAllowed(msg.sender);
        }
        _;
    }

    function isAllowed(address caller) external view returns (bool res) {
        if (!_isStateUpToDate()) {
            return false;
        }
        return _isAllowed(caller);
    }

    function isAllowedAfterStateUpdate(address caller) external view returns (bool res) {
        return _isAllowed(caller);
    }

    function getCurrentPlayer() public view returns (address res) {
        if (!_isStateUpToDate()) {
            return address(0);
        }
        return _getCurrentPlayer();
    }

    function getCurrentPlayerAfterStateUpdate() public view returns (address) {
        return _getCurrentPlayer();
    }

    function getPlayerByTimestamp(uint256 timestamp) public view returns (address) {
        return _getPlayerByTimestamp(timestamp);
    }

    function updateState() external onlyAllowed {
        if (_transistState()) {
            _prepareNextRoundState(round.slotDuration, round.endsInOrLaterThen());
        }
    }

    ////////////////////////
    // Admin functions
    ///////////////////////
    function restart(uint256 startsAt, uint256 slotDuration) external onlyOwner {
        _restart(startsAt, slotDuration);
    }

    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = TheFedz(_nftContract);
    }

    ////////////////////////////////
    // Internal functions
    ///////////////////////////////
    function _restart(uint256 startsAt, uint256 slotDuration) internal {
        _prepareNextRoundState(slotDuration, startsAt);
    }

    function _getCurrentPlayer() internal view returns (address) {
        return getPlayerByTimestamp(block.timestamp);
    }

    function _prepareNextRoundState(uint256 slotDuration, uint256 startsAt) internal {
        uint256 random = randomSeed.gen(round.number+1);
        uint256[] memory slots = nftContract.toArrayWithShuffle(random);
        _prepareNextRoundState(slotDuration, startsAt, slots);
        emit NextRoundAnnouncement(nextRound.number, random, nextRound.slotDuration, nextRound.startsAt, nextRound.slots);
    }

    function _isAllowed(address caller) internal view returns (bool) {
        return getPlayerByTimestamp(block.timestamp) == caller;
    }

    function _statefullIsAllowed(address caller) internal view returns (bool) {
        return getPlayerByTimestamp(block.timestamp) == caller;
    }

    function _getPlayerByTimestamp(uint256 timestamp) internal view returns (address) {
        uint tokenIdTurn = getSlotValueByTimestamp(timestamp);
        return tokenIdTurn > 0 ? nftContract.ownerOf(tokenIdTurn) : address(0);
    }

}
