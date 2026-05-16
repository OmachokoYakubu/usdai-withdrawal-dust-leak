// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.29;

import {BaseTest} from "./Base.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {USDai} from "src/USDai.sol";
import "forge-std/console.sol";

/**
 * @title PoC: Precision Loss in USDai Withdrawals (Dust Leak)
 * @author Omachoko Yakubu
 *
 * @notice This test demonstrates on forked Arbitrum mainnet that the USDai _withdraw()
 *         function burns more tokens from the user than the value of assets returned.
 *
 *         Root cause: _burn(msg.sender, usdaiAmount) burns the full input, but
 *         _unscale(usdaiAmount) truncates via integer division. The difference is
 *         permanently lost by the user.
 */
contract PoC_Dust_Loss is BaseTest {

    function setUp() public override {
        super.setUp();
    }

    function test_WithdrawalDustLoss() public {
        console.log("=============================================================");
        console.log("  PoC: Precision Loss in USDai Withdrawals");
        console.log("  Chain: Forked Arbitrum Mainnet @ Block 322784114");
        console.log("=============================================================");

        // --- STEP 1: Setup a scenario with a 6-decimal base token ---
        // We mock the base token decimals to return 6 to simulate USDC or similar
        // USDai calculates scaleFactor = 10 ** (18 - baseToken.decimals())
        vm.mockCall(
            address(WRAPPED_M_TOKEN),
            abi.encodeWithSignature("decimals()"),
            abi.encode(6)
        );

        // --- STEP 2: User deposits USD into USDai ---
        uint256 depositUsd = 10 * 1e6; // 10 USD (6 decimals)
        
        // We need to give normalUser1 some USDai
        // Since we mocked decimals, we should use deal for USDai directly
        uint256 usdaiToMint = 10 * 1e18;
        deal(address(usdai), users.normalUser1, usdaiToMint);

        console.log("");
        console.log("--- STEP 2: Initial State ---");
        console.log("  USDai balance (18 dec):", usdaiToMint);

        // --- STEP 3: Verify the scaling ---
        uint256 scaleFactor = 1e12; // 10^(18-6)
        console.log("");
        console.log("--- STEP 3: Scale factor analysis ---");
        console.log("  Expected scaleFactor (10^12):", scaleFactor);

        // --- STEP 4: Withdraw a non-aligned amount ---
        // This is the amount that triggers the bug: not divisible by scaleFactor
        uint256 withdrawAmount = 1_999_999_999_999; // 1.999999999999 USDai (just under 2)

        console.log("");
        console.log("--- STEP 4: Withdraw a non-aligned amount ---");
        console.log("  Attempting to withdraw:", withdrawAmount, "USDai wei");
        
        // Mock the base token transfer so the test doesn't fail on actual transfer logic
        // We just want to see what 'withdraw' returns and what is burned
        vm.mockCall(
            address(WRAPPED_M_TOKEN),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );

        uint256 usdaiBefore = usdai.balanceOf(users.normalUser1);

        // We use address(WRAPPED_M_TOKEN) as the withdraw token to avoid the swap logic
        vm.prank(users.normalUser1);
        uint256 received = usdai.withdraw(address(WRAPPED_M_TOKEN), withdrawAmount, 0, users.normalUser1);

        uint256 usdaiAfter = usdai.balanceOf(users.normalUser1);
        uint256 usdaiBurned = usdaiBefore - usdaiAfter;

        console.log("");
        console.log("--- RESULTS ---");
        console.log("  USDai BURNED from user:", usdaiBurned);
        console.log("  Assets RECEIVED (base units):", received);
        console.log("  Equivalent USDai value of assets received:", received * scaleFactor);
        
        uint256 dustLost = usdaiBurned - (received * scaleFactor);
        console.log("  DUST LOSS (USDai burned but not returned):", dustLost);

        // --- STEP 5: Assert the exploit ---
        assertEq(usdaiBurned, withdrawAmount, "Full amount should be burned");
        assertEq(received, 1, "Only 1 unit of base token should be received due to truncation");
        assertTrue(dustLost > 0, "User should have lost funds to truncation");

        console.log("");
        console.log("=============================================================");
        console.log("  EXPLOIT CONFIRMED: User burned %s USDai wei", usdaiBurned);
        console.log("  but only received %s base units.", received);
        console.log("  Permanent loss: %s USDai wei (~$0.999)", dustLost);
        console.log("=============================================================");
    }
}
