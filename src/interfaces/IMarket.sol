// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

/// @title IMarket
/// @author Jet Jadeja <jjadeja@usc.edu>
/// @notice Interface for handling splitting/merging of collateral into position tokens
interface IMarket {
    /*///////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when collateral is split into position tokens
    /// @param sender The address that initiated the split
    /// @param recipient The address that received the position tokens
    /// @param amount The amount of collateral split
    event Split(address indexed sender, address indexed recipient, uint256 amount);

    /// @notice Emitted when position tokens are merged back into collateral
    /// @param sender The address that initiated the merge
    /// @param recipient The address that received the collateral
    /// @param amount The amount of position tokens merged
    event Merge(address indexed sender, address indexed recipient, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Splits collateral into equal amounts of position tokens
    /// @param amount The amount of collateral to split
    /// @param recipient The address to receive the position tokens
    /// @param data Callback data to pass to the sender
    /// @return The amount of position tokens minted
    function split(uint256 amount, address recipient, bytes calldata data) external returns (uint256);

    /// @notice Merges equal amounts of position tokens back into collateral
    /// @param amount The amount of each position token to merge
    /// @param recipient The address to receive the collateral
    /// @param data Callback data to pass to the sender
    /// @return The amount of collateral returned
    function merge(uint256 amount, address recipient, bytes calldata data) external returns (uint256);

    /*///////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns both position token addresses
    function getTokens() external view returns (address, address);

    /// @notice Returns the collateral token address
    function collateralToken() external view returns (address);

    /// @notice Returns position token A address
    function tokenA() external view returns (address);

    /// @notice Returns position token B address
    function tokenB() external view returns (address);

    /// @notice Returns the factory that deployed this market
    function factory() external view returns (address);

    /// @notice Returns the name of the market
    function name() external view returns (string memory);
}
