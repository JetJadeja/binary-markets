// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

import { IMarketFactory } from "./interfaces/IMarketFactory.sol";

/// @title MarketFactory
/// @author binary-markets
/// @notice Deploy and track prediction markets with deterministic addresses
contract MarketFactory is IMarketFactory {
    /*///////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The collateral token used by all markets created by this factory
    /// @dev This token is used as collateral for all prediction markets
    /// @return The address of the collateral token
    address public immutable collateralToken;

    /// @notice The router contract address for market interactions
    /// @dev Router handles complex market operations and swaps
    /// @return The address of the router contract
    address public immutable router;

    /*///////////////////////////////////////////////////////////////
                          CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new MarketFactory
    /// @param _collateralToken The collateral token for all markets
    /// @param _router The router contract address
    constructor(address _collateralToken, address _router) {
        collateralToken = _collateralToken;
        router = _router;
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new prediction market with the specified parameters
    /// @dev Deploys a new market contract and its associated position tokens
    /// @param name The name of the market to create
    /// @param initialLiquidity The amount of initial liquidity to provide to the market
    function createMarket(
        string calldata name,
        uint256 initialLiquidity
    )
        external
        returns (address market, address tokenA, address tokenB)
    { }

    /// @notice Returns the market address for a given salt
    /// @dev Retrieves the deployed market address from the markets mapping
    /// @param salt The unique identifier to look up the market
    /// @return The address of the market
    function getMarket(bytes32 salt) external view returns (address) { }
}
