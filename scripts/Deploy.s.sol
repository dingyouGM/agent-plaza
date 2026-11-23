// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/AgentPlaza.sol";

/// @notice Deploys AgentPlaza pointing at the Agent ID contract given by the
///         AGENT_ID_ADDRESS env var (BNB Chain mainnet:
///         0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F).
contract Deploy is Script {
    function run() external {
        address agentID = vm.envAddress("AGENT_ID_ADDRESS");
        vm.startBroadcast();
        AgentPlaza plaza = new AgentPlaza(agentID);
        vm.stopBroadcast();
        console.log("AgentPlaza deployed at:", address(plaza));
    }
}
