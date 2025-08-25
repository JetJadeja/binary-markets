// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

import { IMarketFactory } from "./interfaces/IMarketFactory.sol";
import { IRouter } from "./interfaces/IRouter.sol";

import { Market } from "./Market.sol";
import { PositionToken } from "./PositionToken.sol";

import { Ownable } from "solady/auth/Ownable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// @title MarketFactory
/// @author Jet Jadeja <jjadeja@usc.edu>
/// @notice Deploy and track prediction markets with deterministic addresses
contract MarketFactory is IMarketFactory, Ownable {
    using SafeTransferLib for address;

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

    /// @notice Minimum initial collateral amount for a market
    uint256 public minimumCollateral;

    /*///////////////////////////////////////////////////////////////
                          CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new MarketFactory
    /// @param _collateralToken The collateral token for all markets
    constructor(address _collateralToken, uint256 _minimumCollateral) {
        collateralToken = _collateralToken;
        minimumCollateral = _minimumCollateral;

        // Initialize the owner
        _initializeOwner(msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new prediction market with the specified parameters
    /// @dev Deploys a new market contract and its associated position tokens using CREATE2 for deterministic addresses
    /// @param name The name of the market to create
    /// @param initialCollateral The initial collateral amount for the market
    function createMarket(
        string calldata name,
        uint256 initialCollateral
    )
        external
        returns (address market, address tokenA, address tokenB)
    {
        // Check if the initial collateral amount is greater than the minimum collateral amount
        require(initialCollateral >= minimumCollateral, "Initial collateral must be greater than minimum");

        // Check that router is set
        require(router != address(0), "Router not set");

        // Deploy market using CREATE2
        // Note that if the market already exists, this will revert
        bytes32 salt = keccak256(abi.encodePacked(name));
        market = address(new Market{ salt: salt }(name, collateralToken));

        // Get token addresses
        tokenA = Market(market).tokenA();
        tokenB = Market(market).tokenB();

        // Approve market to spend collateral
        collateralToken.safeApprove(market, initialCollateral);

        // Deploy Uniswap V3 pool and add initial liquidity
        IRouter(router).deployPool(market, tokenA, tokenB, initialCollateral);

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

    /// @notice Sets the minimum initial collateral amount
    /// @dev Only the owner can set the minimum initial collateral amount
    /// @param _minimumCollateral The minimum initial collateral amount
    function setMinimumCollateral(uint256 _minimumCollateral) external onlyOwner {
        minimumCollateral = _minimumCollateral;
    }
}
