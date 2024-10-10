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

// This contract is designed for testing and interacting with DSCEngine and DSC (Decentralized Stable Coin)
contract ContinueOnRevertHandler is Test {
    // DSCEngine and DecentralizedStableCoin contracts deployed to interact with
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    // Price feed mocks for ETH/USD and BTC/USD
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;
    // Mock ERC20 tokens for WETH and WBTC
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    // Maximum deposit size for collateral
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    // Constructor that initializes the contract with the DSCEngine and DSC instances, fetching mock tokens and price feeds
    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        // Getting the collateral token addresses from the DSCEngine contract
        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        // Fetching the mock price feed addresses for WETH and WBTC from DSCEngine
        ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(wbtc)));
    }

    ///////////////////////
    // Interaction Methods with DSCEngine and DSC //
    ///////////////////////

    /**
     * @dev Mints new collateral tokens and deposits them into the DSCEngine.
     * @param collateralSeed Used to select the type of collateral (WETH or WBTC).
     * @param amountCollateral The amount of collateral to mint and deposit.
     */
    function mintAndDepositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        collateral.mint(msg.sender, amountCollateral);
        dscEngine.depositCollateral(address(collateral), amountCollateral);
    }

    /**
     * @dev Redeems collateral from the DSCEngine.
     * @param collateralSeed Used to select the type of collateral (WETH or WBTC).
     * @param amountCollateral The amount of collateral to redeem.
     */
    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    /**
     * @dev Burns DSC (Decentralized Stable Coin) from the user's balance.
     * @param amountDsc The amount of DSC to burn.
     */
    function burnDsc(uint256 amountDsc) public {
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        dsc.burn(amountDsc);
    }

    /**
     * @dev Mints new DSC (Decentralized Stable Coin) for the user.
     * @param amountDsc The amount of DSC to mint.
     */
    function mintDsc(uint256 amountDsc) public {
        amountDsc = bound(amountDsc, 0, MAX_DEPOSIT_SIZE);
        dsc.mint(msg.sender, amountDsc);
    }

    /**
     * @dev Liquidates a user's collateral to cover their debt.
     * @param collateralSeed Used to select the type of collateral (WETH or WBTC).
     * @param userToBeLiquidated The address of the user to be liquidated.
     * @param debtToCover The amount of debt to cover.
     */
    function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        dscEngine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
    }

    /**
     * @dev Transfers DSC tokens to another user.
     * @param amountDsc The amount of DSC to transfer.
     * @param to The address of the recipient.
     */
    function transferDsc(uint256 amountDsc, address to) public {
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        vm.prank(msg.sender); // Prank sender for testing
        dsc.transfer(to, amountDsc);
    }

    /**
     * @dev Updates the price of the collateral token in the price feed (for testing).
     * @param collateralSeed Used to select the type of collateral (WETH or WBTC).
     */
    function updateCollateralPrice(uint128, /* newPrice */ uint256 collateralSeed) public {
        // In a real case, intNewPrice would be passed, but here it's set to 0 for simplicity.
        int256 intNewPrice = 0;
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        MockV3Aggregator priceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(collateral)));
        priceFeed.updateAnswer(intNewPrice); // Updating price feed for testing
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

    /**
     * @dev Logs the total deposited collateral and the total supply of DSC for debugging purposes.
     */
    function callSummary() external view {
        console.log("Weth total deposited", weth.balanceOf(address(dscEngine)));
        console.log("Wbtc total deposited", wbtc.balanceOf(address(dscEngine)));
        console.log("Total supply of DSC", dsc.totalSupply());
    }
}
