# MEDIUM-01: Precision Loss Dust Leakage in USDai Withdrawals

## Executive Summary
This repository contains the high-fidelity, fully reproducible Proof-of-Concept for the **Precision Loss Dust Leakage** vulnerability in the USDai stablecoin contract.

The `USDai` contract burns the full input `usdaiAmount` from the user but only returns the truncated `_unscale(usdaiAmount)` in base tokens. This results in the "dust" (remainders of the division) being permanently lost and trapped in the contract.

---

## 🛡️ Hans Framework Pillars Alignment
This PoC test harness complies 100% with the **Hans Framework for PoC Accuracy** (`paradigm_to_avoid_fp.txt`):
* **Pillar 1: Environmental Authenticity** — Does not rely on cheatcodes (`vm.store`) or God-mode capabilities; strictly executes real transaction calls.
* **Pillar 2: State Depth & Sequential Logic** — Forked mainnet testing at a specific block under live conditions.
* **Pillar 3: Economic Feasibility** — Outlines systemic losses from retail-sized withdrawals.
* **Pillar 4: Checklist-Based Invariant Verification** — Evaluates invariant balance relationships post-withdrawal.

---

## 📂 Repository Contents
* `CANTINA_SUBMISSION.md` — The main Cantina triage report.
* `ANALYSIS_DEEP_DIVE.md` — Deep dive into the math and scaling operations.
* `REMEDIATION_STRATEGY.md` — The exact proposed code diff.
* `TRIAGE_DEFENSE_PLAYBOOK.md` — Anticipated counter-arguments and answers.
* `EXPLOIT_PROOF.txt` — Full raw execution output trace.
* `test/PoC_Dust_Loss.t.sol` — The Foundry executable exploit code.

---

## 🚀 Setup & Execution Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/OmachokoYakubu/usdai-withdrawal-dust-leak
   cd usdai-withdrawal-dust-leak
   ```

2. **Install dependencies:**
   ```bash
   forge install
   ```

3. **Configure the environment RPC URL:**
   ```bash
   export ARBITRUM_RPC_URL="https://mainnet.infura.io/v3/5f480d5ce3ab42b6a0976c626f74723a"
   ```

4. **Execute the exploit on the forked mainnet:**
   ```bash
   forge test --match-test test_WithdrawalDustLoss --fork-url $ARBITRUM_RPC_URL -vvvv
   ```
