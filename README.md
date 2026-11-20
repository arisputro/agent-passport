# Agent Passport

A free soulbound NFT passport for Agent ID holders, with a verified-agent
directory and attestations between agents. Built for the Agent ID Hackathon
(submission deadline 9 Dec 2026 08:00 UTC).

No Telegram bot is involved. No server, no accounts, no tracking, no data
is collected.

## What it is

- **AgentPassport** — a minimal, hand-rolled ERC-721 contract on BNB Chain.
  Any address holding an Agent ID can mint exactly one passport, for free
  (gas only). The passport is soulbound: it cannot be transferred, approved,
  or sold.
- **Profiles** — a pass holder can publish a short public profile (name, bio,
  link). Only profiles set voluntarily appear in the directory.
- **Attestations** — a pass holder can vouch for another pass holder, one
  attestation per pair, revocable at any time.
- **Web app** (`web/`) — a static page (no build step, no backend) to mint,
  set a profile, attest, and browse the directory.

## How the Agent ID gate works

`mint()` calls `balanceOf(msg.sender)` on the Agent ID registry
(`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, ERC-721) and requires a
balance greater than zero. No Agent ID, no mint. One passport per address;
a second mint reverts. The registry address is immutable, set once in the
constructor.

## Contract design

- File: `contracts/AgentPassport.sol` (Solidity 0.8.24, Foundry).
- Minimal ERC-721 written by hand — no external dependencies — to keep
  deployment gas low. Measured deployment gas: **1,316,045** (5,940 bytes).
- Functions: `mint()`, `setProfile(name, bio, link)` (byte caps 64 / 280 /
  128), `attest(agent)`, `revokeAttestation(agent)`.
- Views: `hasPass`, `tokenOf`, `profileOf`, `attestationCount`,
  `hasAttested`, `totalSupply`, `agentIdRegistry`, plus standard ERC-721
  `balanceOf`, `ownerOf`, `tokenURI`, `supportsInterface`.
- `tokenURI` returns a `data:application/json` URI (name, description,
  holder address). No external image dependency.
- Every state change emits an event (`Mint`, `ProfileSet`,
  `AttestationAdded`, `AttestationRemoved`, plus ERC-721 `Transfer` on mint).

### No owner privileges

The contract has **no owner and no admin functions**: no pause, no
upgradeability, no mint fee, no royalties, no function that can move or
freeze anyone's passport. The deployer has no special powers after
deployment.

## Gas (measured, Foundry gas report)

| Operation | Gas (first call / max in tests) |
|---|---|
| Deployment | 1,316,045 |
| `mint` | ~124,000 |
| `setProfile` | ~96,000 (long strings; ~43,000 typical) |
| `attest` | ~72,000 |
| `revokeAttestation` | ~34,000 |

At the 0.1 gwei gas-price floor, deployment costs about 0.000132 BNB —
almost exactly the deployer wallet's current balance (~0.0001359 BNB).
At any higher gas price a small top-up is needed before deploying.

## Tests

```bash
forge build
forge test
```

- `test/AgentPassport.t.sol` — 24 unit tests with a mock Agent ID registry:
  mint gating, one-mint rule, profile caps, attestation rules, soulbound
  transfers revert, `tokenURI` JSON.
- `test/AgentPassportFork.t.sol` — 4 fork tests against BSC mainnet using
  the real Agent ID contract: the user's wallet
  (`0x59B6C7D8471F8220f06899A360E5440A895918F6`, holder of `poetro.ai`)
  can mint; an address without an Agent ID reverts.
- `script/DeployLocal.s.sol` — local anvil deployment helper (test only).

All 28 tests pass. `forge build` is warning-free.

## Web app

Static files under `web/` (`index.html`, `app.js`, `style.css`, plus a
vendored `ethers.min.js` v6.13.4 — no CDN, no build step). Serve the
directory with any static server, e.g.:

```bash
cd web && python3 -m http.server 8123
```

The same files are mirrored in `docs/` — that copy exists only so GitHub
Pages (which only publishes from `/` or `/docs`) can host the site.
`web/` is the source of truth; keep the two copies in sync.

- Wallet connect uses the **injected provider only** (`window.ethereum`).
  No WalletConnect, no QR codes, no pairing codes. Open the page inside
  your wallet app's browser, or use a browser wallet such as MetaMask.
- Reads use a public BSC RPC when no wallet is connected.
- Every write (mint, set profile, attest, revoke) is user-initiated and
  confirmed in the user's own wallet.
- The directory lists **only** pass holders who voluntarily set a public
  profile. It is **not** a lookup of arbitrary wallets by Agent ID — this
  is stated on the page.
- Free to mint. No rewards, returns, or income are promised.

## Deployed contract

- Network: BNB Chain (chain ID 56)
- Contract address: `0x0aee32055557837b73b5e14a2b8dd25f1bde789e`
- Deployment tx: `0xfbf69e98b3e96b7c85dcf31588680e5a3fb819c8f6b6b84e804564662c17983b` (block 134590384, gas used 1,318,553 at 0.0622 gwei, cost ~0.000082 BNB)
- Deployed via the canonical deterministic deployment proxy (`0x4e59b44847b379578588920cA78FbF26c0B4956C`, CREATE2, salt 0) — the Agentic Wallet cannot send a bare contract-creation transaction, so the proxy created the contract. The deployed bytecode and constructor argument (Agent ID registry) are identical to a direct deployment; the contract has no owner/admin, so the deployer address is irrelevant.
- BscScan verification: **verified** — https://bscscan.com/address/0x0aee32055557837b73b5e14a2b8dd25f1bde789e#code

## Hackathon red-line compliance

- No web QR login, no pairing codes, no stored login sessions.
- No transaction is ever sent without the user confirming it in their own
  wallet; nothing bypasses user confirmation.
- No unauthorized transfers; no unlimited approvals are requested.
- Contract is open source (MIT) with no owner permissions to disclose.
- No brand impersonation: no third-party logos or brand names are used anywhere.
- No seed phrases, private keys, API secrets, or pairing codes are
  collected — the app never asks for them.
- No returns are promised anywhere in the app or docs.
- Agent ID is not packaged as a tool for looking up other people's
  wallets: the directory shows only self-published profiles.

## License

MIT — see `LICENSE`.
