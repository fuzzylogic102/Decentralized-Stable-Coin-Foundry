// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// Importing libraries and dependencies from OpenZeppelin and Foundry
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Test } from "forge-std/Test.sol";
// Importing the mock ERC20 token contract for local testing
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
// Importing the mock Chainlink price feed aggregator contract for local testing
import { MockV3Aggregator } from "../../mocks/MockV3Aggregator.sol";
// Importing DSCEngine and DecentralizedStableCoin from the project's source
import { DSCEngine, AggregatorV3Interface } from "../../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../../src/DecentralizedStableCoin.sol";
// Importing the console for logging during local testing
import { console } from "forge-std/console.sol";

// The StopOnRevertHandler contract interacts with DSCEngine and DSC contracts, and it stops execution if an error occurs
contract StopOnRevertHandler is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Deployed contracts to interact with
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    // Constant variable for the maximum amount of collateral deposit
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    /**
     * @dev Constructor to initialize the contract with DSCEngine and DSC instances.
     * It fetches the WETH and WBTC tokens and price feeds from the DSCEngine.
     * @param _dscEngine The DSCEngine contract.
     * @param _dsc The DecentralizedStableCoin contract.
     */
    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        // Getting the collateral tokens (WETH and WBTC) from DSCEngine
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        // Fetching the price feed addresses for ETH/USD and BTC/USD
        ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(wbtc)));
    }

    ///////////////
    // DSCEngine //
    ///////////////

    /**
     * @dev Mints new collateral and deposits it into the DSCEngine.
     * @param collateralSeed Seed to choose between WETH and WBTC.
     * @param amountCollateral The amount of collateral to mint and deposit.
     */
    function mintAndDepositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        // Ensure the amount of collateral is greater than zero
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        // Start a new transaction using vm.prank for msg.sender
        vm.startPrank(msg.sender);
        // Mint the collateral for msg.sender and approve DSCEngine to spend it
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscEngine), amountCollateral);
        // Deposit the collateral into DSCEngine
        dscEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    /**
     * @dev Redeems collateral from DSCEngine.
     * @param collateralSeed Seed to choose between WETH and WBTC.
     * @param amountCollateral The amount of collateral to redeem.
     */
    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        // Get the maximum redeemable amount of collateral for the user
        uint256 maxCollateral = dscEngine.getCollateralBalanceOfUser(msg.sender, address(collateral));

        amountCollateral = bound(amountCollateral, 0, maxCollateral);
        // If the amount to redeem is 0, return early
        if (amountCollateral == 0) {
            return;
        }
        // Redeem the collateral using vm.prank for msg.sender
        vm.prank(msg.sender);
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    /**
     * @dev Burns DSC (Decentralized Stable Coin) for the user.
     * @param amountDsc The amount of DSC to burn.
     */
    function burnDsc(uint256 amountDsc) public {
        // Ensure the amount to burn is greater than zero
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        if (amountDsc == 0) {
            return;
        }
        // Burn the DSC using vm.prank for msg.sender
        vm.startPrank(msg.sender);
        dsc.approve(address(dscEngine), amountDsc);
        dscEngine.burnDsc(amountDsc);
        vm.stopPrank();
    }

    /**
     * @dev Liquidates the collateral of a user to cover their debt if their health factor is below the minimum.
     * @param collateralSeed Seed to choose between WETH and WBTC.
     * @param userToBeLiquidated The address of the user to be liquidated.
     * @param debtToCover The amount of debt to cover during liquidation.
     */
    function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
        // Check if the user can be liquidated (health factor below minimum)
        uint256 minHealthFactor = dscEngine.getMinHealthFactor();
        uint256 userHealthFactor = dscEngine.getHealthFactor(userToBeLiquidated);
        if (userHealthFactor >= minHealthFactor) {
            return;
        }
        // Bound the amount of debt to cover and liquidate the user's collateral
        debtToCover = bound(debtToCover, 1, uint256(type(uint96).max));
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        dscEngine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
    }

    /////////////////////////////
    // DecentralizedStableCoin //
    /////////////////////////////

    /**
     * @dev Transfers DSC (Decentralized Stable Coin) to another address.
     * @param amountDsc The amount of DSC to transfer.
     * @param to The recipient address (if zero, it's replaced with address(1)).
     */
    function transferDsc(uint256 amountDsc, address to) public {
        // Ensure the recipient is not the zero address (replace it with address(1))
        if (to == address(0)) {
            to = address(1);
        }
        // Bound the transfer amount and execute the transfer using vm.prank for msg.sender
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        vm.prank(msg.sender);
        dsc.transfer(to, amountDsc);
    }

    /////////////////////////////
    // Aggregator //
    /////////////////////////////

    /**
     * @dev Updates the price of the collateral in the price feed.
     * @param newPrice The new price to set for the collateral.
     * @param collateralSeed Seed to choose between WETH and WBTC.
     */
    function updateCollateralPrice(uint96 newPrice, uint256 collateralSeed) public {
        // Convert the new price to an integer and update the price feed
        int256 intNewPrice = int256(uint256(newPrice));
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        MockV3Aggregator priceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(collateral)));

        // Update the price feed with the new price
        priceFeed.updateAnswer(intNewPrice);
    }

    ///////////////////
    // Helper Functions //
    ///////////////////

    /**
     * @dev Helper function to get the correct collateral token (WETH or WBTC) based on the seed value.
     * @param collateralSeed A seed value used to pick between WETH and WBTC.
     * @return The selected collateral token (WETH or WBTC).
     */
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth; // Return WETH if seed is even
        } else {
            return wbtc; // Return WBTC if seed is odd
        }
    }
}
