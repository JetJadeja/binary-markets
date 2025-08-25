// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

/// @title IRouter
/// @notice Interface for enabling direct swaps between collateral and positions via Uniswap V3
interface IRouter {
    /*///////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a new Uniswap V3 pool for a market and adds initial liquidity
    /// @param market The market address for splitting collateral
    /// @param tokenA The address of token A
    /// @param tokenB The address of token B
    /// @param initialLiquidity The amount of collateral to use for initial liquidity
    function deployPool(
        address market,
        address tokenA,
        address tokenB,
        uint256 initialLiquidity
    )
        external
        returns (address pool, uint256 tokenId);

    /// @notice Swaps collateral for a position token
    /// @param market The market address
    /// @param buyTokenA True to buy token A, false to buy token B
    /// @param amountIn The amount of collateral to swap
    /// @param minAmountOut The minimum amount of position tokens to receive
    /// @param recipient The address to receive the position tokens
    /// @param deadline The deadline for the swap
    /// @return amountOut The amount of position tokens received
    function swapCollateralForPosition(
        address market,
        bool buyTokenA,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    )
        external
        returns (uint256 amountOut);

    /// @notice Swaps a position token for collateral
    /// @param market The market address
    /// @param sellTokenA True to sell token A, false to sell token B
    /// @param amountIn The amount of position tokens to swap
    /// @param minAmountOut The minimum amount of collateral to receive
    /// @param recipient The address to receive the collateral
    /// @param deadline The deadline for the swap
    /// @return amountOut The amount of collateral received
    function swapPositionForCollateral(
        address market,
        bool sellTokenA,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    )
        external
        returns (uint256 amountOut);

    /// @notice Swaps one position token for another
    /// @param market The market address
    /// @param amountIn The amount of position tokens to swap
    /// @param minAmountOut The minimum amount of position tokens to receive
    /// @param recipient The address to receive the position tokens
    /// @param deadline The deadline for the swap
    /// @return amountOut The amount of position tokens received
    function swapPositionForPosition(
        address market,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    )
        external
        returns (uint256 amountOut);

    /*///////////////////////////////////////////////////////////////
                                 CALLBACKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback for Uniswap V3 swaps
    /// @param amount0Delta The amount of token0 owed
    /// @param amount1Delta The amount of token1 owed
    /// @param data Callback data
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;

    /*///////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the Uniswap V3 pool address for a market
    /// @param market The market address
    /// @return The pool address
    function getPoolAddress(address market) external view returns (address);

    /// @notice Quotes a swap between position tokens
    /// @param market The market address
    /// @param tokenAToB True for A to B, false for B to A
    /// @param amountIn The amount to swap
    /// @return expectedOut The expected output amount
    /// @return priceImpact The price impact of the swap
    function quote(
        address market,
        bool tokenAToB,
        uint256 amountIn
    )
        external
        view
        returns (uint256 expectedOut, uint256 priceImpact);
}
