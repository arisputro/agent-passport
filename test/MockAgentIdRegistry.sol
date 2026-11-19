// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal ERC-721-like mock of the Agent ID registry for tests.
/// Only balanceOf matters to AgentPassport.
contract MockAgentIdRegistry {
    mapping(address => uint256) private _balances;

    function setBalance(address who, uint256 amount) external {
        _balances[who] = amount;
    }

    function balanceOf(address who) external view returns (uint256) {
        return _balances[who];
    }
}
