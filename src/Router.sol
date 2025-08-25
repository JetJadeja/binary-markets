// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

import { IRouter } from "./interfaces/IRouter.sol";
import { IMarket } from "./interfaces/IMarket.sol";

import { IUniswapV3Factory } from "vendor/v3-core/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "vendor/v3-core/interfaces/IUniswapV3Pool.sol";
import { TickMath } from "vendor/v3-core/libraries/TickMath.sol";
import { INonfungiblePositionManager } from "vendor/v3-periphery/interfaces/INonfungiblePositionManager.sol";

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// @title Router
/// @author Jet Jadeja <jjadeja@usc.edu>
/// @notice Enable direct swaps between collateral and positions via Uniswap V3
contract Router is IRouter {
    using SafeTransferLib for address;

    /// @notice Data passed through swap callbacks
    /// @param tokenA The first token in the market
    /// @param tokenB The second token in the market
    /// @param payer The address that will pay for the swap
    struct SwapCallbackData {
        address tokenA;
        address tokenB;
        address payer;
    }

    /*///////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The market factory contract address
    address public immutable factory;

    /// @notice Collateral token address
    address public immutable collateralToken;

    /// @notice The Uniswap V3 factory contract address
    IUniswapV3Factory public immutable uniswapV3Factory;

    /// @notice The Uniswap V3 position manager for adding liquidity
    INonfungiblePositionManager public immutable positionManager;

    /// @notice Default fee tier for Uniswap V3 pools (500 = 0.05%, lowest tier)
    uint24 public constant DEFAULT_POOL_FEE = 500;

    /*///////////////////////////////////////////////////////////////
                         MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Restricts function access to the factory contract only
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
    /// @param _positionManager The Uniswap V3 position manager address
    constructor(address _factory, address _collateralToken, address _uniswapV3Factory, address _positionManager) {
        factory = _factory;
        collateralToken = _collateralToken;
        uniswapV3Factory = IUniswapV3Factory(_uniswapV3Factory);
        positionManager = INonfungiblePositionManager(_positionManager);
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a new Uniswap V3 pool for a market and adds initial liquidity
    /// @dev Only the factory contract can deploy pools. Expects collateral to be transferred before calling.
    /// @param market The market address for splitting collateral
    /// @param tokenA The address of token A
    /// @param tokenB The address of token B
    /// @param initialLiquidity The amount of collateral to use for initial liquidity
    /// @return pool The address of the deployed pool
    /// @return tokenId The NFT token ID of the liquidity position
    function deployPool(
        address market,
        address tokenA,
        address tokenB,
        uint256 initialLiquidity
    )
        external
        onlyFactory
        returns (address pool, uint256 tokenId)
    {
        // Order tokens as required by Uniswap (token0 < token1)
        (address token0, address token1) = _getTokensOrdered(tokenA, tokenB);

        // Create the pool
        pool = uniswapV3Factory.createPool(token0, token1, DEFAULT_POOL_FEE);

        // Initialize the pool with 1:1 price ratio (equal value for both tokens)
        // sqrtPriceX96 = sqrt(1) * 2^96 = 2^96
        uint160 sqrtPriceX96 = 2 ** 96;
        IUniswapV3Pool(pool).initialize(sqrtPriceX96);

        // Split collateral into equal amounts of position tokens
        IMarket(market).split(initialLiquidity, msg.sender, address(this));

        // Approve position manager to spend both tokens
        token0.safeApprove(address(positionManager), initialLiquidity);
        token1.safeApprove(address(positionManager), initialLiquidity);

        // Calculate tick spacing based on fee tier
        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        // Calculate full range ticks aligned to tick spacing
        int24 tickLower = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 tickUpper = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;

        // Add liquidity to the pool
        (tokenId,,,) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: DEFAULT_POOL_FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: initialLiquidity,
                amount1Desired: initialLiquidity,
                amount0Min: initialLiquidity - 1, // Allow minimal slippage for rounding
                amount1Min: initialLiquidity - 1,
                recipient: msg.sender, // Send LP NFT to factory
                deadline: block.timestamp
            })
        );

        return (pool, tokenId);
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
    {
        // Validate transaction deadline
        require(block.timestamp <= deadline, "Transaction expired");

        // Get position token addresses from market
        (address tokenA, address tokenB) = IMarket(market).getTokens();

        // Pull collateral from user and approve market to spend it
        collateralToken.safeTransferFrom(msg.sender, address(this), amountIn);
        collateralToken.safeApprove(market, amountIn);

        // Split collateral into equal amounts of both position tokens
        IMarket(market).split(amountIn, address(this), address(this));

        // Get the Uniswap V3 pool for these tokens
        address pool = _getPoolAddress(tokenA, tokenB);
        require(pool != address(0), "Pool does not exist");

        // Execute swap to convert unwanted token to desired token
        amountOut = _executeSwap(pool, tokenA, tokenB, buyTokenA, amountIn);

        // Enforce slippage protection
        require(amountOut >= minAmountOut, "Insufficient output amount");

        // Transfer all of the desired token to recipient
        address tokenToBuy = buyTokenA ? tokenA : tokenB;
        tokenToBuy.safeTransfer(recipient, amountOut);

        return amountOut;
    }

    /// @notice Swaps position tokens for collateral tokens through Uniswap V3
    /// @dev Swaps one position for the other via the pool, then merges positions back to collateral
    /// @param market The address of the prediction market
    /// @param sellTokenA True to sell token A, false to sell token B
    /// @param amountIn The amount of position tokens to swap
    /// @param swapAmount The exact amount to swap to balance positions
    /// @param minAmountOut The minimum amount of collateral tokens to receive (slippage protection)
    /// @param recipient The address that will receive the collateral tokens
    /// @param deadline The timestamp after which the transaction will revert
    /// @return amountOut The actual amount of collateral tokens received
    function swapPositionForCollateral(
        address market,
        bool sellTokenA,
        uint256 amountIn,
        uint256 swapAmount,
        uint256 minAmountOut,
        address recipient,
        uint256 deadline
    )
        external
        returns (uint256 amountOut)
    {
        // Validate transaction deadline
        require(block.timestamp <= deadline, "Transaction expired");

        // Validate swap amount doesn't exceed input
        require(swapAmount <= amountIn, "Swap amount exceeds input");

        // Get position token addresses from market
        (address tokenA, address tokenB) = IMarket(market).getTokens();

        // Pull sell tokens from user to router
        {
            address sellToken = sellTokenA ? tokenA : tokenB;
            sellToken.safeTransferFrom(msg.sender, address(this), amountIn);
        }

        // Get the Uniswap V3 pool for these tokens
        address pool = _getPoolAddress(tokenA, tokenB);
        require(pool != address(0), "Pool does not exist");

        uint256 buyTokensReceived;

        if (swapAmount > 0) {
            // Execute swap in a scope to avoid stack too deep
            bool zeroForOne = sellTokenA ? (tokenA < tokenB) : (tokenB < tokenA);
            
            // Execute the swap on Uniswap V3 pool
            (int256 amount0Delta, int256 amount1Delta) = IUniswapV3Pool(pool).swap(
                address(this),
                zeroForOne,
                int256(swapAmount),
                zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                abi.encode(SwapCallbackData({ tokenA: tokenA, tokenB: tokenB, payer: address(this) }))
            );

            // Calculate how many buyTokens we received (negative delta = received)
            buyTokensReceived = uint256(-(zeroForOne ? amount1Delta : amount0Delta));
        }

        // Calculate final balance and merge
        {
            uint256 mergeAmount = amountIn - swapAmount;
            
            // Require exact balance for merge (no partial merges allowed)
            require(mergeAmount == buyTokensReceived, "Unbalanced positions for merge");

            address sellToken = sellTokenA ? tokenA : tokenB;
            address buyToken = sellTokenA ? tokenB : tokenA;

            // Approve market to spend both tokens for merge
            sellToken.safeApprove(market, mergeAmount);
            buyToken.safeApprove(market, mergeAmount);

            // Merge equal positions back to collateral
            amountOut = IMarket(market).merge(mergeAmount, address(this));
        }

        // Enforce slippage protection
        require(amountOut >= minAmountOut, "Insufficient output amount");

        // Transfer collateral to recipient
        collateralToken.safeTransfer(recipient, amountOut);

        return amountOut;
    }

    /*///////////////////////////////////////////////////////////////
                                CALLBACKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function called by Uniswap V3 pools during swaps
    /// @dev Only callable by valid Uniswap V3 pools to request payment for swaps
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive)
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive)
    /// @param data Encoded data containing swap context and parameters
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        // Ensure we owe tokens (positive delta means we owe)
        require(amount0Delta > 0 || amount1Delta > 0, "Invalid callback amounts");

        // Decode callback data to get token information
        SwapCallbackData memory decoded = abi.decode(data, (SwapCallbackData));

        // Verify callback is from the legitimate pool
        address expectedPool = _getPoolAddress(decoded.tokenA, decoded.tokenB);
        require(msg.sender == expectedPool, "Invalid callback caller");

        // Order tokens to match Uniswap's token0/token1
        (address token0, address token1) =
            decoded.tokenA < decoded.tokenB ? (decoded.tokenA, decoded.tokenB) : (decoded.tokenB, decoded.tokenA);

        // Determine which token and amount to pay
        uint256 amountToPay;
        address tokenToPay;
        if (amount0Delta > 0) {
            amountToPay = uint256(amount0Delta);
            tokenToPay = token0;
        } else {
            amountToPay = uint256(amount1Delta);
            tokenToPay = token1;
        }

        // Transfer payment to the pool
        tokenToPay.safeTransfer(msg.sender, amountToPay);
    }

    /*///////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the Uniswap V3 pool address for a pair of tokens
    /// @dev Orders tokens correctly as required by Uniswap
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @return pool The pool address (or address(0) if not exists)
    function _getPoolAddress(address tokenA, address tokenB) internal view returns (address pool) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pool = uniswapV3Factory.getPool(token0, token1, DEFAULT_POOL_FEE);
    }

    /// @notice Executes a swap on the Uniswap V3 pool
    /// @param pool The pool address
    /// @param tokenA Token A address
    /// @param tokenB Token B address
    /// @param buyTokenA Whether to buy token A (true) or token B (false)
    /// @param amountIn The amount to swap
    /// @return totalAmount The total amount of the desired token after swap
    function _executeSwap(
        address pool,
        address tokenA,
        address tokenB,
        bool buyTokenA,
        uint256 amountIn
    )
        internal
        returns (uint256 totalAmount)
    {
        // Determine which token we're selling
        address tokenToSell = buyTokenA ? tokenB : tokenA;
        (address token0,) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bool zeroForOne = tokenToSell == token0;

        // Prepare callback data
        bytes memory swapData = abi.encode(SwapCallbackData({ tokenA: tokenA, tokenB: tokenB, payer: address(this) }));

        // Execute the swap on Uniswap V3 pool
        (int256 amount0Delta, int256 amount1Delta) = IUniswapV3Pool(pool).swap(
            address(this),
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            swapData
        );

        // Calculate total received (negative delta = we received tokens)
        uint256 amountReceived = uint256(-(zeroForOne ? amount1Delta : amount0Delta));
        totalAmount = amountIn + amountReceived;
    }

    /// @notice Orders two tokens as required by Uniswap (token0 < token1)
    /// @param tokenA First token
    /// @param tokenB Second token (can be address(0) if only ordering against tokenA)
    /// @return token0 The lower address
    /// @return token1 The higher address
    function _getTokensOrdered(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /*///////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the Uniswap V3 pool address for a given market
    /// @dev Computes the deterministic pool address for the market's position tokens
    /// @param market The address of the prediction market
    /// @return The address of the Uniswap V3 pool for the market's position tokens
    function getPoolAddress(address market) external view returns (address) {
        // Get the tokens for the market
        (address tokenA, address tokenB) = IMarket(market).getTokens();
        return _getPoolAddress(tokenA, tokenB);
    }
}
