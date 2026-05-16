# Remediation Strategy: Precision Loss Dust Leakage

## Vulnerability Overview
The `USDai` contract burns the full input `usdaiAmount` from the user but only returns the truncated `_unscale(usdaiAmount)` in base tokens. This results in the "dust" (remainders of the division) being permanently lost.

## Mitigation Plan

### 1. Adjust Burn to Match Unscaled Amount
The simplest and most correct fix is to only burn what is actually being withdrawn in base token terms.

**Proposed Change:**

```diff
// src/USDai.sol

    function _withdraw(
        address withdrawToken,
        uint256 usdaiAmount,
        uint256 withdrawAmountMinimum,
        address recipient,
        bytes calldata data
    ) internal nonZeroUint(usdaiAmount) nonZeroAddress(recipient) returns (uint256) {
-       /* Burn USD.ai tokens */
-       _burn(msg.sender, usdaiAmount);

        /* If the withdraw token isn't base token, swap out */
        uint256 withdrawAmount;
        if (withdrawToken != address(_baseToken)) {
            uint256 baseTokenAmount = _unscale(usdaiAmount);
+           
+           /* Burn only the equivalent USDai of the unscaled base tokens */
+           _burn(msg.sender, _scale(baseTokenAmount));

            /* Approve the adapter to spend the token in */
            _baseToken.approve(address(_swapAdapter), baseTokenAmount);

            /* Swap base token input for withdraw token */
            withdrawAmount = _swapAdapter.swapOut(withdrawToken, baseTokenAmount, withdrawAmountMinimum, data);
        } else {
            withdrawAmount = _unscale(usdaiAmount);
+           
+           /* Burn only the equivalent USDai of the unscaled base tokens */
+           _burn(msg.sender, _scale(withdrawAmount));
        }

        /* Transfer token output from this contract to the recipient address */
        IERC20(withdrawToken).transfer(recipient, withdrawAmount);
        // ...
    }
```

### 2. Alternative: Enforcement of Aligned Amounts
Add a check that `usdaiAmount % _scaleFactor() == 0` at the beginning of `_withdraw`.

**Pros:**
*   Forces users/integrations to be explicit about precision.
*   Zero risk of unexpected leakage.

**Cons:**
*   Breaks compatibility with some frontend/integrations that might pass raw 18-decimal balances.

## Verification of Fix
After applying the fix, the user in the PoC should only see exactly `1,000,000,000,000` (1 unit) burned from their balance when they receive 1 unit of base token, leaving the "dust" in their wallet.
