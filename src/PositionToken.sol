// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

import { ERC20 } from "solady/tokens/ERC20.sol";

/// @title PositionToken
/// @author binary-markets
/// @notice Minimal ERC20 token representing binary outcome positions
contract PositionToken is ERC20 {
    /*///////////////////////////////////////////////////////////////
                         STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The name of the position token
    /// @dev Stored privately and accessed via name() function
    string private _name;

    /// @notice The symbol of the position token
    /// @dev Stored privately and accessed via symbol() function
    string private _symbol;

    /*///////////////////////////////////////////////////////////////
                          CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new PositionToken
    /// @param name_ The name of the token
    /// @param symbol_ The symbol of the token
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /*///////////////////////////////////////////////////////////////
                         PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name of the token
    /// @dev Overrides the ERC20 name function from Solady
    /// @return The name of the position token
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the token
    /// @dev Overrides the ERC20 symbol function from Solady
    /// @return The symbol of the position token
    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}
