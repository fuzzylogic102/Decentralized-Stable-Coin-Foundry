// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Decentralized Stable Coin (DSC)
 * @dev This contract implements an ERC20 token that represents a stablecoin pegged to the USD.
 * It is governed by DSCEngine and has minting and burning functionality.
 * The stablecoin is over-collateralized with exogenous assets like ETH and BTC.
 * 
 * Features:
 * - Exogenous collateral (ETH, BTC)
 * - Algorithmic minting mechanism
 * - Pegged to USD ($1 DSC = $1 USD)
 * - Burnable and Ownable
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {

    // Errors
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance(uint256 balance);
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {
        // Constructor sets the token name and symbol and assigns the contract owner
    }

    /**
     * @notice Burns a specific amount of DSC tokens, reducing total supply.
     * @param _amount The amount of tokens to burn
     */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance(balance);
        }
        // Calls burn function from the ERC20Burnable parent contract
        super.burn(_amount);
    }

    /**
     * @notice Mints new DSC tokens to a specified address.
     * @param _to The recipient address
     * @param _amount The amount of tokens to mint
     * @return bool indicating successful minting
     */
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
