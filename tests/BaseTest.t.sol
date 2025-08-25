// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Test } from "forge-std/Test.sol";

import { Market } from "../src/Market.sol";
import { MarketFactory } from "../src/MarketFactory.sol";
import { PositionToken } from "../src/PositionToken.sol";

import { ERC20 } from "solady/tokens/ERC20.sol";

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

        // Deploy factory
        factory = new MarketFactory(address(collateralToken), MINIMUM_COLLATERAL);

        // Mint tokens to test addresses
        collateralToken.mint(alice, INITIAL_BALANCE);
        collateralToken.mint(bob, INITIAL_BALANCE);
        collateralToken.mint(charlie, INITIAL_BALANCE);
        collateralToken.mint(address(this), INITIAL_BALANCE);
    }
}
