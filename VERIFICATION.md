# BscScan verification inputs — AgentPassport

- Network: BNB Chain (chain ID 56)
- Contract: `0x0aee32055557837b73b5e14a2b8dd25f1bde789e`
- Deployment tx: `0xfbf69e98b3e96b7c85dcf31588680e5a3fb819c8f6b6b84e804564662c17983b`
- Verification type: Solidity (Single file)
- Compiler: v0.8.24+commit.e11b9ed9
- Optimization: Yes, 200 runs
- License: MIT (SPDX-License-Identifier: MIT in source)
- Constructor arguments (ABI-encoded, 1 word): `00000000000000000000000060b9262456de011f7d15a54cdd8c48baaa8b022f`
- Source: `contracts/AgentPassport.sol` (no imports; single file)

## Notes

- The on-chain runtime code matches the Foundry artifact byte-for-byte
  except the `agentIdRegistry` immutable slot, which is zero in the artifact
  and holds the registry address on-chain — expected; BscScan fills
  immutables from the constructor arguments.
- Deployed via the canonical deterministic deployment proxy
  (`0x4e59b44847b379578588920cA78FbF26c0B4956C`, CREATE2, salt 0) because
  the Binance Agentic Wallet cannot send a bare contract-creation tx.
- Deployed bytecode: 5,726 bytes. Creation bytecode: 5,940 bytes.
- Status: pending (attempt via BscScan web form; no API key available).
