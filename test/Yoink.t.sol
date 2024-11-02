// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Yoink, Yoinked, Score, SlowDown, Unauthorized} from "../src/Yoink.sol";

error InsufficientBalance();

contract YoinkTest is Test {
    Yoink public yoink;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        yoink = new Yoink();
        vm.warp(block.timestamp + yoink.COOLDOWN());
    }

    function test_yoink_increments_totalYoinks() public {
        assertEq(yoink.totalYoinks(), 0);

        vm.prank(alice);
        yoink.yoink();
        assertEq(yoink.totalYoinks(), 1);

        vm.prank(bob);
        yoink.yoink();
        assertEq(yoink.totalYoinks(), 2);
    }

    function test_yoink_stores_lastYoinkedAt() public {
        assertEq(yoink.lastYoinkedAt(), 1);

        vm.warp(block.timestamp + 1);
        vm.prank(alice);
        yoink.yoink();
        assertEq(yoink.lastYoinkedAt(), 602);

        vm.warp(block.timestamp + 1);
        vm.prank(bob);
        yoink.yoink();
        assertEq(yoink.lastYoinkedAt(), 603);
    }

    function test_yoink_stores_lastYoinkedBy() public {
        assertEq(yoink.lastYoinkedBy(), address(yoink));

        vm.prank(alice);
        yoink.yoink();
        assertEq(yoink.lastYoinkedBy(), alice);

        vm.prank(bob);
        yoink.yoink();
        assertEq(yoink.lastYoinkedBy(), bob);

        vm.warp(block.timestamp + yoink.COOLDOWN());
        vm.prank(alice);
        yoink.yoink();
        assertEq(yoink.lastYoinkedBy(), alice);
    }

    function test_score_stores_yoinks_by_user() public {
        Score memory score = yoink.score(alice);
        assertEq(score.yoinks, 0);

        vm.prank(alice);
        yoink.yoink();

        score = yoink.score(alice);
        assertEq(score.yoinks, 1);
    }

    function test_score_tracks_holding_time() public {
        vm.prank(alice);
        yoink.yoink();

        vm.warp(block.timestamp + 100);

        Score memory score = yoink.score(alice);
        assertEq(score.time, 100);

        vm.prank(bob);
        yoink.yoink();

        score = yoink.score(alice);
        assertEq(score.time, 100);

        vm.warp(block.timestamp + 50);

        score = yoink.score(bob);
        assertEq(score.time, 50);

        vm.warp(block.timestamp + yoink.COOLDOWN());
        vm.prank(alice);
        yoink.yoink();

        score = yoink.score(bob);
        assertEq(score.time, 650);

        score = yoink.score(alice);
        assertEq(score.time, 100);
    }

    function test_cooldown() public {
        vm.prank(alice);
        yoink.yoink();

        vm.prank(bob);
        yoink.yoink();

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SlowDown.selector, 10 minutes));
        yoink.yoink();

        vm.warp(block.timestamp + 9 minutes);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SlowDown.selector, 1 minutes));
        yoink.yoink();

        vm.warp(block.timestamp + 1 minutes);

        vm.prank(alice);
        yoink.yoink();
    }

    function test_yoink_emits_event() public {
        vm.warp(block.timestamp + 100);
        _expectYoinkEvent(bob, address(yoink));
        vm.prank(bob);
        yoink.yoink();

        vm.warp(block.timestamp + yoink.COOLDOWN());
        _expectYoinkEvent(alice, bob);
        vm.prank(alice);
        yoink.yoink();
    }

    function test_initial_flag_ownership() public view {
        assertEq(yoink.balanceOf(address(yoink), yoink.FLAG_ID()), 1);
        assertEq(yoink.balanceOf(alice, yoink.FLAG_ID()), 0);
    }

    function test_yoink_transfers_flag() public {
        vm.prank(alice);
        yoink.yoink();

        assertEq(yoink.balanceOf(address(yoink), yoink.FLAG_ID()), 0);
        assertEq(yoink.balanceOf(alice, yoink.FLAG_ID()), 1);
    }

    function test_yoink_transfers_flag_between_users() public {
        vm.prank(alice);
        yoink.yoink();
        assertEq(yoink.balanceOf(alice, yoink.FLAG_ID()), 1);

        vm.warp(block.timestamp + yoink.COOLDOWN());
        vm.prank(bob);
        yoink.yoink();

        assertEq(yoink.balanceOf(alice, yoink.FLAG_ID()), 0);
        assertEq(yoink.balanceOf(bob, yoink.FLAG_ID()), 1);
    }

    function test_yoink_to_contract_receiver() public {
        MockERC1155Receiver receiver = new MockERC1155Receiver();

        vm.prank(address(receiver));
        yoink.yoink();

        assertEq(yoink.balanceOf(address(receiver), yoink.FLAG_ID()), 1);
    }

    function _expectYoinkEvent(address by, address from) internal {
        vm.expectEmit(true, true, true, true);
        emit Yoinked(by, from);
    }

    function test_yoink_prevents_reentrancy() public {
        ReentrantERC1155Receiver attacker = new ReentrantERC1155Receiver();

        vm.prank(address(attacker));
        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector));
        yoink.yoink();
    }

    function test_direct_transfer_of_flag_reverts() public {
        vm.prank(alice);
        yoink.yoink();

        uint256 id = yoink.FLAG_ID();
        vm.startPrank(alice);
        vm.expectRevert(Unauthorized.selector);
        yoink.safeTransferFrom(alice, bob, id, 1, "");
        vm.stopPrank();
    }

    function test_batch_transfer_of_flag_reverts() public {
        vm.prank(alice);
        yoink.yoink();

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = yoink.FLAG_ID();
        amounts[0] = 1;

        vm.startPrank(alice);
        vm.expectRevert(Unauthorized.selector);
        yoink.safeBatchTransferFrom(alice, bob, ids, amounts, "");
        vm.stopPrank();
    }

    function test_score_token_minted_once() public {
        vm.prank(alice);
        yoink.yoink();

        vm.prank(bob);
        yoink.yoink();

        uint256 aliceScoreTokenId = uint256(uint160(alice));
        assertEq(yoink.balanceOf(alice, aliceScoreTokenId), 1);

        vm.warp(block.timestamp + yoink.COOLDOWN());

        vm.prank(alice);
        yoink.yoink();
        assertEq(yoink.balanceOf(alice, aliceScoreTokenId), 1);

        vm.prank(bob);
        yoink.yoink();

        vm.warp(block.timestamp + yoink.COOLDOWN());
        vm.prank(alice);
        yoink.yoink();
        assertEq(yoink.balanceOf(alice, aliceScoreTokenId), 1);
    }

    function test_score_token_multiple_players() public {
        vm.prank(alice);
        yoink.yoink();
        uint256 aliceScoreTokenId = uint256(uint160(alice));
        assertEq(yoink.balanceOf(alice, aliceScoreTokenId), 1);

        vm.prank(bob);
        yoink.yoink();
        uint256 bobScoreTokenId = uint256(uint160(bob));
        assertEq(yoink.balanceOf(bob, bobScoreTokenId), 1);

        assertEq(yoink.balanceOf(alice, bobScoreTokenId), 0);
        assertEq(yoink.balanceOf(bob, aliceScoreTokenId), 0);
    }

    function test_cannot_yoink_from_self() public {
        vm.prank(alice);
        yoink.yoink();

        vm.warp(block.timestamp + yoink.COOLDOWN());

        vm.prank(alice);
        vm.expectRevert(Unauthorized.selector);
        yoink.yoink();
    }
}

contract MockERC1155Receiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        public
        pure
        returns (bytes4)
    {
        return bytes4(0xf23a6e61);
    }
}

contract ReentrantERC1155Receiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        returns (bytes4)
    {
        Yoink(msg.sender).yoink();
        return bytes4(0xf23a6e61);
    }
}
