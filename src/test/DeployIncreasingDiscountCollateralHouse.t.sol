pragma solidity ^0.6.7;

import "geb-deploy/test/GebDeploy.t.base.sol";
import "../DeployIncreasingDiscountCollateralHouse.sol";

contract DeployIncreasingDiscountCollateralHouseTest is GebDeployTestBase {
    DeployIncreasingDiscountCollateralHouse deployProxy;

    function setUp() public override {
        super.setUp();
        deployIndex("");
        deployProxy = new DeployIncreasingDiscountCollateralHouse();
    }

    function test_execute() public {
        (address oldAuctionHouseAddress,,) = liquidationEngine.collateralTypes("ETH");

        // deploy the proposal
        address      usr = address(deployProxy);
        bytes32      tag;  assembly { tag := extcodehash(usr) }
        bytes memory fax = abi.encodeWithSignature(
            "execute(address,address,bytes32,address)",
            address(safeEngine),
            address(liquidationEngine),
            bytes32("ETH"),
            address(globalSettlement)
        );
        uint         eta = now;
        pause.scheduleTransaction(usr, tag, fax, eta);
        bytes memory out = pause.executeTransaction(usr, tag, fax, eta);

        (address newAuctionHouseAddress,,) = liquidationEngine.collateralTypes("ETH");
        IncreasingDiscountCollateralAuctionHouse oldAuctionHouse = IncreasingDiscountCollateralAuctionHouse(oldAuctionHouseAddress);
        IncreasingDiscountCollateralAuctionHouse newAuctionHouse = IncreasingDiscountCollateralAuctionHouse(newAuctionHouseAddress);

        assertEq(newAuctionHouseAddress, abi.decode(out, (address)));
        assertEq(liquidationEngine.authorizedAccounts(address(newAuctionHouseAddress)), 1);
        assertEq(liquidationEngine.authorizedAccounts(oldAuctionHouseAddress), 0);
        assertEq(newAuctionHouse.authorizedAccounts(address(liquidationEngine)), 1);
        assertEq(newAuctionHouse.authorizedAccounts(address(globalSettlement)), 1);
        assertEq(address(newAuctionHouse.oracleRelayer()), address(oldAuctionHouse.oracleRelayer()));
        assertEq(address(newAuctionHouse.collateralFSM()), address(oldAuctionHouse.collateralFSM()));
        assertEq(address(newAuctionHouse.systemCoinOracle()), address(oldAuctionHouse.systemCoinOracle()));

        assertEq(newAuctionHouse.authorizedAccounts(address(pause.proxy())), 1);
    }
}
