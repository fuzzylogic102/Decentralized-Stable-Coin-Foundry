// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { DecentralizedStableCoin } from "../src/DecentralizedStableCoin.sol";
import { DSCEngine } from "../src/DSCEngine.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    /**
     * @dev The main function for deploying the DSC system.
     * @return DecentralizedStableCoin - The deployed stablecoin contract
     * @return DSCEngine - The deployed DSC engine that manages the system
     * @return HelperConfig - The helper configuration that provides network-specific details
     */
    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        // Instantiate the HelperConfig, which sets up the configuration based on the current network.
        // This includes the mocks for testing networks like Hardhat or Anvil.
        HelperConfig helperConfig = new HelperConfig(); 

        // Destructuring assignment to extract token and price feed addresses as well as the deployer's private key.
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) = 
        helperConfig.activeNetworkConfig();
        
        // Setting up token and price feed addresses (e.g., WETH and WBTC with their USD price feeds)
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        // Starting the transaction broadcast with the deployer's private key
        vm.startBroadcast(deployerKey);

        // Deploying the DecentralizedStableCoin contract
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();

        // Deploying the DSCEngine contract with the token and price feed addresses, and linking it to the DSC contract
        DSCEngine dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        // Transferring ownership of the stablecoin contract to the DSCEngine
        dsc.transferOwnership(address(dscEngine));

        // Ending the transaction broadcast
        vm.stopBroadcast();

        // Returning the deployed contracts and the helper configuration for further use
        return (dsc, dscEngine, helperConfig);
    }
}
