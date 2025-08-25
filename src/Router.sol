// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

import { IRouter } from "./interfaces/IRouter.sol";

import { IUniswapV3Factory } from "vendor/v3-core/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "vendor/v3-core/interfaces/IUniswapV3Pool.sol";
import { TickMath } from "vendor/v3-core/libraries/TickMath.sol";

/// @title Router
/// @author Jet Jadeja <jjadeja@usc.edu>
/// @notice Enable direct swaps between collateral and positions via Uniswap V3
contract Router is IRouter {
    /*///////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The market factory contract address
    address public immutable factory;

    /// @notice The Uniswap V3 factory contract address
    IUniswapV3Factory public immutable uniswapV3Factory;

    /*///////////////////////////////////////////////////////////////
                         MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyFactory() {
        if (msg.sender != factory) revert("Caller must be factory");
        _;
    }

    /*///////////////////////////////////////////////////////////////
                          CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new Router
    /// @param _factory The market factory address
    /// @param _uniswapV3Factory The Uniswap V3 factory address
    constructor(address _factory, address _uniswapV3Factory) {
        factory = _factory;
        uniswapV3Factory = IUniswapV3Factory(_uniswapV3Factory);
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a new Uniswap V3 pool for a market
    /// @dev Only the factory contract can deploy pools
    /// @param tokenA The address of token A
    /// @param tokenB The address of token B
    /// @param fee The fee for the pool (e.g., 3000 for 0.3%)
    /// @return pool The address of the deployed pool
    function deployPool(address tokenA, address tokenB, uint24 fee) external onlyFactory returns (address pool) {
        // Order tokens as required by Uniswap (token0 < token1)
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        // Create the pool
        // No need to check if this pool already exists because the factory will revert if it does
        pool = uniswapV3Factory.createPool(token0, token1, fee);

        // Initialize the pool with 1:1 price ratio (equal value for both tokens)
        // sqrtPriceX96 = sqrt(1) * 2^96 = 2^96
        uint160 sqrtPriceX96 = 2 ** 96;
        IUniswapV3Pool(pool).initialize(sqrtPriceX96);

        // Return the pool address
        return pool;
    }

    /// @notice Swaps collateral tokens for position tokens through Uniswap V3
    /// @dev Splits collateral into positions, then swaps one position for the other via the pool
    /// @param market The address of the prediction market
    /// @param buyTokenA True to buy token A, false to buy token B
    /// @param amountIn The amount of collateral tokens to swap
    /// @param minAmountOut The minimum amount of position tokens to receive (slippage protection)
    /// @param recipient The address that will receive the position tokens
    /// @param deadline The timestamp after which the transaction will revert
    /// @return amountOut The actual amount of position tokens received
    function swapCollateralForPosition(
        address market,
        bool buyTokenA,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    )
        external
        returns (uint256 amountOut)
    { }

    /// @notice Swaps position tokens for collateral tokens through Uniswap V3
    /// @dev Swaps one position for the other via the pool, then merges positions back to collateral
    /// @param market The address of the prediction market
    /// @param sellTokenA True to sell token A, false to sell token B
    /// @param amountIn The amount of position tokens to swap
    /// @param minAmountOut The minimum amount of collateral tokens to receive (slippage protection)
    /// @param recipient The address that will receive the collateral tokens
    /// @param deadline The timestamp after which the transaction will revert
    /// @return amountOut The actual amount of collateral tokens received
    function swapPositionForCollateral(
        address market,
        bool sellTokenA,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    )
        external
        returns (uint256 amountOut)
    { }

    /// @notice Swaps one position token for another through Uniswap V3
    /// @dev Direct swap between position tokens via the Uniswap V3 pool
    /// @param market The address of the prediction market
    /// @param amountIn The amount of position tokens to swap
    /// @param minAmountOut The minimum amount of position tokens to receive (slippage protection)
    /// @param recipient The address that will receive the position tokens
    /// @param deadline The timestamp after which the transaction will revert
    /// @return amountOut The actual amount of position tokens received
    function swapPositionForPosition(
        address market,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    )
        external
        returns (uint256 amountOut)
    { }

    /*///////////////////////////////////////////////////////////////
                                CALLBACKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function called by Uniswap V3 pools during swaps
    /// @dev Only callable by valid Uniswap V3 pools to request payment for swaps
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive)
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive)
    /// @param data Encoded data containing swap context and parameters
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external { }

    /*///////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the Uniswap V3 pool address for a given market
    /// @dev Computes the deterministic pool address for the market's position tokens
    /// @param market The address of the prediction market
    /// @return The address of the Uniswap V3 pool for the market's position tokens
    function getPoolAddress(address market) external view returns (address) { }

    /// @notice Quotes the expected output and price impact for a position-to-position swap
    /// @dev Simulates the swap to calculate expected output without executing
    /// @param market The address of the prediction market
    /// @param tokenAToB True to swap token A for token B, false for B to A
    /// @param amountIn The amount of tokens to swap
    /// @return expectedOut The expected amount of tokens to receive
    /// @return priceImpact The estimated price impact of the swap in basis points
    function quote(
        address market,
        bool tokenAToB,
        uint256 amountIn
    )
        external
        view
        returns (uint256 expectedOut, uint256 priceImpact)
    { }
}
