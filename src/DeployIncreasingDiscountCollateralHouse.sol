pragma solidity 0.6.7;

import {IncreasingDiscountCollateralAuctionHouse} from "geb/CollateralAuctionHouse.sol";

abstract contract LiquidationEngineLike {
    function addAuthorization(address) external virtual;
    function removeAuthorization(address) external virtual;
    function modifyParameters(bytes32,bytes32,address) external virtual;
    function collateralTypes(bytes32) virtual public view returns (
        IncreasingDiscountCollateralAuctionHouse collateralAuctionHouse,
        uint256 liquidationPenalty,     // [wad]
        uint256 liquidationQuantity     // [rad]
    );
}

contract DeployIncreasingDiscountCollateralHouse {
    function execute(address safeEngine, LiquidationEngineLike liquidationEngine, bytes32 collateralType, address globalSettlement) public returns (address) {
        // get old collateral house
        (IncreasingDiscountCollateralAuctionHouse oldCollateralHouse,,) = liquidationEngine.collateralTypes(collateralType);

        // deploy new auction house
        IncreasingDiscountCollateralAuctionHouse auctionHouse =
            new IncreasingDiscountCollateralAuctionHouse(safeEngine, address(liquidationEngine), collateralType);
        // set the new collateral auction house in liquidation engine
        liquidationEngine.modifyParameters(collateralType, "collateralAuctionHouse", address(auctionHouse));
        // Approve the auction house in order to reduce the currentOnAuctionSystemCoins
        liquidationEngine.addAuthorization(address(auctionHouse));
        // Remove the old auction house
        liquidationEngine.removeAuthorization(address(oldCollateralHouse));
        // Internal auth
        auctionHouse.addAuthorization(address(liquidationEngine));
        auctionHouse.addAuthorization(globalSettlement);
        // Oracles
        auctionHouse.modifyParameters("oracleRelayer", address(oldCollateralHouse.oracleRelayer()));
        auctionHouse.modifyParameters("collateralFSM", address(oldCollateralHouse.collateralFSM()));
        auctionHouse.modifyParameters("systemCoinOracle", address(oldCollateralHouse.systemCoinOracle()));

        return address(auctionHouse);
    }
}
