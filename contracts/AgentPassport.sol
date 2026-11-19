// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal read interface of the Agent ID registry (SPACE ID Agent ID, ERC-721).
interface IAgentIdRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title Agent Passport
/// @notice A free soulbound NFT pass for holders of an Agent ID.
/// @dev Minimal hand-rolled ERC-721 (no external dependencies) to keep
/// deployment gas low. The pass is non-transferable: every transfer and
/// approval function reverts. There is no owner, no admin, no pause, no
/// upgradeability, no mint fee and no royalties.
contract AgentPassport {
    /// @notice The Agent ID registry on BNB Chain.
    IAgentIdRegistry public immutable agentIdRegistry;

    string public constant name = "Agent Passport";
    string public constant symbol = "AGPASS";

    uint256 public totalSupply;

    uint256 private _nextTokenId = 1;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _tokenOf;

    struct Profile {
        string name;
        string bio;
        string link;
    }

    mapping(uint256 => Profile) private _profiles;

    mapping(address => mapping(address => bool)) private _attested;
    mapping(address => uint256) private _attestationCount;

    error NotAgentIdHolder();
    error AlreadyHasPass();
    error NotPassHolder();
    error TargetNotPassHolder();
    error SelfAttestation();
    error AlreadyAttested();
    error NotAttested();
    error NameTooLong();
    error BioTooLong();
    error LinkTooLong();
    error TokenDoesNotExist();
    error ZeroAddress();
    error Soulbound();

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Mint(address indexed holder, uint256 indexed tokenId);
    event ProfileSet(address indexed holder, uint256 indexed tokenId);
    event AttestationAdded(address indexed attester, address indexed agent);
    event AttestationRemoved(address indexed attester, address indexed agent);

    constructor(address registry) {
        if (registry == address(0)) revert ZeroAddress();
        agentIdRegistry = IAgentIdRegistry(registry);
    }

    // ------------------------------------------------------------------
    // Minting
    // ------------------------------------------------------------------

    /// @notice Mint one free pass. Caller must hold an Agent ID and must
    /// not already hold a pass. Token IDs are sequential from 1.
    function mint() external returns (uint256 tokenId) {
        if (agentIdRegistry.balanceOf(msg.sender) < 1) revert NotAgentIdHolder();
        if (_tokenOf[msg.sender] != 0) revert AlreadyHasPass();
        tokenId = _nextTokenId++;
        _owners[tokenId] = msg.sender;
        _tokenOf[msg.sender] = tokenId;
        unchecked {
            ++_balances[msg.sender];
            ++totalSupply;
        }
        emit Transfer(address(0), msg.sender, tokenId);
        emit Mint(msg.sender, tokenId);
    }

    // ------------------------------------------------------------------
    // Profiles
    // ------------------------------------------------------------------

    /// @notice Set the caller's public profile. Length caps in bytes:
    /// name <= 64, bio <= 280, link <= 128.
    function setProfile(string calldata name_, string calldata bio, string calldata link) external {
        uint256 tokenId = _tokenOf[msg.sender];
        if (tokenId == 0) revert NotPassHolder();
        if (bytes(name_).length > 64) revert NameTooLong();
        if (bytes(bio).length > 280) revert BioTooLong();
        if (bytes(link).length > 128) revert LinkTooLong();
        _profiles[tokenId] = Profile(name_, bio, link);
        emit ProfileSet(msg.sender, tokenId);
    }

    // ------------------------------------------------------------------
    // Attestations
    // ------------------------------------------------------------------

    /// @notice Vouch for another pass holder. One attestation per pair.
    function attest(address agent) external {
        if (_tokenOf[msg.sender] == 0) revert NotPassHolder();
        if (_tokenOf[agent] == 0) revert TargetNotPassHolder();
        if (agent == msg.sender) revert SelfAttestation();
        if (_attested[msg.sender][agent]) revert AlreadyAttested();
        _attested[msg.sender][agent] = true;
        unchecked {
            ++_attestationCount[agent];
        }
        emit AttestationAdded(msg.sender, agent);
    }

    /// @notice Remove a previously given attestation.
    function revokeAttestation(address agent) external {
        if (!_attested[msg.sender][agent]) revert NotAttested();
        // The change IS logged: AttestationRemoved is emitted below for
        // exactly this (attester, agent) pair.
        // forge-lint: disable-next-line(missing-events-access-control)
        _attested[msg.sender][agent] = false;
        emit AttestationRemoved(msg.sender, agent);
        unchecked {
            --_attestationCount[agent];
        }
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    function hasPass(address who) external view returns (bool) {
        return _tokenOf[who] != 0;
    }

    function tokenOf(address who) external view returns (uint256) {
        return _tokenOf[who];
    }

    /// @notice Returns (name, bio, link). Empty strings when the address
    /// holds no pass or has not set a profile.
    function profileOf(address who) external view returns (string memory, string memory, string memory) {
        Profile storage p = _profiles[_tokenOf[who]];
        return (p.name, p.bio, p.link);
    }

    function attestationCount(address who) external view returns (uint256) {
        return _attestationCount[who];
    }

    function hasAttested(address attester, address agent) external view returns (bool) {
        return _attested[attester][agent];
    }

    // ------------------------------------------------------------------
    // ERC-721 (minimal, soulbound)
    // ------------------------------------------------------------------

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert TokenDoesNotExist();
        return owner;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        address holder = _owners[tokenId];
        if (holder == address(0)) revert TokenDoesNotExist();
        // string.concat (not abi.encodePacked): the dynamic parts (token id,
        // holder address) sit between fixed literals, so no collision.
        return string.concat(
            'data:application/json,{"name":"Agent Passport #',
            _toString(tokenId),
            '","description":"A soulbound passport for an Agent ID holder.","attributes":[{"trait_type":"holder","value":"',
            _toHex(holder),
            '"}]}'
        );
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        if (_owners[tokenId] == address(0)) revert TokenDoesNotExist();
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165
            || interfaceId == 0x80ac58cd // ERC721
            || interfaceId == 0x5b5e139f; // ERC721Metadata
    }

    function transferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert Soulbound();
    }

    function approve(address, uint256) external pure {
        revert Soulbound();
    }

    function setApprovalForAll(address, bool) external pure {
        revert Soulbound();
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits = 0;
        while (temp != 0) {
            ++digits;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        bytes memory alphabet = "0123456789";
        while (value != 0) {
            --digits;
            buffer[digits] = alphabet[value % 10];
            value /= 10;
        }
        return string(buffer);
    }

    function _toHex(address value) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory buffer = new bytes(42);
        buffer[0] = "0";
        buffer[1] = "x";
        uint160 v = uint160(value);
        for (uint256 i = 0; i < 20; ++i) {
            buffer[2 + i * 2] = alphabet[(v >> (8 * (19 - i) + 4)) & 0xf];
            buffer[3 + i * 2] = alphabet[(v >> (8 * (19 - i))) & 0xf];
        }
        return string(buffer);
    }
}
