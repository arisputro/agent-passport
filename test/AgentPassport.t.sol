// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/AgentPassport.sol";
import "./MockAgentIdRegistry.sol";

contract AgentPassportTest is Test {
    AgentPassport passport;
    MockAgentIdRegistry registry;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCA901);

    function setUp() public {
        registry = new MockAgentIdRegistry();
        passport = new AgentPassport(address(registry));
        registry.setBalance(alice, 1);
        registry.setBalance(bob, 1);
        registry.setBalance(carol, 1);
    }

    // ------------------------------------------------------------------
    // Minting
    // ------------------------------------------------------------------

    function testMintWithoutAgentIdReverts() public {
        address stranger = address(0x999);
        vm.prank(stranger);
        vm.expectRevert(AgentPassport.NotAgentIdHolder.selector);
        passport.mint();
    }

    function testMintWithAgentIdSucceeds() public {
        vm.prank(alice);
        uint256 tokenId = passport.mint();
        assertEq(tokenId, 1);
        assertTrue(passport.hasPass(alice));
        assertEq(passport.tokenOf(alice), 1);
        assertEq(passport.totalSupply(), 1);
        assertEq(passport.balanceOf(alice), 1);
        assertEq(passport.ownerOf(1), alice);
    }

    function testSecondMintReverts() public {
        vm.prank(alice);
        passport.mint();
        vm.prank(alice);
        vm.expectRevert(AgentPassport.AlreadyHasPass.selector);
        passport.mint();
    }

    function testTokenIdsAreSequential() public {
        vm.prank(alice);
        assertEq(passport.mint(), 1);
        vm.prank(bob);
        assertEq(passport.mint(), 2);
        assertEq(passport.totalSupply(), 2);
    }

    // ------------------------------------------------------------------
    // Profiles
    // ------------------------------------------------------------------

    function testSetProfile() public {
        vm.prank(alice);
        passport.mint();
        vm.prank(alice);
        passport.setProfile("Alice Agent", "Signal bot on BNB Chain", "https://example.com/alice");
        (string memory n, string memory b, string memory l) = passport.profileOf(alice);
        assertEq(n, "Alice Agent");
        assertEq(b, "Signal bot on BNB Chain");
        assertEq(l, "https://example.com/alice");
    }

    function testSetProfileWithoutPassReverts() public {
        vm.prank(address(0x999));
        vm.expectRevert(AgentPassport.NotPassHolder.selector);
        passport.setProfile("X", "", "");
    }

    function testSetProfileNameCap() public {
        vm.prank(alice);
        passport.mint();
        string memory tooLong = new string(65);
        vm.prank(alice);
        vm.expectRevert(AgentPassport.NameTooLong.selector);
        passport.setProfile(tooLong, "", "");
        // exactly 64 bytes passes
        string memory ok = new string(64);
        vm.prank(alice);
        passport.setProfile(ok, "", "");
    }

    function testSetProfileBioCap() public {
        vm.prank(alice);
        passport.mint();
        vm.prank(alice);
        vm.expectRevert(AgentPassport.BioTooLong.selector);
        passport.setProfile("", new string(281), "");
        vm.prank(alice);
        passport.setProfile("", new string(280), "");
    }

    function testSetProfileLinkCap() public {
        vm.prank(alice);
        passport.mint();
        vm.prank(alice);
        vm.expectRevert(AgentPassport.LinkTooLong.selector);
        passport.setProfile("", "", new string(129));
        vm.prank(alice);
        passport.setProfile("", "", new string(128));
    }

    function testProfileOfNonHolderIsEmpty() public {
        (string memory n, string memory b, string memory l) = passport.profileOf(address(0x999));
        assertEq(bytes(n).length, 0);
        assertEq(bytes(b).length, 0);
        assertEq(bytes(l).length, 0);
    }

    // ------------------------------------------------------------------
    // Attestations
    // ------------------------------------------------------------------

    function _mintAliceBob() internal {
        vm.prank(alice);
        passport.mint();
        vm.prank(bob);
        passport.mint();
    }

    function testAttest() public {
        _mintAliceBob();
        vm.prank(alice);
        passport.attest(bob);
        assertTrue(passport.hasAttested(alice, bob));
        assertEq(passport.attestationCount(bob), 1);
    }

    function testAttestSelfReverts() public {
        _mintAliceBob();
        vm.prank(alice);
        vm.expectRevert(AgentPassport.SelfAttestation.selector);
        passport.attest(alice);
    }

    function testAttestNonHolderTargetReverts() public {
        vm.prank(alice);
        passport.mint();
        vm.prank(alice);
        vm.expectRevert(AgentPassport.TargetNotPassHolder.selector);
        passport.attest(address(0x999));
    }

    function testAttestByNonHolderReverts() public {
        vm.prank(bob);
        passport.mint();
        vm.prank(address(0x999));
        vm.expectRevert(AgentPassport.NotPassHolder.selector);
        passport.attest(bob);
    }

    function testAttestDuplicateReverts() public {
        _mintAliceBob();
        vm.prank(alice);
        passport.attest(bob);
        vm.prank(alice);
        vm.expectRevert(AgentPassport.AlreadyAttested.selector);
        passport.attest(bob);
    }

    function testRevokeAttestation() public {
        _mintAliceBob();
        vm.prank(alice);
        passport.attest(bob);
        vm.prank(alice);
        passport.revokeAttestation(bob);
        assertFalse(passport.hasAttested(alice, bob));
        assertEq(passport.attestationCount(bob), 0);
        // can attest again after revoking
        vm.prank(alice);
        passport.attest(bob);
        assertEq(passport.attestationCount(bob), 1);
    }

    function testRevokeWithoutAttestationReverts() public {
        _mintAliceBob();
        vm.prank(alice);
        vm.expectRevert(AgentPassport.NotAttested.selector);
        passport.revokeAttestation(bob);
    }

    // ------------------------------------------------------------------
    // Soulbound
    // ------------------------------------------------------------------

    function testTransfersRevert() public {
        vm.prank(alice);
        passport.mint();
        vm.prank(alice);
        vm.expectRevert(AgentPassport.Soulbound.selector);
        passport.transferFrom(alice, bob, 1);
        vm.prank(alice);
        vm.expectRevert(AgentPassport.Soulbound.selector);
        passport.safeTransferFrom(alice, bob, 1);
        vm.prank(alice);
        vm.expectRevert(AgentPassport.Soulbound.selector);
        passport.safeTransferFrom(alice, bob, 1, "");
        vm.prank(alice);
        vm.expectRevert(AgentPassport.Soulbound.selector);
        passport.approve(bob, 1);
        vm.prank(alice);
        vm.expectRevert(AgentPassport.Soulbound.selector);
        passport.setApprovalForAll(bob, true);
    }

    function testApprovalsAreEmpty() public {
        vm.prank(alice);
        passport.mint();
        assertEq(passport.getApproved(1), address(0));
        assertFalse(passport.isApprovedForAll(alice, bob));
    }

    // ------------------------------------------------------------------
    // ERC-721 metadata / interfaces
    // ------------------------------------------------------------------

    function testSupportsInterface() public view {
        assertTrue(passport.supportsInterface(0x01ffc9a7)); // ERC165
        assertTrue(passport.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(passport.supportsInterface(0x5b5e139f)); // ERC721Metadata
        assertFalse(passport.supportsInterface(0xffffffff));
    }

    function testTokenURI() public {
        vm.prank(alice);
        passport.mint();
        string memory uri = passport.tokenURI(1);
        // data URI prefix
        assertEq(bytes(uri).length > 24, true);
        assertTrue(_startsWith(uri, "data:application/json,"));
        assertTrue(_contains(uri, '"name":"Agent Passport #1"'));
        assertTrue(_contains(uri, "0x00000000000000000000000000000000000a11ce"));
        assertTrue(_contains(uri, '"trait_type":"holder"'));
    }

    function testTokenURINonexistentReverts() public {
        vm.expectRevert(AgentPassport.TokenDoesNotExist.selector);
        passport.tokenURI(99);
    }

    function testOwnerOfNonexistentReverts() public {
        vm.expectRevert(AgentPassport.TokenDoesNotExist.selector);
        passport.ownerOf(99);
    }

    function testRegistryAddress() public view {
        assertEq(address(passport.agentIdRegistry()), address(registry));
        assertEq(passport.name(), "Agent Passport");
        assertEq(passport.symbol(), "AGPASS");
    }

    // ------------------------------------------------------------------
    // String helpers for assertions
    // ------------------------------------------------------------------

    function _startsWith(string memory s, string memory prefix) internal pure returns (bool) {
        bytes memory sb = bytes(s);
        bytes memory pb = bytes(prefix);
        if (sb.length < pb.length) return false;
        for (uint256 i = 0; i < pb.length; ++i) {
            if (sb[i] != pb[i]) return false;
        }
        return true;
    }

    function _contains(string memory s, string memory needle) internal pure returns (bool) {
        bytes memory sb = bytes(s);
        bytes memory nb = bytes(needle);
        if (nb.length == 0 || sb.length < nb.length) return false;
        for (uint256 i = 0; i <= sb.length - nb.length; ++i) {
            bool found = true;
            for (uint256 j = 0; j < nb.length; ++j) {
                if (sb[i + j] != nb[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}
