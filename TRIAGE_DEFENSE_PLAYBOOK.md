# Triage Defense Playbook: Precision Loss Dust Leakage

## 1. Triage Classification
*   **Vulnerability Type**: Precision Loss / Accounting Error
*   **Severity**: Medium (Accumulated Fund Loss)
*   **Impacted Component**: `USDai.sol` -> `_withdraw`

## 2. Evidence of Vulnerability
*   **Location**: `USDai.sol#L254` (Truncation) and `USDai.sol#L241` (Burn).
*   **Arithmetic**: `burn(amount) != transfer(_unscale(amount))`.

## 3. Anticipated Developer Counter-Arguments
*   *"The dust is less than $1.00."*
    *   **Defense**: While the individual loss is small, the **leakage is 100% of the remainder**. For a stablecoin protocol, losing ~$0.99 on a $2.00 withdrawal represents a 50% loss of value, which is critical for retail users.
*   *"The user can just withdraw multiples of 1e12."*
    *   **Defense**: The protocol does not enforce this restriction. If the protocol allows arbitrary `usdaiAmount` inputs, it must handle the remainders correctly. Failing to do so is a direct violation of Pillar I (Mathematical Integrity).

## 4. Developer Masking Analysis
*   **Scaling Assumption**: Developers assumed that because `deposit` scales *up* (multiplication), the reverse scaling *down* (division) would be safe. They failed to account for the "Loss of Precision" rule in Solidity: **Always Multiply Before Dividing**. In this case, the Burn happens *before* the division, effectively charging the user for precision they don't receive.

## 5. Critical Invariants to Monitor
*   **Invariant-01**: `UserBalanceChange == TransferAmount` (adjusted for scaling).
*   **Invariant-02**: `address(this).balance` (or token balance) should never grow due to user withdrawals (which would indicate funds were left behind).
