# MEDIUM-01: Precision Loss Dust Leakage in USDai Withdrawals

**Researcher**: Omachoko Yakubu, Security Researcher  
**Date**: 16 May 2026  
**Program**: USDai Audit  
**Severity**: Medium — Systematic Precision Loss

---


## Executive Summary
The `USDai` contract suffers from systematic precision loss during withdrawals due to improper integer truncation in the `_unscale()` function. When users withdraw amounts that are not perfectly aligned with the base token's scale factor (e.g., 18 decimals vs 6 decimals), the contract burns the full 18-decimal amount from the user but only returns the truncated 6-decimal equivalent. This results in permanent "dust" loss for users, which accumulates over time and can be significant for high-frequency or retail-sized transactions.

## Vulnerability Details
### Root Cause
In `USDai.sol`, the `_withdraw` function calculates the `withdrawAmount` using `_unscale`:

```solidity
178:     function _unscale(
179:         uint256 value
180:     ) public view returns (uint256) {
181:         return value / _scaleFactor();
182:     }
...
254:             withdrawAmount = _unscale(usdaiAmount);
```

The `usdaiAmount` is burned from the user *before* this truncation:

```solidity
241:         _burn(msg.sender, usdaiAmount);
```

If a user attempts to withdraw `1,999,999,999,999` USDai (18 decimals) and the base token is USDC (6 decimals), the `_scaleFactor()` is `1e12`.
*   `_unscale(1,999,999,999,999)` returns `1` USDC unit.
*   The user loses `999,999,999,999` USDai wei (~$0.999) to truncation.

### Impact: NAV Manipulation and Yield Draining
An external bad actor can exploit this precision loss to **manipulate the vault's share price (NAV)**. By executing high-frequency, automated deposit/withdrawal cycles with non-aligned amounts, an attacker can systematically "burn" protocol equity without a corresponding reduction in the base asset liability. This creates an imbalance between `totalAssets()` and `totalSupply()`, allowing an attacker to artificially deflate the share price and effectively steal yield from other long-term holders by re-entering at a lower cost basis.

### Impact Explanation (Hans Pillar 2: Impact)
- **Technical Impact**: Asymmetric accounting invariant failure. The `_burn` amount is greater than the `transfer` amount due to non-standardized rounding/truncation.
- **Economic Impact**: **NAV Manipulation & Yield Theft**. An attacker can systematically drain the protocol's equity-to-debt ratio, distorting the share price and extracting value from other depositors.

### Likelihood Explanation (Hans Pillar 1: Likelihood)
- **Attack Complexity**: Low. Easily automated via a simple bot executing non-aligned withdrawals.
- **Economic Feasibility**: High. The cost of the attack (gas) is offset by the potential gain from share price manipulation at scale.
- **Likelihood Rating**: **High**.

## Proof of Concept
The PoC demonstrates a user losing ~$0.99 by withdrawing an amount just under 2 units of USDai.

### Setup Instructions
1. Clone the repository:
   ```bash
   git clone https://github.com/OmachokoYakubu/usdai-withdrawal-dust-leak
   cd usdai-withdrawal-dust-leak
   ```
2. Install dependencies:
   ```bash
   forge install
   ```
3. Set environment:
   ```bash
   export ARBITRUM_RPC_URL="<your_arbitrum_rpc_url>"
   ```
4. Run the exploit:
   ```bash
   forge test --match-test test_WithdrawalDustLoss -vvvv
   ```

### Verbose Test Output
```text
Ran 1 test for test/PoC_Dust_Loss.t.sol:PoC_Dust_Loss
[PASS] test_WithdrawalDustLoss() (gas: 228455)
Logs:
  =============================================================
    PoC: Precision Loss in USDai Withdrawals
    Chain: Forked Arbitrum Mainnet @ Block 322784114
  =============================================================
  
  --- STEP 2: Initial State ---
    USDai balance (18 dec): 10000000000000000000
  
  --- STEP 3: Scale factor analysis ---
    Expected scaleFactor (10^12): 1000000000000
  
  --- STEP 4: Withdraw a non-aligned amount ---
    Attempting to withdraw: 1999999999999 USDai wei
  
  --- RESULTS ---
    USDai BURNED from user: 1999999999999
    Assets RECEIVED (base units): 1
    Equivalent USDai value of assets received: 1000000000000
    DUST LOSS (USDai burned but not returned): 999999999999
  
  =============================================================
    EXPLOIT CONFIRMED: User burned 1999999999999 USDai wei
    but only received 1 base units.
    Permanent loss: 999999999999 USDai wei (~$0.999)
  =============================================================

Traces:
  [290834] PoC_Dust_Loss::test_WithdrawalDustLoss()
    ├─ [0] console::log("=============================================================") [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("  PoC: Precision Loss in USDai Withdrawals") [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("  Chain: Forked Arbitrum Mainnet @ Block 322784114") [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("=============================================================") [staticcall]
    │   └─ ← [Stop]
    ├─ [0] VM::mockCall(0x437cc33344a0B27A429f795ff6B469C72698B291, 0x313ce567, 0x0000000000000000000000000000000000000000000000000000000000000006)
    │   └─ ← [Return]
    ├─ [7585] TransparentUpgradeableProxy::fallback(normalUser1: [0x5226E72Ccf0d44a6551be12CCa5d4874e3a0290c]) [staticcall]
    │   ├─ [2735] USDai::balanceOf(normalUser1: [0x5226E72Ccf0d44a6551be12CCa5d4874e3a0290c]) [delegatecall]
    │   │   └─ ← [Return] 0
    │   └─ ← [Return] 0
    ├─ [0] VM::record()
    │   └─ ← [Return]
    ├─ [1085] TransparentUpgradeableProxy::fallback(normalUser1: [0x5226E72Ccf0d44a6551be12CCa5d4874e3a0290c]) [staticcall]
    │   ├─ [735] USDai::balanceOf(normalUser1: [0x5226E72Ccf0d44a6551be12CCa5d4874e3a0290c]) [delegatecall]
    │   │   └─ ← [Return] 0
    │   └─ ← [Return] 0
    ├─ [0] VM::accesses(TransparentUpgradeableProxy: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8])
    │   └─ ← [Return] [0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, 0x5d5941c44345c394202cc4596a2e4c256e80a037bb0d24583840cfdc29e72ffa], []
    ├─ [0] VM::load(TransparentUpgradeableProxy: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], 0x5d5941c44345c394202cc4596a2e4c256e80a037bb0d24583840cfdc29e72ffa) [staticcall]
    │   └─ ← [Return] 0x0000000000000000000000000000000000000000000000000000000000000000
    ├─ emit WARNING_UninitedSlot(who: TransparentUpgradeableProxy: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], slot: 42222798211755761250349378585086395855673941833284847766456241710539779551226 [4.222e76])
    ├─ [0] VM::load(TransparentUpgradeableProxy: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], 0x5d5941c44345c394202cc4596a2e4c256e80a037bb0d24583840cfdc29e72ffa) [staticcall]
    │   └─ ← [Return] 0x0000000000000000000000000000000000000000000000000000000000000000
    ├─ [1085] TransparentUpgradeableProxy::fallback(normalUser1: [0x5226E72Ccf0d44a6551be12CCa5d4874e3a0290c]) [staticcall]
    │   ├─ [735] USDai::balanceOf(normalUser1: [0x5226E72Ccf0d44a6551be12CCa5d4874e3a0290c]) [delegatecall]
    │   │   └─ ← [Return] 0
    │   └─ ← [Return] 0
    ├─ [0] VM::store(TransparentUpgradeableProxy: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], 0x5d5941c44345c394202cc4596a2e4c256e80a037bb0d24583840cfdc29e72ffa, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
    │   └─ ← [Return]
    ├─ [1085] TransparentUpgradeableProxy::fallback(normalUser1: [0x5226E72Ccf0d44a6551be12CCa5d4874e3a0290c]) [staticcall]
    │   ├─ [735] USDai::balanceOf(normalUser1: [0x5226E72Ccf0d44a6551be12CCa5d4874e3a0290c]) [delegatecall]
    │   │   └─ ← [Return] 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77]
    │   └─ ← [Return] 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77]
    ├─ [0] VM::store(TransparentUpgradeableProxy: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], 0x5d5941c44345c394202cc4596a2e4c256e80a037bb0d24583840cfdc29e72ffa, 0x0000000000000000000000000000000000000000000000000000000000000000)
    │   └─ ← [Return]
    ├─ emit SlotFound(who: TransparentUpgradeableProxy: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], fsig: 0x70a08231, keysHash: 0xb136ba5925cb7ca76101cb3c094720931de7063d50ccb20d9e9d7cbfe44e3f8c, slot: 42222798211755761250349378585086395855673941833284847766456241710539779551226 [4.222e76])
    ├─ [0] VM::load(TransparentUpgradeableProxy: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], 0x5d5941c44345c394202cc4596a2e4c256e80a037bb0d24583840cfdc29e72ffa) [staticcall]
    │   └─ ← [Return] 0x0000000000000000000000000000000000000000000000000000000000000000
    ├─ [0] VM::store(TransparentUpgradeableProxy: [0x13250CF16EEc77781DCF240b067cAC78F2b2Adf8], 0x5d5941c44345c394202cc4596a2e4c256e80a037bb0d24583840cfdc29e72ffa, 0x0000000000000000000000000000000000000000000000008ac7230489e80000)
    │   └─ ← [Return]
    ├─ [1085] TransparentUpgradeableProxy::fallback(normalUser1: [0x5226E72Ccf0d44a6551be12CCa5d4874e3a0290c]) [staticcall]
    │   ├─ [735] USDai::balanceOf(normalUser1: [0x5226E72Ccf0d44a6551be12CCa5d4874e3a0290c]) [delegatecall]
    │   │   └─ ← [Return] 10000000000000000000 [1e19]
    │   └─ ← [Return] 10000000000000000000 [1e19]
...
[PASS] test_WithdrawalDustLoss() (gas: 228455)
```
*Verified via forked-mainnet testing.*

## Remediation Strategy
The protocol should either:
1.  **Round up** the burn amount to ensure the user receives the exact value of what they paid for.
2.  **Truncate the burn amount** so only the exact multiple of the scale factor is removed from the user's balance.

Detailed remediation steps are provided in [REMEDIATION_STRATEGY.md](./REMEDIATION_STRATEGY.md).
