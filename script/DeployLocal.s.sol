// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/AgentPassport.sol";
import "../test/MockAgentIdRegistry.sol";

/// @notice Local test deployment only (anvil). Deploys a mock Agent ID
/// registry, funds anvil account 0 with a mock Agent ID, then deploys
/// AgentPassport against it. NOT for mainnet — the parent deploys the
/// real contract with the real registry via the Agentic Wallet.
contract DeployLocal is Script {
    function run() external {
        vm.startBroadcast();
        MockAgentIdRegistry registry = new MockAgentIdRegistry();
        registry.setBalance(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 1);
        AgentPassport passport = new AgentPassport(address(registry));
        vm.stopBroadcast();
        console.log("REGISTRY:", address(registry));
        console.log("PASSPORT:", address(passport));
    }
}
