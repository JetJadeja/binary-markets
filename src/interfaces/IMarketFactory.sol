// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

/// @title IMarketFactory
/// @notice Interface for deploying and tracking prediction markets with deterministic addresses
interface IMarketFactory {
    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new market is created
    /// @param market The address of the newly created market
    /// @param tokenA The address of position token A
    /// @param tokenB The address of position token B
    /// @param name The name of the market
    /// @param creator The address that created the market
    event MarketCreated(address indexed market, address tokenA, address tokenB, string name, address indexed creator);

    /*///////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// TODO: CHANGE THIS WE MIGHT HAVE A REQUIRED INITIAL LIQUIDITY AMOUNT OR SOMETHING (TBD)
    /// @notice Creates a new prediction market
    /// @param name The name of the market
    /// @return market The address of the deployed market
    /// @return tokenA The address of position token A
    /// @return tokenB The address of position token B
    function createMarket(string calldata name) external returns (address market, address tokenA, address tokenB);

    /// @notice Sets the router address
    /// @dev Only the owner can set the router address
    /// @param _router The address of the router contract
    function setRouter(address _router) external;

    /// @notice Sets the minimum initial collateral amount
    /// @dev Only the owner can set the minimum initial collateral amount
    /// @param _minimumCollateral The minimum initial collateral amount
    function setMinimumCollateral(uint256 _minimumCollateral) external;

    /*///////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the market address for a given name
    /// @param name The name of the market
    /// @return The address of the market (zero if not deployed)
    function getMarket(string memory name) external view returns (address);

    /// @notice Returns the collateral token used by all markets
    /// @return The address of the collateral token
    function collateralToken() external view returns (address);

    /// @notice Returns the router address
    /// @return The address of the router contract
    function router() external view returns (address);

    /// @notice Returns the minimum initial collateral amount
    /// @return The minimum initial collateral amount
    function minimumCollateral() external view returns (uint256);
}
