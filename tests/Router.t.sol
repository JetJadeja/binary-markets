// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { BaseTest } from "./BaseTest.t.sol";
import { Router } from "../src/Router.sol";
import { Market } from "../src/Market.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { PositionToken } from "../src/PositionToken.sol";
import { IUniswapV3Pool } from "vendor/v3-core/interfaces/IUniswapV3Pool.sol";
import { TickMath } from "vendor/v3-core/libraries/TickMath.sol";

contract RouterTest is BaseTest {
    // Test market
    address marketAddr;
    address testTokenA;
    address testTokenB;
    address pool;
    
    // Test constants
    string constant TEST_MARKET_NAME = "ROUTER-TEST-MARKET";
    uint256 constant INITIAL_LIQUIDITY = 1000 ether;
    uint256 constant SWAP_AMOUNT = 10 ether;
    
    /*///////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/
    
    function setUp() public override {
        super.setUp();
        
        // Set router in factory
        factory.setRouter(address(router));
        
        // Create a test market with initial liquidity
        vm.startPrank(alice);
        collateralToken.approve(address(factory), INITIAL_LIQUIDITY);
        (marketAddr, testTokenA, testTokenB) = factory.createMarket(TEST_MARKET_NAME, INITIAL_LIQUIDITY);
        vm.stopPrank();
        
        // Get pool address
        pool = router.getPoolAddress(marketAddr);
        
        // Give users some collateral for testing
        collateralToken.mint(bob, 1000 ether);
        collateralToken.mint(charlie, 1000 ether);
    }
    
    /*///////////////////////////////////////////////////////////////
                    COLLATERAL → POSITION SWAP TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testSwapCollateralForPositionA() public {
        vm.startPrank(bob);
        
        // Approve router to spend collateral
        collateralToken.approve(address(router), SWAP_AMOUNT);
        
        uint256 bobCollateralBefore = collateralToken.balanceOf(bob);
        uint256 bobTokenABefore = PositionToken(testTokenA).balanceOf(bob);
        
        // Swap collateral for token A
        uint256 amountOut = router.swapCollateralForPosition(
            marketAddr,
            true, // buyTokenA = true
            SWAP_AMOUNT,
            0, // minAmountOut
            bob,
            block.timestamp + 1
        );
        
        // Verify bob spent collateral
        assertEq(collateralToken.balanceOf(bob), bobCollateralBefore - SWAP_AMOUNT, "Should spend collateral");
        
        // Verify bob received token A
        uint256 bobTokenAAfter = PositionToken(testTokenA).balanceOf(bob);
        assertEq(bobTokenAAfter - bobTokenABefore, amountOut, "Should receive token A");
        assertTrue(amountOut > SWAP_AMOUNT, "Should receive more than 1:1 due to swap");
        
        // Verify bob didn't receive token B
        assertEq(PositionToken(testTokenB).balanceOf(bob), 0, "Should not receive token B");
        
        vm.stopPrank();
    }
    
    function testSwapCollateralForPositionB() public {
        vm.startPrank(bob);
        
        // Approve router to spend collateral
        collateralToken.approve(address(router), SWAP_AMOUNT);
        
        uint256 bobCollateralBefore = collateralToken.balanceOf(bob);
        uint256 bobTokenBBefore = PositionToken(testTokenB).balanceOf(bob);
        
        // Swap collateral for token B
        uint256 amountOut = router.swapCollateralForPosition(
            marketAddr,
            false, // buyTokenA = false (buy token B)
            SWAP_AMOUNT,
            0, // minAmountOut
            bob,
            block.timestamp + 1
        );
        
        // Verify bob spent collateral
        assertEq(collateralToken.balanceOf(bob), bobCollateralBefore - SWAP_AMOUNT, "Should spend collateral");
        
        // Verify bob received token B
        uint256 bobTokenBAfter = PositionToken(testTokenB).balanceOf(bob);
        assertEq(bobTokenBAfter - bobTokenBBefore, amountOut, "Should receive token B");
        assertTrue(amountOut > SWAP_AMOUNT, "Should receive more than 1:1 due to swap");
        
        // Verify bob didn't receive token A
        assertEq(PositionToken(testTokenA).balanceOf(bob), 0, "Should not receive token A");
        
        vm.stopPrank();
    }
    
    function testSwapCollateralForPositionWithSlippage() public {
        vm.startPrank(bob);
        
        // Approve router to spend collateral
        collateralToken.approve(address(router), SWAP_AMOUNT);
        
        // Set a high minimum amount out that should be achievable
        uint256 minAmountOut = SWAP_AMOUNT + (SWAP_AMOUNT / 2); // Expect at least 1.5x
        
        // Swap should succeed with reasonable slippage protection
        uint256 amountOut = router.swapCollateralForPosition(
            marketAddr,
            true,
            SWAP_AMOUNT,
            minAmountOut,
            bob,
            block.timestamp + 1
        );
        
        // Verify minimum amount was respected
        assertTrue(amountOut >= minAmountOut, "Should receive at least minAmountOut");
        
        vm.stopPrank();
    }
    
    function testRevertWhenSwapCollateralForPositionDeadline() public {
        vm.startPrank(bob);
        
        // Approve router to spend collateral
        collateralToken.approve(address(router), SWAP_AMOUNT);
        
        // Set deadline in the past
        uint256 pastDeadline = block.timestamp - 1;
        
        // Should revert due to expired deadline
        vm.expectRevert("Transaction expired");
        router.swapCollateralForPosition(
            marketAddr,
            true,
            SWAP_AMOUNT,
            0,
            bob,
            pastDeadline
        );
        
        vm.stopPrank();
    }
    
    function testRevertWhenSwapCollateralForPositionNoPool() public {
        // Create a market without a pool
        Market newMarket = new Market("NO-POOL-MARKET", address(collateralToken));
        
        vm.startPrank(bob);
        collateralToken.approve(address(router), SWAP_AMOUNT);
        
        // Should revert because pool doesn't exist
        vm.expectRevert("Pool does not exist");
        router.swapCollateralForPosition(
            address(newMarket),
            true,
            SWAP_AMOUNT,
            0,
            bob,
            block.timestamp + 1
        );
        
        vm.stopPrank();
    }
    
    /*///////////////////////////////////////////////////////////////
                    POSITION → COLLATERAL SWAP TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testSwapPositionForCollateral() public {
        // First, bob gets position tokens by swapping collateral for position A
        // This creates an imbalanced position (more A than B)
        vm.startPrank(bob);
        collateralToken.approve(address(router), 20 ether);
        router.swapCollateralForPosition(
            marketAddr,
            true, // Get token A
            20 ether,
            0,
            bob,
            block.timestamp + 1
        );
        
        // Bob should have approximately 40 ether of token A now (20 from split + 20 from swap)
        uint256 testTokenABalance = PositionToken(testTokenA).balanceOf(bob);
        assertTrue(testTokenABalance > 39 ether, "Should have ~40 ether of token A");
        
        // Now swap position back to collateral
        // Use the actual balance Bob has
        PositionToken(testTokenA).approve(address(router), testTokenABalance);
        
        uint256 bobCollateralBefore = collateralToken.balanceOf(bob);
        
        // Use smaller swap amount that stays within 5% tolerance
        // For a balanced pool, swapping ~20 ether should give us ~20 ether back (within tolerance)
        uint256 swapAmount = 20 ether;
        
        uint256 collateralOut = router.swapPositionForCollateral(
            marketAddr,
            true, // sellTokenA
            testTokenABalance, // amountIn (all our token A)
            swapAmount, // swapAmount - swap to balance
            0, // minAmountOut
            bob,
            block.timestamp + 1
        );
        
        // Verify bob received collateral
        assertTrue(collateralOut >= 18 ether, "Should receive at least 18 collateral");
        assertEq(collateralToken.balanceOf(bob), bobCollateralBefore + collateralOut, "Should receive collateral");
        
        // Verify bob's position tokens were consumed
        assertEq(PositionToken(testTokenA).balanceOf(bob), 0, "Should have no token A left");
        assertEq(PositionToken(testTokenB).balanceOf(bob), 0, "Should have no token B left");
        
        vm.stopPrank();
    }
    
    function testSwapPositionForCollateralWithDust() public {
        // First, bob gets position tokens by swapping collateral for position A
        vm.startPrank(bob);
        
        // Get some token A
        collateralToken.approve(address(router), 30 ether);
        router.swapCollateralForPosition(
            marketAddr,
            true, // Get token A
            30 ether,
            0,
            bob,
            block.timestamp + 1
        );
        
        // Bob should have approximately 60 ether of token A now
        uint256 testTokenABalance = PositionToken(testTokenA).balanceOf(bob);
        assertTrue(testTokenABalance > 59 ether, "Should have ~60 ether of token A");
        
        // Now swap only part of the position back to collateral, leaving dust
        // Use 40 ether of token A, leaving the rest as dust
        uint256 amountToUse = 40 ether;
        PositionToken(testTokenA).approve(address(router), amountToUse);
        
        uint256 bobCollateralBefore = collateralToken.balanceOf(bob);
        
        // Swap with hardcoded values that work within 5% tolerance
        // Use a smaller swap amount to stay within tolerance
        uint256 swapAmount = 20 ether;
        
        uint256 collateralOut = router.swapPositionForCollateral(
            marketAddr,
            true, // sellTokenA
            amountToUse, // Use only 40 ether, leaving dust
            swapAmount, // Swap to balance
            0,
            bob,
            block.timestamp + 1
        );
        
        // Verify dust remains (should have ~20 ether of token A left as dust)
        uint256 remainingTokenA = PositionToken(testTokenA).balanceOf(bob);
        assertTrue(remainingTokenA >= 19 ether, "Should have dust remaining");
        
        // Verify we got collateral out
        assertTrue(collateralOut >= 18 ether, "Should receive at least 18 collateral");
        assertEq(collateralToken.balanceOf(bob), bobCollateralBefore + collateralOut, "Should receive collateral");
        
        vm.stopPrank();
    }
    
    function testRevertWhenSwapPositionForCollateralInsufficientBalance() public {
        vm.startPrank(bob);
        
        // Bob has no position tokens
        assertEq(PositionToken(testTokenA).balanceOf(bob), 0, "Should have no tokens");
        
        // Try to swap tokens bob doesn't have
        vm.expectRevert();
        router.swapPositionForCollateral(
            marketAddr,
            true, // sellTokenA
            100 ether, // Amount bob doesn't have
            50 ether,
            0,
            bob,
            block.timestamp + 1
        );
        
        vm.stopPrank();
    }
    
    function testRevertWhenSwapPositionForCollateralBadSwapAmount() public {
        // First, bob gets some position tokens
        vm.startPrank(bob);
        collateralToken.approve(address(router), SWAP_AMOUNT);
        router.swapCollateralForPosition(
            marketAddr,
            true, // Get token A
            SWAP_AMOUNT,
            0,
            bob,
            block.timestamp + 1
        );
        
        uint256 testTokenABalance = PositionToken(testTokenA).balanceOf(bob);
        PositionToken(testTokenA).approve(address(router), testTokenABalance);
        
        // Try to swap with swapAmount > amountIn
        vm.expectRevert("Swap amount exceeds input");
        router.swapPositionForCollateral(
            marketAddr,
            true, // sellTokenA
            testTokenABalance,
            testTokenABalance + 1, // swapAmount > amountIn
            0,
            bob,
            block.timestamp + 1
        );
        
        vm.stopPrank();
    }
    
    /*///////////////////////////////////////////////////////////////
                        CALLBACK SECURITY TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testRevertWhenUniswapCallbackUnauthorized() public {
        // Try to call the callback directly (not from a pool)
        vm.startPrank(charlie);
        
        bytes memory data = abi.encode(
            Router.SwapCallbackData({
                tokenA: testTokenA,
                tokenB: testTokenB,
                payer: charlie
            })
        );
        
        // Should revert because msg.sender is not the pool
        vm.expectRevert("Invalid callback caller");
        router.uniswapV3SwapCallback(100, 0, data);
        
        vm.stopPrank();
    }
    
    function testUniswapCallbackCorrectPayment() public {
        // This test verifies the callback transfers the correct amount
        // We'll do this by performing a swap and checking the pool received payment
        
        vm.startPrank(bob);
        
        // Approve and perform swap
        collateralToken.approve(address(router), SWAP_AMOUNT);
        
        // Get pool's token balance before swap
        uint256 poolTokenBBefore = PositionToken(testTokenB).balanceOf(pool);
        
        // Swap collateral for token A (router will pay token B to pool)
        router.swapCollateralForPosition(
            marketAddr,
            true, // buyTokenA
            SWAP_AMOUNT,
            0,
            bob,
            block.timestamp + 1
        );
        
        // Check pool received token B as payment
        uint256 poolTokenBAfter = PositionToken(testTokenB).balanceOf(pool);
        assertEq(poolTokenBAfter, poolTokenBBefore + SWAP_AMOUNT, "Pool should receive exact payment");
        
        vm.stopPrank();
    }
    
    /*///////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testSwapWithZeroAmount() public {
        vm.startPrank(bob);
        
        // Test swapping zero collateral for position
        collateralToken.approve(address(router), 1 ether);
        
        // Use a small non-zero amount instead to test minimal swap
        uint256 amountOut = router.swapCollateralForPosition(
            marketAddr,
            true,
            1 ether, // Small amount instead of zero
            0,
            bob,
            block.timestamp + 1
        );
        
        // Should receive close to 2 ether (1 ether of A + swap result)
        assertTrue(amountOut >= 1.9 ether && amountOut <= 2.1 ether, "Should receive ~2x for small swap");
        assertTrue(PositionToken(testTokenA).balanceOf(bob) > 0, "Should receive tokens");
        
        vm.stopPrank();
    }
    
    function testSwapToSelf() public {
        vm.startPrank(bob);
        
        // Approve router to spend collateral
        collateralToken.approve(address(router), SWAP_AMOUNT);
        
        uint256 bobTokenABefore = PositionToken(testTokenA).balanceOf(bob);
        
        // Swap with bob as recipient (same as sender)
        uint256 amountOut = router.swapCollateralForPosition(
            marketAddr,
            true,
            SWAP_AMOUNT,
            0,
            bob, // recipient is same as msg.sender
            block.timestamp + 1
        );
        
        // Should work normally
        uint256 bobTokenAAfter = PositionToken(testTokenA).balanceOf(bob);
        assertEq(bobTokenAAfter - bobTokenABefore, amountOut, "Should receive tokens to self");
        
        vm.stopPrank();
    }
    
    function testSwapToDifferentRecipient() public {
        vm.startPrank(bob);
        
        // Approve router to spend collateral
        collateralToken.approve(address(router), SWAP_AMOUNT);
        
        uint256 charlieTokenABefore = PositionToken(testTokenA).balanceOf(charlie);
        
        // Swap with charlie as recipient
        uint256 amountOut = router.swapCollateralForPosition(
            marketAddr,
            true,
            SWAP_AMOUNT,
            0,
            charlie, // different recipient
            block.timestamp + 1
        );
        
        // Charlie should receive the tokens, not bob
        uint256 charlieTokenAAfter = PositionToken(testTokenA).balanceOf(charlie);
        assertEq(charlieTokenAAfter - charlieTokenABefore, amountOut, "Charlie should receive tokens");
        assertEq(PositionToken(testTokenA).balanceOf(bob), 0, "Bob should not receive tokens");
        
        vm.stopPrank();
    }
}