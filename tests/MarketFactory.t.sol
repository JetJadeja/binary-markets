// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { BaseTest } from "./BaseTest.t.sol";
import { Market } from "../src/Market.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { PositionToken } from "../src/PositionToken.sol";
import { Router } from "../src/Router.sol";

contract MarketFactoryTest is BaseTest {
    /*///////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        // Set router in factory (as owner)
        factory.setRouter(address(router));
    }

    /*///////////////////////////////////////////////////////////////
                        MARKET CREATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testCreateMarket() public {
        string memory marketName = "ETH-USD-2025";
        uint256 initialCollateral = 10 ether;

        // Give alice collateral for initial liquidity
        vm.startPrank(alice);
        collateralToken.approve(address(factory), initialCollateral);

        // Create market
        (address marketAddr, address tokenA, address tokenB) = factory.createMarket(marketName, initialCollateral);

        // Verify market was created
        assertTrue(marketAddr != address(0), "Market should be created");
        assertTrue(tokenA != address(0), "Token A should be created");
        assertTrue(tokenB != address(0), "Token B should be created");

        // Verify market can be retrieved by name
        assertEq(factory.getMarket(marketName), marketAddr, "Should retrieve market by name");

        // Verify market properties
        Market createdMarket = Market(marketAddr);
        assertEq(createdMarket.collateralToken(), address(collateralToken), "Collateral token should match");
        assertEq(createdMarket.tokenA(), tokenA, "Token A should match");
        assertEq(createdMarket.tokenB(), tokenB, "Token B should match");

        // Verify position tokens
        PositionToken positionA = PositionToken(tokenA);
        PositionToken positionB = PositionToken(tokenB);
        assertEq(positionA.owner(), marketAddr, "Token A market should match");
        assertEq(positionB.owner(), marketAddr, "Token B market should match");

        vm.stopPrank();
    }

    function testCreateMarketDeterministic() public {
        string memory marketName = "BTC-USD-2025";
        uint256 initialCollateral = 10 ether;

        // First creation
        vm.startPrank(alice);
        collateralToken.approve(address(factory), initialCollateral);
        (address market1,,) = factory.createMarket(marketName, initialCollateral);
        vm.stopPrank();

        // Deploy a new factory with same collateral token
        MarketFactory factory2 = new MarketFactory(address(collateralToken), MINIMUM_COLLATERAL);
        Router router2 = new Router(
            address(factory2), address(collateralToken), address(uniswapV3Factory), address(nftPositionManager)
        );
        factory2.setRouter(address(router2));

        // Try to create market with same name from different factory
        vm.startPrank(bob);
        collateralToken.approve(address(factory2), initialCollateral);

        // The addresses should be different because they come from different factories
        (address market2,,) = factory2.createMarket(marketName, initialCollateral);

        assertTrue(market1 != market2, "Markets from different factories should have different addresses");

        // But the same name from same factory should be retrievable
        assertEq(factory.getMarket(marketName), market1, "Should retrieve same market from factory1");
        assertEq(factory2.getMarket(marketName), market2, "Should retrieve same market from factory2");

        vm.stopPrank();
    }

    function testRevertWhenCreateMarketDuplicate() public {
        string memory marketName = "DUPLICATE-MARKET";
        uint256 initialCollateral = 10 ether;

        // First creation should succeed
        vm.startPrank(alice);
        collateralToken.approve(address(factory), initialCollateral * 2);
        factory.createMarket(marketName, initialCollateral);

        // Second creation with same name should fail
        vm.expectRevert();
        factory.createMarket(marketName, initialCollateral);
        vm.stopPrank();
    }

    function testCreateMultipleMarkets() public {
        string[3] memory marketNames = ["MARKET-1", "MARKET-2", "MARKET-3"];
        uint256 initialCollateral = 10 ether;

        address[3] memory markets;
        address[3] memory tokensA;
        address[3] memory tokensB;

        vm.startPrank(alice);
        collateralToken.approve(address(factory), initialCollateral * 3);

        // Create multiple markets
        for (uint256 i = 0; i < marketNames.length; i++) {
            (markets[i], tokensA[i], tokensB[i]) = factory.createMarket(marketNames[i], initialCollateral);
        }

        // Verify all markets are different
        for (uint256 i = 0; i < marketNames.length; i++) {
            for (uint256 j = i + 1; j < marketNames.length; j++) {
                assertTrue(markets[i] != markets[j], "Markets should be unique");
                assertTrue(tokensA[i] != tokensA[j], "Token As should be unique");
                assertTrue(tokensB[i] != tokensB[j], "Token Bs should be unique");
            }
        }

        // Verify all markets can be retrieved
        for (uint256 i = 0; i < marketNames.length; i++) {
            assertEq(factory.getMarket(marketNames[i]), markets[i], "Should retrieve correct market");
        }

        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                    POOL INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testCreateMarketWithInitialLiquidity() public {
        string memory marketName = "LIQUIDITY-TEST";
        uint256 initialCollateral = 100 ether;

        vm.startPrank(alice);
        
        // Alice approves factory to spend her collateral
        collateralToken.approve(address(factory), initialCollateral);
        
        uint256 aliceBalanceBefore = collateralToken.balanceOf(alice);

        // Create market with initial liquidity
        (address marketAddr, address tokenA, address tokenB) = factory.createMarket(marketName, initialCollateral);

        // Verify collateral was transferred from alice
        uint256 aliceBalanceAfter = collateralToken.balanceOf(alice);
        assertEq(aliceBalanceBefore - aliceBalanceAfter, initialCollateral, "Collateral should be transferred from alice");

        // Verify market received collateral (should be held after split)
        assertEq(collateralToken.balanceOf(marketAddr), initialCollateral, "Market should hold collateral");

        // Verify position tokens were created
        PositionToken positionA = PositionToken(tokenA);
        PositionToken positionB = PositionToken(tokenB);

        // Check that total supply exists (tokens were minted for liquidity)
        assertTrue(positionA.totalSupply() > 0, "Token A should have supply");
        assertTrue(positionB.totalSupply() > 0, "Token B should have supply");
        assertEq(positionA.totalSupply(), positionB.totalSupply(), "Token supplies should be equal");
        assertEq(positionA.totalSupply(), initialCollateral, "Token supply should equal initial collateral");

        // Verify Uniswap pool was created
        address pool = router.getPoolAddress(marketAddr);
        assertTrue(pool != address(0), "Uniswap pool should be created");
        
        vm.stopPrank();
    }

    function testRevertWhenCreateMarketInsufficientLiquidity() public {
        string memory marketName = "INSUFFICIENT-LIQUIDITY";
        uint256 insufficientCollateral = MINIMUM_COLLATERAL - 1;

        vm.startPrank(alice);
        collateralToken.approve(address(factory), insufficientCollateral);

        // Should revert when trying to create market with insufficient collateral
        vm.expectRevert("Initial collateral must be greater than minimum");
        factory.createMarket(marketName, insufficientCollateral);

        vm.stopPrank();
    }
    
    function testRevertWhenCreateMarketWithoutApproval() public {
        string memory marketName = "NO-APPROVAL-MARKET";
        uint256 initialCollateral = 10 ether;

        vm.startPrank(alice);
        // Don't approve - should fail
        
        vm.expectRevert();
        factory.createMarket(marketName, initialCollateral);
        
        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                        ROUTER INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testRevertWhenCreateMarketWithoutRouter() public {
        // Deploy new factory without router
        MarketFactory newFactory = new MarketFactory(address(collateralToken), MINIMUM_COLLATERAL);

        string memory marketName = "NO-ROUTER-MARKET";
        uint256 initialCollateral = 10 ether;

        vm.startPrank(alice);
        collateralToken.approve(address(newFactory), initialCollateral);

        // Should revert when router is not set
        vm.expectRevert("Router not set");
        newFactory.createMarket(marketName, initialCollateral);

        vm.stopPrank();
    }

    /*///////////////////////////////////////////////////////////////
                            EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testCreateMarketExactMinimumCollateral() public {
        string memory marketName = "MINIMUM-COLLATERAL-MARKET";
        uint256 initialCollateral = MINIMUM_COLLATERAL;

        vm.startPrank(alice);
        collateralToken.approve(address(factory), initialCollateral);

        // Should succeed with exactly minimum collateral
        (address marketAddr,,) = factory.createMarket(marketName, initialCollateral);

        assertTrue(marketAddr != address(0), "Market should be created with minimum collateral");

        vm.stopPrank();
    }
}
