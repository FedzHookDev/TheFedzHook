// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../src/ShuffleAccessManager.sol";
import "../src/MockERC721.sol";
import {ITheFedz} from "../src/interfaces/ITheFedz.sol";
import {TheFedz} from "../src/TheFedz.sol";
import {RoundsIterator} from "../src/RoundsIterator.sol";

contract ShuffleTimeSlotSystemTest is Test {
    ShuffleAccessManager public timeSlotSystem;
    ITheFedz public mockNFT;
    address public owner;
    address public player1;
    address public player2;
    address public player3;
    address public player4;
    address public hook;

    uint256 constant SLOT_DURATION = 1 hours;
    uint256 constant ROUND_DURATION = 24 hours;

    bytes32 randomSeed;
    function setUp() public {
        owner = makeAddr("OWNER");
        player1 = makeAddr("ALICE");
        player2 = makeAddr("BOB");
        player3 = makeAddr("CHARLEI");
        player4 = makeAddr("PLAYER_4");
        hook = makeAddr("HOOK");

        randomSeed = blockhash(block.number-1);
        mockNFT = ITheFedz(address(new TheFedz(owner)));
        vm.roll(5);
        timeSlotSystem = new ShuffleAccessManager(owner, address(mockNFT));
        // Mint NFTs to players
        //Mint 2 NFTs to player1
        vm.prank(owner);
        mockNFT.adminMint(player1, 1);

        vm.prank(owner);
        mockNFT.adminMint(player2, 1);

        vm.prank(owner);
        mockNFT.adminMint(player3, 1);
    }

    function test_randomSeed_byDeploymentBlock() public {
        assertEq(timeSlotSystem.randomSeed(), blockhash(block.number-1));
    }

    function test_nonRestarted_fresh() public {
        vm.warp(1000);
        assertEq(timeSlotSystem.getCurrentPlayer(), address(0));
        // (RoundsIterator.RoundDescriptor memory curRound, RoundsIterator.RoundDescriptor memory nextRound) = timeSlotSystem.rounds();
        // assertEq(curRound.startsAt, 0);
        // assertEq(nextRound.startsAt, 0);
    }

    function test_restart_nextRoundAnnounced() public {
        vm.warp(0);
        uint256 startingTime = block.timestamp + 1 hours;
        uint256 slotDuration = 1 hours;
        uint256 expcRandom = uint256(keccak256(abi.encodePacked(timeSlotSystem.randomSeed(), uint256(1))));

        vm.expectEmit(address(timeSlotSystem));
        emit IAccessManager.NextRoundAnnouncement(1, expcRandom, startingTime, slotDuration, fisherYatesShuffle(expcRandom));
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, slotDuration);
        // assertEq(timeSlotSystem.isActiveOn(block.timestamp), false);
        (RoundsIterator.RoundDescriptor memory curRound, RoundsIterator.RoundDescriptor memory nextRound) = timeSlotSystem.rounds();
        assertEq(curRound.startsAt, 0);
        assertEq(nextRound.startsAt, startingTime);
    }

    function test_restartAndStarted() public {
        vm.warp(0);
        uint256 startingTime = block.timestamp + 1 hours;
        uint256 slotDuration = 1 hours;
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, slotDuration);
        vm.warp(startingTime);
        (RoundsIterator.RoundDescriptor memory curRound, RoundsIterator.RoundDescriptor memory nextRound) = timeSlotSystem.rounds();
        assertEq(curRound.startsAt, startingTime);
        assertEq(nextRound.startsAt, 0);
    }

    function test_afterRestartAndBeforeStart() public {
        vm.warp(10 hours);
        uint256 startingTime = block.timestamp + 1 hours;
        uint256 slotDuration = 1 hours;
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, slotDuration);
        (RoundsIterator.RoundDescriptor memory curRound, RoundsIterator.RoundDescriptor memory nextRound) = timeSlotSystem.rounds();
        assertEq(curRound.startsAt, 0);
        assertEq(nextRound.startsAt, startingTime);
    }

    function test_secondRestartBeforeStart_revert() public { // TODO: Check if this is the correct behavior
    }

    function test_startNewRoundFromNonOwner_revert() public {
        uint256 startingTime = block.timestamp + 1 hours;
        uint256 slotDuration = 1 hours;
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, makeAddr("NON_OWNER")),
            address(timeSlotSystem)
        );
        vm.prank(makeAddr("NON_OWNER"));
        timeSlotSystem.restart(startingTime, slotDuration);
    }

    function test_startNewRoundWithRetroactiveStart_revert() public {
        vm.warp(10 hours);
        uint256 startingTime = block.timestamp - 1 hours;
        uint256 slotDuration = 1 hours;
        vm.expectRevert("Invalid start time");
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, slotDuration);
    }

    function test_restart_firstRestartWithEmptySlotDuration_revert() public {
        vm.warp(10 hours);
        uint256 startingTime = block.timestamp + 1 hours;
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, 1 hours);

        (RoundsIterator.RoundDescriptor memory curRound, RoundsIterator.RoundDescriptor memory nextRound) = timeSlotSystem.rounds();
        assertEq(curRound.startsAt, 0);
        assertEq(nextRound.startsAt, startingTime);
    }

    function test_firstAccessAfterRoundStart() public {
        uint256 slotDuration = 1 hours;
        uint256 startingTime = ((block.timestamp + slotDuration) - (block.timestamp) % slotDuration) + slotDuration;

        uint256 expcRandom = uint256(keccak256(abi.encodePacked(timeSlotSystem.randomSeed(), uint256(1))));
        vm.expectEmit(address(timeSlotSystem));
        emit IAccessManager.NextRoundAnnouncement(1, expcRandom, slotDuration, startingTime, fisherYatesShuffle(expcRandom));
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, slotDuration);

        vm.warp(startingTime + 1 minutes);
        expcRandom = uint256(keccak256(abi.encodePacked(timeSlotSystem.randomSeed(), uint256(2))));
        vm.expectEmit(address(timeSlotSystem));
        emit IAccessManager.NextRoundAnnouncement(2, expcRandom, slotDuration, 18000, fisherYatesShuffle(expcRandom));
        vm.prank(player3);
        timeSlotSystem.unlockRound();
        assertEq(timeSlotSystem.getCurrentPlayer(), player3);

        vm.warp(block.timestamp + slotDuration);
        vm.expectRevert("Round is not locked");
        vm.prank(player1);
        timeSlotSystem.unlockRound();
        assertEq(timeSlotSystem.getCurrentPlayer(), player1);

        vm.warp(block.timestamp + slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player2);

        // Next round starts here
        expcRandom = uint256(keccak256(abi.encodePacked(timeSlotSystem.randomSeed(), uint256(3))));
        vm.expectEmit(address(timeSlotSystem));
        emit IAccessManager.NextRoundAnnouncement(3, expcRandom, slotDuration, 28800, fisherYatesShuffle(expcRandom));
        vm.warp(block.timestamp + slotDuration);
        vm.prank(player2);
        timeSlotSystem.unlockRound();
        assertEq(timeSlotSystem.getCurrentPlayer(), player2);
        vm.warp(block.timestamp + slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player3);
        vm.warp(block.timestamp + slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player1);

        // Next round starts here
        expcRandom = uint256(keccak256(abi.encodePacked(timeSlotSystem.randomSeed(), uint256(4))));
        vm.expectEmit(address(timeSlotSystem));
        emit IAccessManager.NextRoundAnnouncement(4, expcRandom, slotDuration, 39600, fisherYatesShuffle(expcRandom));
        vm.warp(block.timestamp + 2 * slotDuration);
        vm.prank(player2);
        timeSlotSystem.unlockRound();
        assertEq(timeSlotSystem.getCurrentPlayer(), player2);
        vm.warp(block.timestamp + slotDuration);

        assertEq(timeSlotSystem.getCurrentPlayer(), player3);
        vm.warp(block.timestamp + slotDuration);
    
        vm.prank(player3);
        timeSlotSystem.unlockRound();
        assertEq(timeSlotSystem.getCurrentPlayer(), player3);
        vm.warp(block.timestamp + slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player2);
        vm.warp(block.timestamp + slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player1);

        // Next round starts here
        vm.warp(block.timestamp + slotDuration);
        expcRandom = uint256(keccak256(abi.encodePacked(timeSlotSystem.randomSeed(), uint256(6))));
        vm.expectEmit(address(timeSlotSystem));
        emit IAccessManager.NextRoundAnnouncement(6, expcRandom, slotDuration, 61200, fisherYatesShuffle(expcRandom));
        vm.prank(player1);
        timeSlotSystem.unlockRound();
        assertEq(timeSlotSystem.getCurrentPlayer(), player1);
    }

    function fisherYatesShuffle(uint256 random) private view returns(uint256[] memory slots) {
        uint256 totalSlots = mockNFT.totalSupply();
        // Fisher-Yates shuffle
        slots = new uint[](totalSlots);
        for (uint256 i = 0; i < totalSlots; i++) {
            slots[i] = mockNFT.tokenByIndex(i);
        }
        for (uint256 i = totalSlots - 1; i > 0; i--) {
            uint256 j = random % (i + 1);
            uint256 temp = slots[i];
            slots[i] = slots[j];
            slots[j] = temp;
        }
    }
}
