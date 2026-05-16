# Technical Deep Dive: Precision Loss in Scaling Logic

## The Scaling Problem
The `USDai` protocol uses a scaling factor to bridge the gap between its native 18-decimal accounting and the underlying base token's decimals (typically 6 for USDC/USDT on Arbitrum).

`ScaleFactor = 10^(18 - BaseDecimals) = 10^12`

### The Withdrawal Leak
In Solidity, division always truncates toward zero.

$$WithdrawalAmount = \lfloor \frac{USDaiAmount}{10^{12}} \rfloor$$

If $USDaiAmount = 1,999,999,999,999$:
1. $\frac{1,999,999,999,999}{10^{12}} = 1.999999999999$
2. Truncated result = $1$
3. Burned from user = $1,999,999,999,999$
4. Value returned to user = $1,000,000,000,000$
5. **Net Loss = $999,999,999,999$** (approx 1 full unit of base token)

## Comparative Analysis: Deposit vs Withdrawal
*   **Deposit**: `usdaiAmount = _scale(depositAmount)`. This is a multiplication (`depositAmount * 1e12`). There is NO precision loss here because every unit of the base token maps to an exact integer multiple in USDai.
*   **Withdrawal**: `withdrawAmount = _unscale(usdaiAmount)`. This is a division. Because `usdaiAmount` is an 18-decimal value that can be modified by yield accrual or manual transfers, it is frequently NOT a multiple of `1e12`.

## Impact Scenarios
1.  **Yield Accrual**: As `StakedUSDai` accrues yield, the user's balance in `USDai` grows in 18-decimal increments. If they try to withdraw their "entire balance", the fractional part (the dust) will almost certainly be lost.
2.  **Protocol Fees**: If fees are ever calculated in 18 decimals, they will exacerbate the non-alignment of balances.
3.  **Bot Arbitrage**: Sophisticated bots could intentionally trigger these truncations if there were a way to capture the "dust" (currently it is just trapped in the contract or burned).

## Conclusion
The asymmetry between multiplication (deposit) and division (withdrawal) creates a one-way valve where funds enter the protocol with full precision but can only leave in $10^{12}$ increments, with the remainder being effectively destroyed.
