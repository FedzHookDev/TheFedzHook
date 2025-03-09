// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../src/ShuffleTimeSlotSystem.sol";
import "../src/MockERC721.sol";

contract ShuffleTimeSlotSystemTest is Test {
    ShuffleTimeSlotSystem public timeSlotSystem;
    TheFedz public mockNFT;
    address public owner;
    address public player1;
    address public player2;
    address public player3;
    address public player4;

    uint256 constant SLOT_DURATION = 1 hours;
    uint256 constant ROUND_DURATION = 24 hours;

    function setUp() public {
        owner = makeAddr("OWNER");
        player1 = makeAddr("PLAYER_1");
        player2 = makeAddr("PLAYER_2");
        player3 = makeAddr("PLAYER_3");
        player4 = makeAddr("PLAYER_4");

        mockNFT = new TheFedz(owner);
        vm.roll(5);
        timeSlotSystem = new ShuffleTimeSlotSystem(owner, address(mockNFT));
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
        assertEq(timeSlotSystem.randomSeed(), keccak256(abi.encodePacked(blockhash(block.number-1))));
    }

    function test_nonRestarted_fresh() public {
        vm.warp(1000);
        assertEq(timeSlotSystem.getCurrentPlayer(), address(0));
        assertEq(timeSlotSystem.isActiveOn(block.timestamp), false);
        assertEq(timeSlotSystem.roundStartedAt(), 0);
        assertEq(timeSlotSystem.nextRoundStartAt(), 0);
    }

    function test_restart_nextRoundAnnounced() public {
        vm.warp(0);
        uint256 startingTime = block.timestamp + 1 hours;
        uint256 slotDuration = 1 hours;
        uint256 expcRandom = 90045193541034823946955040002439578345925946192123642160420600331405398852504;
        vm.expectEmit(address(timeSlotSystem));
        emit ITimeSlotSystem.NextRoundAnnouncement(1, expcRandom, startingTime, slotDuration, fisherYatesShuffle(expcRandom));
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, slotDuration);
        assertEq(timeSlotSystem.isActiveOn(block.timestamp), false);
        assertEq(timeSlotSystem.roundStartedAt(), 0);
        assertEq(timeSlotSystem.nextRoundStartAt(), startingTime);
    }

    function test_restartAndStarted() public {
        vm.warp(0);
        uint256 startingTime = block.timestamp + 1 hours;
        uint256 slotDuration = 1 hours;
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, slotDuration);
        vm.warp(startingTime);
        assertEq(timeSlotSystem.isActiveOn(block.timestamp), true);
        assertEq(timeSlotSystem.roundStartedAt(), startingTime);
        assertEq(timeSlotSystem.nextRoundStartAt(), 0);
    }

    function test_afterRestartAndBeforeStart() public {
        uint256 startingTime = block.timestamp + 1 hours;
        uint256 slotDuration = 1 hours;
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, slotDuration);
        assertEq(timeSlotSystem.isActiveOn(block.timestamp), false);
        assertEq(timeSlotSystem.roundStartedAt(), 0);
        assertEq(timeSlotSystem.nextRoundStartAt(), startingTime);
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
        vm.warp(10000);
        uint256 startingTime = block.timestamp - 1 hours;
        uint256 slotDuration = 1 hours;
        vm.expectRevert("Invalid start time");
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, slotDuration);
    }

    function test_restart_firstRestartWithEmptySlotDuration_revert() public {
        uint256 startingTime = block.timestamp + 1 hours;
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, 1 hours);
        assertEq(timeSlotSystem.nextRoundStartAt(), startingTime);
        assertEq(timeSlotSystem.nextSlotDuration(), 1 hours);
    }

    function test_firstAccessAfterRoundStart() public {
        uint256 startingTime = block.timestamp + 1 hours;
        uint256 slotDuration = 1 hours;
        vm.prank(owner);
        timeSlotSystem.restart(startingTime, slotDuration);
        vm.warp(startingTime);
        vm.expectEmit(address(timeSlotSystem));
        emit ITimeSlotSystem.RoundStarted(1, 0, startingTime, slotDuration, 3);

        uint256 expcRandom = 14060197318521799830544281995515102828570105187169927350578527920070012718387;
        vm.expectEmit(address(timeSlotSystem));
        emit ITimeSlotSystem.NextRoundAnnouncement(2, expcRandom, slotDuration, 14401, fisherYatesShuffle(expcRandom));

        assertEq(timeSlotSystem.getCurrentPlayer(), player3);
        vm.warp(block.timestamp + slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player1);
        vm.warp(block.timestamp + slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player2);

        // Next round starts here
        vm.expectEmit(address(timeSlotSystem));
        emit ITimeSlotSystem.RoundStarted(2, 0, 14401, slotDuration, 3);
        expcRandom = 58929516342146752248318105509329355679184442390785039174273888353726450426109;
        vm.expectEmit(address(timeSlotSystem));
        emit ITimeSlotSystem.NextRoundAnnouncement(3, expcRandom, slotDuration, 25201, fisherYatesShuffle(expcRandom));
        vm.warp(block.timestamp + slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player2);
        vm.warp(block.timestamp + slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player1);
        vm.warp(block.timestamp + slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player3);

        // Next round starts here
        vm.expectEmit(address(timeSlotSystem));
        emit ITimeSlotSystem.RoundStarted(3, 1, 25201, slotDuration, 3);
        expcRandom = 95663239321759996399985236510040750497076662416542587399129177390727309568828;
        vm.expectEmit(address(timeSlotSystem));
        emit ITimeSlotSystem.NextRoundAnnouncement(4, expcRandom, slotDuration, 36001, fisherYatesShuffle(expcRandom));
        vm.warp(block.timestamp + 2 * slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player1);
        vm.warp(block.timestamp + slotDuration);
        assertEq(timeSlotSystem.getCurrentPlayer(), player3);

        // Next round starts here
        vm.warp(block.timestamp + slotDuration);
        vm.expectEmit(address(timeSlotSystem));
        emit ITimeSlotSystem.RoundStarted(4, 0, 36001, slotDuration, 3);
        expcRandom = 40484017006162911396215742235401181641635690429308957077172007996218646966913;
        vm.expectEmit(address(timeSlotSystem));
        emit ITimeSlotSystem.NextRoundAnnouncement(5, expcRandom, slotDuration, 46801, fisherYatesShuffle(expcRandom));
        assertEq(timeSlotSystem.getCurrentPlayer(), player3);
    }

    function fisherYatesShuffle(uint256 random) private view returns(uint256[] memory slots) {
        uint256 totalSlots = mockNFT.totalSupply();
        // Fisher-Yates shuffle
        slots = new uint[](totalSlots);
        for (uint256 i = 0; i < totalSlots-1; i++) {
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
