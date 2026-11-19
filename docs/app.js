/* Agent Passport — static web app.
 * No backend, no tracking, no data collection. Reads use a public BSC RPC;
 * writes are always user-initiated and confirmed in the user's own wallet.
 * Wallet connect uses the INJECTED provider only (window.ethereum).
 * No WalletConnect, no QR codes, no pairing codes anywhere.
 *
 * Test overrides (harmless in production): ?rpc=<url>&contract=<address>
 */

"use strict";

// TODO (parent): fill in after deployment.
const CONTRACT_ADDRESS = "0x0aee32055557837b73b5e14a2b8dd25f1bde789e";
const AGENT_ID_REGISTRY = "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F";
const BSC_CHAIN_ID = 56;
const PUBLIC_RPCS = [
  "https://bsc-rpc.publicnode.com",
];
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const MAX_DIRECTORY = 500;

const PASSPORT_ABI = [
  "function mint() returns (uint256)",
  "function setProfile(string name, string bio, string link)",
  "function attest(address agent)",
  "function revokeAttestation(address agent)",
  "function hasPass(address who) view returns (bool)",
  "function tokenOf(address who) view returns (uint256)",
  "function profileOf(address who) view returns (string, string, string)",
  "function attestationCount(address who) view returns (uint256)",
  "function hasAttested(address attester, address agent) view returns (bool)",
  "function totalSupply() view returns (uint256)",
  "function ownerOf(uint256 tokenId) view returns (address)",
  "function agentIdRegistry() view returns (address)",
];

const REGISTRY_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
];

const params = new URLSearchParams(window.location.search);
const rpcOverride = params.get("rpc");
const contractOverride = params.get("contract");
const contractAddress = contractOverride || CONTRACT_ADDRESS;
const contractDeployed = contractAddress.toLowerCase() !== ZERO_ADDRESS;

const $ = (id) => document.getElementById(id);

let readProvider = null; // ethers.JsonRpcProvider for public reads
let browserProvider = null; // ethers.BrowserProvider when a wallet is connected
let signer = null;
let account = null;
let passportRead = null;
let registryRead = null;

function shortAddr(a) {
  return a ? a.slice(0, 6) + "…" + a.slice(-4) : "";
}

function byteLen(s) {
  return new TextEncoder().encode(s).length;
}

function setMsg(id, text, isError) {
  const el = $(id);
  el.textContent = text || "";
  el.classList.toggle("error", !!isError);
}

async function getReadProvider() {
  if (readProvider) return readProvider;
  const urls = rpcOverride ? [rpcOverride] : PUBLIC_RPCS;
  for (const url of urls) {
    try {
      const p = new ethers.JsonRpcProvider(url);
      await p.getBlockNumber();
      readProvider = p;
      return p;
    } catch (e) {
      console.warn("RPC unreachable, trying next:", url);
    }
  }
  throw new Error("No public RPC reachable");
}

function getContracts(provider) {
  const passport = contractDeployed ? new ethers.Contract(contractAddress, PASSPORT_ABI, provider) : null;
  const registry = new ethers.Contract(AGENT_ID_REGISTRY, REGISTRY_ABI, provider);
  return { passport, registry };
}

async function refreshStatus() {
  const provider = await getReadProvider();
  const { passport, registry } = getContracts(provider);
  passportRead = passport;
  registryRead = registry;

  if (!contractDeployed) {
    $("contractLine").textContent = "Contract: not deployed yet — minting and the directory unlock after deployment.";
    $("agentIdStatus").textContent = account ? "checking…" : "connect your wallet to check";
    $("passStatus").textContent = "—";
    $("attestCount").textContent = "—";
    $("statusNote").textContent = "";
    if (account) {
      try {
        const bal = await registry.balanceOf(account);
        $("agentIdStatus").textContent = bal > 0n ? "held" : "not held";
      } catch (e) {
        $("agentIdStatus").textContent = "unavailable";
      }
    }
    return;
  }

  $("contractLine").textContent = "Contract: " + contractAddress;
  const total = await passport.totalSupply();
  $("directoryMeta").textContent = total + " passport(s) minted.";

  if (!account) {
    $("agentIdStatus").textContent = "connect your wallet to check";
    $("passStatus").textContent = "—";
    $("attestCount").textContent = "—";
    return;
  }

  const [agentBal, has, tokenId, count] = await Promise.all([
    registry.balanceOf(account),
    passport.hasPass(account),
    passport.tokenOf(account),
    passport.attestationCount(account),
  ]);
  $("agentIdStatus").textContent = agentBal > 0n ? "held" : "not held";
  $("passStatus").textContent = has ? "held (#" + tokenId.toString() + ")" : "not held";
  $("attestCount").textContent = count.toString();
  $("mintBtn").disabled = !(agentBal > 0n && !has);
  $("saveProfileBtn").disabled = !has;
  $("attestBtn").disabled = !has;
  $("revokeAttestBtn").disabled = !has;
  $("statusNote").textContent = has
    ? ""
    : agentBal > 0n
      ? "You hold an Agent ID — you can mint your free passport below."
      : "You need an Agent ID to mint a passport.";
  if (has) {
    const [n, b, l] = await passport.profileOf(account);
    if (!$("profileName").value) $("profileName").value = n;
    if (!$("profileBio").value) $("profileBio").value = b;
    if (!$("profileLink").value) $("profileLink").value = l;
  }
}

async function loadDirectory() {
  const dir = $("directory");
  if (!contractDeployed) {
    dir.innerHTML = "<p class=\"muted\">The directory unlocks after the contract is deployed.</p>";
    return;
  }
  dir.innerHTML = "<p class=\"muted\">Loading…</p>";
  try {
    const provider = await getReadProvider();
    const { passport } = getContracts(provider);
    const total = Number(await passport.totalSupply());
    const shown = Math.min(total, MAX_DIRECTORY);
    const visible = [];
    const CHUNK = 25;
    for (let start = 1; start <= shown; start += CHUNK) {
      const ids = [];
      for (let id = start; id < Math.min(start + CHUNK, shown + 1); id++) ids.push(id);
      const owners = await Promise.all(ids.map((id) => passport.ownerOf(id).catch(() => null)));
      const details = await Promise.all(owners.map(async (owner) => {
        if (!owner) return null;
        try {
          const [profile, count] = await Promise.all([
            passport.profileOf(owner),
            passport.attestationCount(owner),
          ]);
          return { owner, profile, count };
        } catch (e) {
          return null;
        }
      }));
      for (let i = 0; i < ids.length; i++) {
        const d = details[i];
        if (d && d.profile[0] && d.profile[0].trim() !== "") visible.push({ id: ids[i], ...d });
      }
      dir.innerHTML = "<p class=\"muted\">Loading " + Math.min(start + CHUNK - 1, shown) + " of " + shown + "…</p>";
    }
    if (visible.length === 0) {
      dir.innerHTML = "<p class=\"muted\">No public profiles yet. Mint a passport and set a profile to be listed here.</p>";
      return;
    }
    dir.innerHTML = "";
    for (const e of visible) {
      const div = document.createElement("div");
      div.className = "entry";
      const h = document.createElement("h3");
      h.textContent = e.profile[0];
      const bio = document.createElement("p");
      bio.textContent = e.profile[1] || "";
      const link = document.createElement("p");
      if (e.profile[2]) {
        const a = document.createElement("a");
        a.href = e.profile[2];
        a.textContent = e.profile[2];
        a.target = "_blank";
        a.rel = "noopener noreferrer";
        link.appendChild(a);
      }
      const meta = document.createElement("p");
      meta.className = "addr";
      meta.textContent = e.owner + " · #" + e.id + " · " + e.count.toString() + " attestation(s)";
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "attest-btn";
      btn.textContent = "Attest this agent";
      btn.addEventListener("click", () => {
        $("attestAddress").value = e.owner;
        $("attestAddress").scrollIntoView({ behavior: "smooth", block: "center" });
      });
      div.appendChild(h);
      if (e.profile[1]) div.appendChild(bio);
      if (e.profile[2]) div.appendChild(link);
      div.appendChild(meta);
      div.appendChild(btn);
      dir.appendChild(div);
    }
  } catch (e) {
    console.error(e);
    dir.innerHTML = "<p class=\"error\">Could not load the directory: " + escapeHtml(e.message || String(e)) + "</p>";
  }
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

async function connectWallet() {
  if (!window.ethereum) {
    $("walletLine").textContent = "No injected wallet found. Open this page inside your wallet app's browser, or install a browser wallet such as MetaMask.";
    return;
  }
  try {
    browserProvider = new ethers.BrowserProvider(window.ethereum);
    const accounts = await browserProvider.send("eth_requestAccounts", []);
    account = accounts[0];
    signer = await browserProvider.getSigner();
    $("walletLine").textContent = "Connected: " + account;
    const net = await browserProvider.getNetwork();
    if (Number(net.chainId) !== BSC_CHAIN_ID) {
      $("walletLine").textContent += " — wrong network (chain " + net.chainId + "). Please switch to BNB Chain (56).";
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: "0x38" }],
        });
      } catch (e) {
        console.warn("network switch declined/unavailable", e);
      }
    }
    await refreshStatus();
  } catch (e) {
    console.error(e);
    setMsg("walletLine", "Connection failed: " + (e.message || String(e)), true);
  }
}

async function withSigner(fn, msgId) {
  if (!signer || !account) {
    setMsg(msgId, "Connect your wallet first.", true);
    return;
  }
  if (!contractDeployed) {
    setMsg(msgId, "Contract not deployed yet.", true);
    return;
  }
  const net = await browserProvider.getNetwork();
  if (Number(net.chainId) !== BSC_CHAIN_ID) {
    setMsg(msgId, "Please switch your wallet to BNB Chain (chain ID 56).", true);
    return;
  }
  const contract = new ethers.Contract(contractAddress, PASSPORT_ABI, signer);
  try {
    setMsg(msgId, "Waiting for your confirmation in the wallet…");
    const tx = await fn(contract);
    setMsg(msgId, "Transaction sent: " + tx.hash + " — waiting for confirmation…");
    await tx.wait();
    setMsg(msgId, "Confirmed: " + tx.hash);
    await refreshStatus();
    await loadDirectory();
  } catch (e) {
    console.error(e);
    setMsg(msgId, "Failed: " + (e.reason || e.message || String(e)), true);
  }
}

function init() {
  $("connectBtn").addEventListener("click", connectWallet);
  $("refreshBtn").addEventListener("click", loadDirectory);
  $("mintBtn").addEventListener("click", () => withSigner((c) => c.mint(), "mintMsg"));
  $("saveProfileBtn").addEventListener("click", () => {
    const n = $("profileName").value;
    const b = $("profileBio").value;
    const l = $("profileLink").value;
    if (byteLen(n) > 64) return setMsg("profileMsg", "Name is over 64 bytes.", true);
    if (byteLen(b) > 280) return setMsg("profileMsg", "Bio is over 280 bytes.", true);
    if (byteLen(l) > 128) return setMsg("profileMsg", "Link is over 128 bytes.", true);
    withSigner((c) => c.setProfile(n, b, l), "profileMsg");
  });
  $("attestBtn").addEventListener("click", () => {
    const a = $("attestAddress").value.trim();
    if (!ethers.isAddress(a)) return setMsg("attestMsg", "Enter a valid wallet address.", true);
    withSigner((c) => c.attest(a), "attestMsg");
  });
  $("revokeAttestBtn").addEventListener("click", () => {
    const a = $("attestAddress").value.trim();
    if (!ethers.isAddress(a)) return setMsg("attestMsg", "Enter a valid wallet address.", true);
    withSigner((c) => c.revokeAttestation(a), "attestMsg");
  });

  if (window.ethereum) {
    window.ethereum.on && window.ethereum.on("accountsChanged", (accs) => {
      account = accs && accs[0] ? accs[0] : null;
      $("walletLine").textContent = account ? "Connected: " + account : "Not connected.";
      refreshStatus().catch(console.error);
    });
    window.ethereum.on && window.ethereum.on("chainChanged", () => window.location.reload());
  }

  refreshStatus().catch((e) => {
    console.error(e);
    $("directory").innerHTML = "<p class=\"error\">Could not reach the network: " + escapeHtml(e.message || String(e)) + "</p>";
  });
  loadDirectory().catch(console.error);
}

document.addEventListener("DOMContentLoaded", init);
