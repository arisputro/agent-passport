// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/AgentPassport.sol";

/// @notice Fork test against BSC mainnet using the REAL Agent ID registry.
/// Run with: forge test --match-contract AgentPassportForkTest
contract AgentPassportForkTest is Test {
    address constant AGENT_ID_REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;
    address constant USER = 0x59B6C7D8471F8220f06899A360E5440A895918F6; // holds poetro.ai

    AgentPassport passport;

    function setUp() public {
        vm.createSelectFork("bsc");
        passport = new AgentPassport(AGENT_ID_REGISTRY);
    }

    function testUserHoldsAgentId() public view {
        uint256 bal = IAgentIdRegistry(AGENT_ID_REGISTRY).balanceOf(USER);
        assertGt(bal, 0, "user must hold an Agent ID (poetro.ai)");
    }

    function testRealHolderCanMint() public {
        vm.deal(USER, 1 ether);
        vm.prank(USER);
        uint256 tokenId = passport.mint();
        assertEq(tokenId, 1);
        assertTrue(passport.hasPass(USER));
        assertEq(passport.tokenOf(USER), 1);
        assertEq(passport.totalSupply(), 1);
        assertEq(passport.ownerOf(1), USER);
    }

    function testNonHolderRevertsOnFork() public {
        address stranger = address(0x1234567890123456789012345678901234567890);
        assertEq(IAgentIdRegistry(AGENT_ID_REGISTRY).balanceOf(stranger), 0);
        vm.deal(stranger, 1 ether);
        vm.prank(stranger);
        vm.expectRevert(AgentPassport.NotAgentIdHolder.selector);
        passport.mint();
    }

    function testRegistryAddressOnFork() public view {
        assertEq(address(passport.agentIdRegistry()), AGENT_ID_REGISTRY);
    }
}
