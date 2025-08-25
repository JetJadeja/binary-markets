// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Test } from "forge-std/Test.sol";

import { Market } from "../src/Market.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { PositionToken } from "../src/PositionToken.sol";
import { Router } from "../src/Router.sol";

import { UniswapV3Factory } from "vendor/v3-core/UniswapV3Factory.sol";
import { NonfungiblePositionManager } from "vendor/v3-periphery/NonfungiblePositionManager.sol";
import { SwapRouter } from "vendor/v3-periphery/SwapRouter.sol";

import { ERC20 } from "solady/tokens/ERC20.sol";
import { WETH } from "solady/tokens/WETH.sol";

contract MockERC20 is ERC20 {
    function name() public pure override returns (string memory) {
        return "Mock Token";
    }

    function symbol() public pure override returns (string memory) {
        return "MOCK";
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract BaseTest is Test {
    /*///////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Core contracts
    MarketFactory public factory;
    Market public market;
    PositionToken public tokenA;
    PositionToken public tokenB;
    Router public router;

    // Uniswap V3 contracts
    UniswapV3Factory public uniswapV3Factory;
    NonfungiblePositionManager public nftPositionManager;
    SwapRouter public swapRouter;
    WETH public weth;

    // Mock tokens
    MockERC20 public collateralToken;

    // Test addresses
    address public alice;
    address public bob;
    address public charlie;

    // Test constants
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant MINIMUM_COLLATERAL = 1 ether;
    string public constant MARKET_NAME = "Test Market";

    /*///////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Setup test addresses
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Deploy mock collateral token
        collateralToken = new MockERC20();

        // Deploy Uniswap V3 contracts
        uniswapV3Factory = new UniswapV3Factory();
        weth = new WETH();

        // Deploy Uniswap V3 position manager
        nftPositionManager = new NonfungiblePositionManager(
            address(uniswapV3Factory),
            address(weth),
            address(0) // No descriptor needed for testing
        );

        // Deploy Uniswap V3 swap router
        swapRouter = new SwapRouter(
            address(uniswapV3Factory),
            address(weth)
        );

        // Deploy Router contract
        router = new Router(
            address(factory), // Will be set after factory deployment
            address(collateralToken),
            address(uniswapV3Factory),
            address(nftPositionManager)
        );

        // Deploy factory with router
        factory = new MarketFactory(address(collateralToken), MINIMUM_COLLATERAL);

        // Update router with correct factory address
        router = new Router(
            address(factory),
            address(collateralToken),
            address(uniswapV3Factory),
            address(nftPositionManager)
        );

        // Mint tokens to test addresses
        collateralToken.mint(alice, INITIAL_BALANCE);
        collateralToken.mint(bob, INITIAL_BALANCE);
        collateralToken.mint(charlie, INITIAL_BALANCE);
        collateralToken.mint(address(this), INITIAL_BALANCE);
    }
}
