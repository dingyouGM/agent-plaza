// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/AgentPlaza.sol";
import "./AgentPlaza.t.sol";

contract TokenURIDecodeTest is Test {
    function testDecode() public {
        MockAgentID mock = new MockAgentID();
        AgentPlaza plaza = new AgentPlaza(address(mock));
        address alice = address(0xA11CE);
        mock.setHandle(alice, "alice");
        vm.prank(alice);
        plaza.post("uri check");
        string memory uri = plaza.tokenURI(1);
        console.log(uri);
    }
}
