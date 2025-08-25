// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

import { IMarketFactory } from "./interfaces/IMarketFactory.sol";

import { Market } from "./Market.sol";
import { PositionToken } from "./PositionToken.sol";

import { Ownable } from "solady/auth/Ownable.sol";

/// @title MarketFactory
/// @author Jet Jadeja <jjadeja@usc.edu>
/// @notice Deploy and track prediction markets with deterministic addresses
contract MarketFactory is IMarketFactory, Ownable {
    /*///////////////////////////////////////////////////////////////
                            IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The collateral token used by all markets created by this factory
    /// @dev This token is used as collateral for all prediction markets
    /// @return The address of the collateral token
    address public immutable collateralToken;

    /*///////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the router contract
    address public router;

    /*///////////////////////////////////////////////////////////////
                          CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new MarketFactory
    /// @param _collateralToken The collateral token for all markets
    constructor(address _collateralToken) {
        collateralToken = _collateralToken;

        // Initialize the owner
        _initializeOwner(msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new prediction market with the specified parameters
    /// @dev Deploys a new market contract and its associated position tokens using CREATE2 for deterministic addresses
    /// @param name The name of the market to create
    function createMarket(string calldata name) external returns (address market, address tokenA, address tokenB) {
        // Deploy market using CREATE2
        // Note that if the market already exists, this will revert
        bytes32 salt = keccak256(abi.encodePacked(name));
        market = address(new Market{ salt: salt }(name, collateralToken));

        // Get token addresses
        tokenA = Market(market).tokenA();
        tokenB = Market(market).tokenB();

        // Emit event
        emit MarketCreated(market, tokenA, tokenB, name, msg.sender);
    }

    /// @notice Returns the market address for a given name
    /// @dev Computes the deterministic address using CREATE2 formula without needing storage
    /// @param name The unique name of the market
    /// @return The address of the market (zero if not deployed)
    function getMarket(string memory name) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(name));

        // Compute market address
        bytes memory marketBytecode = abi.encodePacked(type(Market).creationCode, abi.encode(name, collateralToken));
        address market = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(marketBytecode)))))
        );

        // Check if the market actually exists at the computed address
        if (market.code.length == 0) {
            return address(0);
        }

        return market;
    }

    /// @notice Sets the router address
    /// @dev Only the owner can set the router address
    /// @param _router The address of the router contract
    function setRouter(address _router) external onlyOwner {
        router = _router;
    }
}
