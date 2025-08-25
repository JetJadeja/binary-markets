// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

import { IMarket } from "./interfaces/IMarket.sol";
import { PositionToken } from "./PositionToken.sol";

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

/// @title Market
/// @author Jet Jadeja <jjadeja@usc.edu>
/// @notice Handle splitting/merging of collateral into position tokens
contract Market is IMarket {
    /*///////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The collateral token used for this market
    /// @dev This token is split into position tokens and received back when merging
    address public immutable collateralToken;

    /// @notice Position token A representing one side of the market outcome
    address public immutable tokenA;

    /// @notice Position token B representing the other side of the market outcome
    address public immutable tokenB;

    /// @notice The factory contract that deployed this market
    address public immutable factory;

    /// @notice The name of this prediction market
    string public name;

    /*///////////////////////////////////////////////////////////////
                          CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new Market
    /// @param _name The name of the market
    /// @param _collateralToken The collateral token address
    constructor(string memory _name, address _collateralToken) {
        name = _name;
        collateralToken = _collateralToken;
        factory = msg.sender;

        // Deploy position tokens
        tokenA = address(new PositionToken(string.concat(_name, " A"), "TA"));
        tokenB = address(new PositionToken(string.concat(_name, " B"), "TB"));
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Splits collateral into equal amounts of position tokens
    /// @dev Takes collateral from sender and mints equal amounts of tokenA and tokenB to recipient
    /// @param amount The amount of collateral to split
    /// @param recipient The address to receive the position tokens
    /// @param data Callback data to pass to the sender after minting
    /// @return The amount of position tokens minted (equal to collateral amount)
    function split(uint256 amount, address recipient, bytes calldata data) external returns (uint256) {
        // Transfer the collateral to this contract
        SafeTransferLib.safeTransferFrom(collateralToken, msg.sender, address(this), amount);
    }

    /// @notice Merges equal amounts of position tokens back into collateral
    /// @dev Burns equal amounts of tokenA and tokenB from sender and returns collateral to recipient
    /// @param amount The amount of each position token to merge
    /// @param recipient The address to receive the collateral
    /// @param data Callback data to pass to the sender after burning
    /// @return The amount of collateral returned (equal to position token amount)
    function merge(uint256 amount, address recipient, bytes calldata data) external returns (uint256) { }

    /*///////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns both position token addresses
    /// @dev Convenience function to get both token addresses in a single call
    /// @return The addresses of tokenA and tokenB respectively
    function getTokens() external view returns (address, address) {
        return (tokenA, tokenB);
    }
}
