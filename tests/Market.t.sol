// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { BaseTest } from "./BaseTest.t.sol";
import { Market } from "../src/Market.sol";
import { PositionToken } from "../src/PositionToken.sol";

contract MarketTest is BaseTest {
    function setUp() public override {
        super.setUp();
        
        // Deploy a market directly for testing
        market = new Market(MARKET_NAME, address(collateralToken));
        tokenA = PositionToken(market.tokenA());
        tokenB = PositionToken(market.tokenB());
    }

    /*///////////////////////////////////////////////////////////////
                        CORE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function testSplitMerge() public {
        uint256 splitAmount = 100 ether;
        
        // Alice approves and splits collateral
        vm.startPrank(alice);
        collateralToken.approve(address(market), splitAmount);
        
        uint256 initialCollateralBalance = collateralToken.balanceOf(alice);
        uint256 returnedAmount = market.split(splitAmount, alice, alice);
        
        // Check returned amount
        assertEq(returnedAmount, splitAmount, "Split should return correct amount");
        
        // Check balances after split
        assertEq(tokenA.balanceOf(alice), splitAmount, "Alice should have tokenA");
        assertEq(tokenB.balanceOf(alice), splitAmount, "Alice should have tokenB");
        assertEq(collateralToken.balanceOf(alice), initialCollateralBalance - splitAmount, "Alice should have less collateral");
        assertEq(collateralToken.balanceOf(address(market)), splitAmount, "Market should hold collateral");
        
        // Merge position tokens back
        uint256 mergeAmount = 50 ether;
        uint256 mergeReturned = market.merge(mergeAmount, alice);
        
        // Check returned amount
        assertEq(mergeReturned, mergeAmount, "Merge should return correct amount");
        
        // Check balances after merge
        assertEq(tokenA.balanceOf(alice), splitAmount - mergeAmount, "Alice should have less tokenA");
        assertEq(tokenB.balanceOf(alice), splitAmount - mergeAmount, "Alice should have less tokenB");
        assertEq(collateralToken.balanceOf(alice), initialCollateralBalance - splitAmount + mergeAmount, "Alice should have more collateral");
        assertEq(collateralToken.balanceOf(address(market)), splitAmount - mergeAmount, "Market should hold less collateral");
        
        vm.stopPrank();
    }

    function testSplitMergeMultipleUsers() public {
        uint256 aliceAmount = 100 ether;
        uint256 bobAmount = 50 ether;
        
        // Alice splits
        vm.startPrank(alice);
        collateralToken.approve(address(market), aliceAmount);
        market.split(aliceAmount, alice, alice);
        vm.stopPrank();
        
        // Bob splits
        vm.startPrank(bob);
        collateralToken.approve(address(market), bobAmount);
        market.split(bobAmount, bob, bob);
        vm.stopPrank();
        
        // Check balances
        assertEq(tokenA.balanceOf(alice), aliceAmount, "Alice should have her tokenA");
        assertEq(tokenB.balanceOf(alice), aliceAmount, "Alice should have her tokenB");
        assertEq(tokenA.balanceOf(bob), bobAmount, "Bob should have his tokenA");
        assertEq(tokenB.balanceOf(bob), bobAmount, "Bob should have his tokenB");
        assertEq(collateralToken.balanceOf(address(market)), aliceAmount + bobAmount, "Market should hold all collateral");
        
        // Alice merges half
        vm.startPrank(alice);
        market.merge(aliceAmount / 2, alice);
        vm.stopPrank();
        
        // Bob merges all
        vm.startPrank(bob);
        market.merge(bobAmount, bob);
        vm.stopPrank();
        
        // Check final balances
        assertEq(tokenA.balanceOf(alice), aliceAmount / 2, "Alice should have half tokenA");
        assertEq(tokenB.balanceOf(alice), aliceAmount / 2, "Alice should have half tokenB");
        assertEq(tokenA.balanceOf(bob), 0, "Bob should have no tokenA");
        assertEq(tokenB.balanceOf(bob), 0, "Bob should have no tokenB");
        assertEq(collateralToken.balanceOf(address(market)), aliceAmount / 2, "Market should hold remaining collateral");
    }

    function test_RevertWhen_SplitWithInsufficientBalance() public {
        uint256 splitAmount = INITIAL_BALANCE + 1;
        
        vm.startPrank(alice);
        collateralToken.approve(address(market), splitAmount);
        vm.expectRevert();
        market.split(splitAmount, alice, alice);
        vm.stopPrank();
    }

    function test_RevertWhen_MergeWithUnbalancedPositions() public {
        uint256 splitAmount = 100 ether;
        
        // Alice splits to get position tokens
        vm.startPrank(alice);
        collateralToken.approve(address(market), splitAmount);
        market.split(splitAmount, alice, alice);
        
        // Transfer some tokenA to bob
        tokenA.transfer(bob, 10 ether);
        
        // Try to merge more than the balanced amount (should fail)
        vm.expectRevert();
        market.merge(splitAmount, alice);
        vm.stopPrank();
    }

    function test_RevertWhen_MergeWithInsufficientPositions() public {
        uint256 splitAmount = 100 ether;
        
        // Alice splits
        vm.startPrank(alice);
        collateralToken.approve(address(market), splitAmount);
        market.split(splitAmount, alice, alice);
        
        // Try to merge more than owned
        vm.expectRevert();
        market.merge(splitAmount + 1, alice);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                      CONSERVATION INVARIANT TESTS
    //////////////////////////////////////////////////////////////*/

    function testConservationInvariant() public {
        uint256 aliceAmount = 100 ether;
        uint256 bobAmount = 75 ether;
        uint256 charlieAmount = 50 ether;
        
        // Multiple users split
        vm.startPrank(alice);
        collateralToken.approve(address(market), aliceAmount);
        market.split(aliceAmount, alice, alice);
        vm.stopPrank();
        
        vm.startPrank(bob);
        collateralToken.approve(address(market), bobAmount);
        market.split(bobAmount, bob, bob);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        collateralToken.approve(address(market), charlieAmount);
        market.split(charlieAmount, charlie, charlie);
        vm.stopPrank();
        
        // Check conservation: collateral in market == total supply of each position token
        uint256 totalCollateral = aliceAmount + bobAmount + charlieAmount;
        assertEq(collateralToken.balanceOf(address(market)), totalCollateral, "Market collateral incorrect");
        assertEq(tokenA.totalSupply(), totalCollateral, "TokenA supply incorrect");
        assertEq(tokenB.totalSupply(), totalCollateral, "TokenB supply incorrect");
        
        // Some users merge
        vm.startPrank(alice);
        market.merge(aliceAmount / 2, alice);
        vm.stopPrank();
        
        vm.startPrank(bob);
        market.merge(bobAmount, bob);
        vm.stopPrank();
        
        // Check conservation after merges
        uint256 remainingCollateral = totalCollateral - aliceAmount / 2 - bobAmount;
        assertEq(collateralToken.balanceOf(address(market)), remainingCollateral, "Market collateral incorrect after merge");
        assertEq(tokenA.totalSupply(), remainingCollateral, "TokenA supply incorrect after merge");
        assertEq(tokenB.totalSupply(), remainingCollateral, "TokenB supply incorrect after merge");
    }

    function test_RevertWhen_CreatePositionsWithoutCollateral() public {
        // Try to mint position tokens directly (should fail as Market is the only minter)
        vm.startPrank(alice);
        vm.expectRevert();
        tokenA.mint(alice, 100 ether);
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                          EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testSplitZeroAmount() public {
        vm.startPrank(alice);
        collateralToken.approve(address(market), 0);
        
        // Split zero amount - should succeed but do nothing
        uint256 returned = market.split(0, alice, alice);
        
        assertEq(returned, 0, "Should return 0");
        assertEq(tokenA.balanceOf(alice), 0, "Should have no tokenA");
        assertEq(tokenB.balanceOf(alice), 0, "Should have no tokenB");
        assertEq(collateralToken.balanceOf(address(market)), 0, "Market should have no collateral");
        
        vm.stopPrank();
    }

    function testMergeZeroAmount() public {
        // First split some tokens
        uint256 splitAmount = 100 ether;
        vm.startPrank(alice);
        collateralToken.approve(address(market), splitAmount);
        market.split(splitAmount, alice, alice);
        
        // Merge zero amount - should succeed but do nothing
        uint256 initialCollateral = collateralToken.balanceOf(alice);
        uint256 returned = market.merge(0, alice);
        
        assertEq(returned, 0, "Should return 0");
        assertEq(tokenA.balanceOf(alice), splitAmount, "Should still have all tokenA");
        assertEq(tokenB.balanceOf(alice), splitAmount, "Should still have all tokenB");
        assertEq(collateralToken.balanceOf(alice), initialCollateral, "Collateral should not change");
        
        vm.stopPrank();
    }
}
