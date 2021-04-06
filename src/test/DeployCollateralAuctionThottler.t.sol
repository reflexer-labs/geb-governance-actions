pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "geb/SAFEEngine.sol";
import "geb/LiquidationEngine.sol";
import "./mock/MockTreasury.sol";

import "../DeployCollateralAuctionThottler.sol";

contract DeployCollateralAuctionThottlerTest is DSTest {
    DeployCollateralAuctionThottler deployProxy;

    // Main contracts
    DSToken systemCoin;
    SAFEEngine safeEngine;
    LiquidationEngine liquidationEngine;
    MockTreasury treasury;

    function setUp() public {
        systemCoin        = new DSToken("RAI", "RAI");
        safeEngine        = new SAFEEngine();
        liquidationEngine = new LiquidationEngine(address(safeEngine));
        treasury          = new MockTreasury(address(systemCoin));

        deployProxy = new DeployCollateralAuctionThottler();
    }

    function test_execute() public {
        (bool success, bytes memory returnData) =  address(deployProxy).delegatecall(abi.encodeWithSignature(
            "execute(address,address,address)",
            address(safeEngine),
            address(liquidationEngine),
            address(treasury)
        ));
        assertTrue(success);

        CollateralAuctionThrottler throttler = CollateralAuctionThrottler(abi.decode(returnData, (address)));

        // checking throttler deployment
        assertEq(address(throttler.safeEngine()), address(safeEngine));
        assertEq(address(throttler.liquidationEngine()), address(liquidationEngine));
        assertEq(address(throttler.treasury()), address(treasury));

        assertEq(throttler.updateDelay(), 1 weeks);
        assertEq(throttler.backupUpdateDelay(), 8 days);
        assertEq(throttler.globalDebtPercentage(), 20);
        assertEq(throttler.baseUpdateCallerReward(), 0);
        assertEq(throttler.maxUpdateCallerReward(), 10 ether);
        assertEq(throttler.perSecondCallerRewardIncrease(), 10**27);
        assertEq(throttler.maxRewardIncreaseDelay(), 3 hours);
        assertEq(throttler.minAuctionLimit(), 500000 * 10**45);

        // checking allowances
        (uint total, uint perBlock) = treasury.getAllowance(address(throttler));
        assertEq(total, uint(-1));
        assertEq(perBlock, 10 ** 46);

        // checking auth in the throttler itself
        assertEq(throttler.authorizedAccounts(address(this)), 1);
        assertEq(throttler.authorizedAccounts(address(deployProxy)), 0);

        // checking auth in LiquidationEngine
        assertEq(liquidationEngine.authorizedAccounts(address(throttler)), 1);
    }
}
