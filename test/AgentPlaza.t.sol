// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/AgentPlaza.sol";

contract MockAgentID {
    mapping(address => string) private _handles;

    function setHandle(address a, string calldata h) external {
        _handles[a] = h;
    }

    function balanceOf(address a) external view returns (uint256) {
        return bytes(_handles[a]).length > 0 ? 1 : 0;
    }

    function handleOf(address a) external view returns (string memory) {
        return _handles[a];
    }
}

contract AgentPlazaTest is Test {
    MockAgentID internal mock;
    AgentPlaza internal plaza;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal stranger = address(0x57A9);

    function setUp() public {
        mock = new MockAgentID();
        plaza = new AgentPlaza(address(mock));
        mock.setHandle(alice, "alice");
        mock.setHandle(bob, "bob");
    }

    function testNonHolderCannotPost() public {
        vm.prank(stranger);
        vm.expectRevert("Agent ID required");
        plaza.post("hello");
    }

    function testNonHolderCannotLike() public {
        vm.prank(alice);
        plaza.post("first");
        vm.prank(stranger);
        vm.expectRevert("Agent ID required");
        plaza.like(0);
    }

    function testPostMintsPassportOnce() public {
        vm.prank(alice);
        uint256 id = plaza.post("hello plaza");
        assertEq(id, 0);
        assertEq(plaza.passportOf(alice), 1);
        assertEq(plaza.balanceOf(alice), 1);
        assertEq(plaza.ownerOf(1), alice);
        assertEq(plaza.postsOf(alice), 1);

        vm.warp(block.timestamp + 31);
        vm.prank(alice);
        plaza.post("second post");
        assertEq(plaza.passportOf(alice), 1, "no second passport");
        assertEq(plaza.totalPassports(), 1);
        assertEq(plaza.postCount(), 2);
    }

    function testCooldownAndLength() public {
        vm.prank(alice);
        plaza.post("one");
        vm.prank(alice);
        vm.expectRevert("cooldown");
        plaza.post("too soon");

        vm.warp(block.timestamp + 31);
        vm.prank(alice);
        vm.expectRevert("empty post");
        plaza.post("");

        bytes memory big = new bytes(501);
        for (uint256 i = 0; i < big.length; i++) big[i] = "a";
        vm.prank(alice);
        vm.expectRevert("post too long");
        plaza.post(string(big));
    }

    function testLikeRules() public {
        vm.prank(alice);
        plaza.post("post by alice");
        vm.prank(bob);
        plaza.like(0);
        assertEq(plaza.likesReceivedOf(alice), 1);
        assertEq(plaza.likesGivenOf(bob), 1);

        vm.prank(bob);
        vm.expectRevert("already liked");
        plaza.like(0);

        vm.prank(bob);
        vm.expectRevert("no such post");
        plaza.like(99);
    }

    function testSoulbound() public {
        vm.prank(alice);
        plaza.post("mine");
        vm.prank(alice);
        vm.expectRevert("soulbound");
        plaza.transferFrom(alice, bob, 1);
    }

    function testGetPostsNewestFirst() public {
        vm.prank(alice);
        plaza.post("a1");
        vm.warp(block.timestamp + 31);
        vm.prank(bob);
        plaza.post("b1");

        (uint256[] memory ids, address[] memory authors, string[] memory contents,, uint32[] memory likeCounts, string[] memory handles) =
            plaza.getPosts(0, 10);
        assertEq(ids.length, 2);
        assertEq(ids[0], 1);
        assertEq(authors[0], bob);
        assertEq(contents[0], "b1");
        assertEq(handles[0], "bob");
        assertEq(contents[1], "a1");
        assertEq(likeCounts[0], 0);
    }

    function testTokenURIContainsHandleAndStats() public {
        vm.prank(alice);
        plaza.post("uri check");
        vm.prank(bob);
        plaza.like(0);
        string memory uri = plaza.tokenURI(1);
        bytes memory u = bytes(uri);
        assertGt(u.length, 100);
        // prefix check: data:application/json;base64,
        bytes memory prefix = bytes("data:application/json;base64,");
        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(u[i], prefix[i]);
        }
    }
}
