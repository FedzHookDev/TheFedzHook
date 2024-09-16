// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TimeSlotSystem.sol";
import "../src/MockERC721.sol";

contract TimeSlotSystemTest is Test {
    TimeSlotSystem public timeSlotSystem;
    MockERC721 public mockNFT;
    address public owner;
    address public player1;
    address public player2;
    address public player3;

    uint256 constant SLOT_DURATION = 1 hours;
    uint256 constant ROUND_DURATION = 24 hours;

    function setUp() public {
        owner = address(this);
        player1 = address(0x27E20BD50106e3Fbc50A230bd5dC02D7793c7D84);
        player2 = address(0x7BD93fb2b1339761220e4167329De5C8671B93e1);
        player3 = address(0x9Df619b3898cc7465a650AAa9C897fF4879D74c8);

        mockNFT = new MockERC721("MockNFT", "MNFT", owner, 'https://mocknft.com/');
        timeSlotSystem = new TimeSlotSystem(SLOT_DURATION, ROUND_DURATION, owner, address(mockNFT));

        // Mint NFTs to players
        //Mint 2 NFTs to player1
        mockNFT.mint(player1);

        mockNFT.mint(player2);
        mockNFT.mint(player2);

        mockNFT.mint(player3);
        mockNFT.mint(player3);
        mockNFT.mint(player3);
    }

    function testPlayerSlotAllocation() public {
        timeSlotSystem.updatePlayerSlots();

        (bool isRegistered1, uint256 slots1) = timeSlotSystem.players(player1);
        (bool isRegistered2, uint256 slots2) = timeSlotSystem.players(player2);
        (bool isRegistered3, uint256 slots3) = timeSlotSystem.players(player3);

        assertTrue(isRegistered1);
        assertTrue(isRegistered2);
        assertTrue(isRegistered3);

        assertEq(slots1, 1);
        assertEq(slots2, 2);
        assertEq(slots3, 3);

        assertEq(timeSlotSystem.totalSlots(), 6);
    }

    function testStartNewRound() public {
        timeSlotSystem.updatePlayerSlots();
        timeSlotSystem.startNewRound();

        assertTrue(timeSlotSystem.isRoundActive());
        assertEq(timeSlotSystem.currentRoundNumber(), 1);
        assertEq(timeSlotSystem.roundStartTime(), block.timestamp);
    }

    function testCanPlayerAct() public {
        timeSlotSystem.updatePlayerSlots();
        timeSlotSystem.startNewRound();

        address currentPlayer = timeSlotSystem.getCurrentPlayer();
        assertTrue(timeSlotSystem.canPlayerAct(currentPlayer));
        vm.expectRevert();
        (timeSlotSystem.canPlayerAct(address(0x999)));
    }

    function testGetNextActionWindow() public {
        timeSlotSystem.updatePlayerSlots();
        timeSlotSystem.startNewRound();

        (uint256 startTime, uint256 endTime) = timeSlotSystem.getNextActionWindow(player1);
        assertGe(startTime, block.timestamp);
        assertEq(endTime - startTime, SLOT_DURATION);

        (startTime, endTime) = timeSlotSystem.getNextActionWindow(player2);
        assertGe(startTime, block.timestamp);
        assertEq(endTime - startTime,  SLOT_DURATION);

        (startTime, endTime) = timeSlotSystem.getNextActionWindow(player3);
        assertGe(startTime, block.timestamp);
        assertEq(endTime - startTime, SLOT_DURATION);
    }

    function testRoundEndsAfter24Hours() public {
        timeSlotSystem.updatePlayerSlots();
        timeSlotSystem.startNewRound();

        // Fast forward 23 hours
        vm.warp(block.timestamp + 23 hours);
        assertTrue(timeSlotSystem.isRoundActive());

        // Fast forward 1 more hour
        vm.warp(block.timestamp + 1 hours);
        assertFalse(timeSlotSystem.isRoundActive());
    }

    function testCannotActAfterRoundEnds() public {
        timeSlotSystem.updatePlayerSlots();
        timeSlotSystem.startNewRound();

        address currentPlayer = timeSlotSystem.getCurrentPlayer();
        assertTrue(timeSlotSystem.canPlayerAct(currentPlayer));

        // Fast forward 24 hours
        vm.warp(block.timestamp + 24 hours);

        vm.expectRevert("Round has ended");
        timeSlotSystem.getCurrentPlayer();

        vm.expectRevert("Round has ended");
        timeSlotSystem.canPlayerAct(player1);
    }

    function testGetAllActionWindows() public {
    timeSlotSystem.updatePlayerSlots();
    timeSlotSystem.startNewRound();

    // Test for player1 (1 NFT)
    (uint256[] memory startTimes1, uint256[] memory endTimes1) = timeSlotSystem.getAllActionWindows(player1);
    assertEq(startTimes1.length, 1);
    assertEq(endTimes1.length, 1);
    assertEq(endTimes1[0] - startTimes1[0], SLOT_DURATION);

    // Test for player2 (2 NFTs)
    (uint256[] memory startTimes2, uint256[] memory endTimes2) = timeSlotSystem.getAllActionWindows(player2);
    assertEq(startTimes2.length, 2);
    assertEq(endTimes2.length, 2);
    for (uint i = 0; i < 2; i++) {
        assertEq(endTimes2[i] - startTimes2[i], SLOT_DURATION);
        if (i > 0) {
            // Check that slots are within the round duration, but not necessarily consecutive
            assertTrue(startTimes2[i] >= timeSlotSystem.roundStartTime());
            assertTrue(endTimes2[i] <= timeSlotSystem.roundStartTime() + ROUND_DURATION);
        }
    }

    // Test for player3 (3 NFTs)
    (uint256[] memory startTimes3, uint256[] memory endTimes3) = timeSlotSystem.getAllActionWindows(player3);
    assertEq(startTimes3.length, 3);
    assertEq(endTimes3.length, 3);
    for (uint i = 0; i < 3; i++) {
        assertEq(endTimes3[i] - startTimes3[i], SLOT_DURATION);
        assertTrue(startTimes3[i] >= timeSlotSystem.roundStartTime());
        assertTrue(endTimes3[i] <= timeSlotSystem.roundStartTime() + ROUND_DURATION);
    }

    // Test that all slots are within the round duration
    assertLe(endTimes3[2], timeSlotSystem.roundStartTime() + ROUND_DURATION);

    // Test for non-registered player
    address nonPlayer = address(0x1234);
    vm.expectRevert("Player not registered");
    timeSlotSystem.getAllActionWindows(nonPlayer);

    // Additional test to check for non-consecutive slots
    bool foundNonConsecutive = false;
    for (uint i = 1; i < 3; i++) {
        if (startTimes3[i] != endTimes3[i-1]) {
            foundNonConsecutive = true;
            break;
        }
    }
    assertTrue(foundNonConsecutive, "Expected to find non-consecutive slots for player3");
}



    function testNewRoundAfterPreviousEnds() public {
        timeSlotSystem.updatePlayerSlots();
        timeSlotSystem.startNewRound();

        // Fast forward 24 hours
        vm.warp(block.timestamp + 24 hours);

        timeSlotSystem.startNewRound();
        assertTrue(timeSlotSystem.isRoundActive());
        assertEq(timeSlotSystem.currentRoundNumber(), 2);
    }
}
