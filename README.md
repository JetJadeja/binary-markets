# Binary Markets

A smart contract system for creating binary prediction markets with integrated AMM trading via Uniswap V3. Split ERC20
collateral into binary outcome tokens and trade them efficiently through a custom router implementation.

## Overview

This project implements a prediction markets infrastructure where users can:

- **Split** collateral tokens into two binary outcome tokens (Token A & Token B) at a 1:1 ratio
- **Merge** equal amounts of both tokens back to recover collateral
- **Trade** position tokens directly for collateral through Uniswap V3 pools
- **Deploy** new markets deterministically using a factory pattern

## Architecture

### Core Contracts

- **`Market.sol`**: Handles split/merge operations, maintaining the invariant that total positions always equal locked
  collateral
- **`PositionToken.sol`**: Minimal ERC20 implementation for binary outcome tokens, mintable only by their parent market
- **`MarketFactory.sol`**: Deploys markets with deterministic addresses using CREATE2, automatically initializing
  Uniswap V3 pools
- **`Router.sol`**: Enables complex swaps between collateral and position tokens through Uniswap V3 integration

## Installation

```bash
# Clone the repository
git clone https://github.com/JetJadeja/binary-markets.git
cd binary-markets

# Install dependencies with Bun
bun install

# Install Foundry dependencies
forge install
```

## Setup

```bash
# Build contracts
bun run build
# or
forge build

# Run tests
forge test

# Run tests with gas reporting
forge test --gas-report

# Format code
forge fmt
```

## Testing

The test suite covers core functionality:

- Market creation through the factory
- Split/merge operations maintaining 1:1 ratios
- AMM swaps via Uniswap V3
- Edge cases like slippage and deadline protection

Run specific tests:

```bash
forge test --match-test testSplitAndMerge
forge test --match-test testSwapCollateralForPosition
```

## Usage Example

```solidity
// Deploy a new prediction market
address market = factory.deployMarket(
    "BTC-100K-2024",      // Market name (used as CREATE2 salt)
    "BTC reaches $100K",  // Token A name
    "BTC below $100K",    // Token B name
    1000e18               // Initial collateral for liquidity
);

// Split collateral into position tokens
Market(market).split(msg.sender, 100e18);

// Swap collateral directly for a position token
router.swapCollateralForPosition(
    market,
    tokenA,        // Desired position token
    100e18,        // Collateral amount
    95e18,         // Minimum output (slippage protection)
    block.timestamp + 3600
);
```

## Technical Stack

- **Solidity 0.8.29**: Fixed version for consistency
- **Foundry**: Development framework and testing
- **Solady**: Gas-optimized library implementations
- **Uniswap V3**: AMM infrastructure for trading
- **Bun**: Fast package manager and task runner

## License

MIT
