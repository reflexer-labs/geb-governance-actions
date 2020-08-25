pragma solidity >=0.6.7;

import "ds-test/test.sol";

import "geb-deploy/test/GebDeploy.t.base.sol";

import {DSValue} from "ds-value/value.sol";

import "../NewCollateralProposal.sol";

import {OracleLike} from "geb/OracleRelayer.sol";
import {BasicCollateralJoin} from "geb/BasicTokenAdapters.sol";

contract NewCollateralProposalTest is GebDeployTestBase {
    NewCollateralProposal proposal;

    bytes32 constant collateralType = "NCT";
    DSToken nctToken;
    BasicCollateralJoin nctBasicCollateralJoin;
    EnglishCollateralAuctionHouse nctBasicCollateralAuctionHouse;
    DSValue nctOrcl;

    function setUp() public override {
        super.setUp();
        deployStable("");

        nctToken = new DSToken(collateralType);
        nctToken.mint(1 ether);
        nctBasicCollateralJoin = new BasicCollateralJoin(address(cdpEngine), collateralType, address(nctToken));
        nctOrcl = new DSValue();
        nctOrcl.updateResult(uint(300 ether));
        nctBasicCollateralAuctionHouse = englishCollateralAuctionHouseFactory.newCollateralAuctionHouse(address(cdpEngine), collateralType);

        
        nctBasicCollateralAuctionHouse.modifyParameters("osm", address(nctOrcl));
        nctBasicCollateralAuctionHouse.modifyParameters("oracleRelayer", address(oracleRelayer));
        nctBasicCollateralAuctionHouse.modifyParameters("bidDuration", pause.delay());

        nctBasicCollateralAuctionHouse.addAuthorization(address(pause.proxy()));
        nctBasicCollateralAuctionHouse.removeAuthorization(address(this));

        proposal = new NewCollateralProposal(
            collateralType,
            address(pause),
            [
                address(cdpEngine),
                address(liquidationEngine),
                address(taxCollector),
                address(oracleRelayer),
                address(globalSettlement),
                address(nctBasicCollateralJoin),
                address(nctOrcl),
                address(nctBasicCollateralAuctionHouse)
            ],
            [
                10000 * 10 ** 45, // debtCeiling
                1500000000 ether, // safetyCRatio
                1500000000 ether, // liquidationCRatio
                1.05 * 10 ** 27, // stabilityFee
                ONE, // liquidationPenalty
                10000 ether // collateralToSell
            ]
        );

        authority.setRootUser(address(proposal), true);

        proposal.scheduleProposal(); 
        proposal.executeProposal();

        nctToken.approve(address(nctBasicCollateralJoin), 1 ether);
    }

    function testVariables() public {
        (,,,uint collType,,) = cdpEngine.collateralTypes(collateralType);
        assertEq(collType, uint(10000 * 10 ** 45));
        (OracleLike orcl, uint safetyCRatio, uint liquidationCRatio) = oracleRelayer.collateralTypes(collateralType);
        assertEq(address(orcl), address(nctOrcl));
        assertEq(safetyCRatio, uint(1500000000 ether));
        assertEq(liquidationCRatio, uint(1500000000 ether));
        (uint tax,) = taxCollector.collateralTypes(collateralType);
        assertEq(tax, uint(1.05 * 10 ** 27));
        (address auction, uint liquidationPenalty, uint collateralToSell) = liquidationEngine.collateralTypes(collateralType);
        assertEq(auction, address(nctBasicCollateralAuctionHouse));
        assertEq(liquidationPenalty, ONE);
        assertEq(collateralToSell, uint(10000 ether));
        assertEq(cdpEngine.authorizedAccounts(address(nctBasicCollateralJoin)), 1);
    }

    function testModifyCDPCollateralization() public {
        assertEq(coin.balanceOf(address(this)), 0);
        nctBasicCollateralJoin.join(address(this), 1 ether);

        cdpEngine.modifyCDPCollateralization(collateralType, address(this), address(this), address(this), 1 ether, 100 ether);

        cdpEngine.approveCDPModification(address(coinJoin));
        coinJoin.exit(address(this), 100 ether);
        assertEq(coin.balanceOf(address(this)), 100 ether);
    }

    function testAuction() public {
        this.modifyParameters(address(liquidationEngine), collateralType, "collateralToSell", 1 ether); // 1 unit of collateral per batch
        this.modifyParameters(address(liquidationEngine), collateralType, "liquidationPenalty", ONE);
        nctBasicCollateralJoin.join(address(this), 1 ether);
        cdpEngine.modifyCDPCollateralization(collateralType, address(this), address(this), address(this), 1 ether, 200 ether); // Maximun RAI generated
        nctOrcl.updateResult(uint(300 ether - 1)); // Decrease price in 1 wei
        oracleRelayer.updateCollateralPrice(collateralType);
        assertEq(cdpEngine.tokenCollateral(collateralType, address(nctBasicCollateralAuctionHouse)), 0);
        uint batchId = liquidationEngine.liquidateCDP(collateralType, address(this));
        assertEq(cdpEngine.tokenCollateral(collateralType, address(nctBasicCollateralAuctionHouse)), 1 ether);

        address(user1).transfer(10 ether);
        user1.doEthJoin(address(weth), address(ethJoin), address(user1), 10 ether);
        user1.doModifyCDPCollateralization(address(cdpEngine), "ETH", address(user1), address(user1), address(user1), 10 ether, 1000 ether);

        address(user2).transfer(10 ether);
        user2.doEthJoin(address(weth), address(ethJoin), address(user2), 10 ether);
        user2.doModifyCDPCollateralization(address(cdpEngine), "ETH", address(user2), address(user2), address(user2), 10 ether, 1000 ether);

        user1.doCDPApprove(address(cdpEngine), address(nctBasicCollateralAuctionHouse));
        user2.doCDPApprove(address(cdpEngine), address(nctBasicCollateralAuctionHouse));

        user1.doIncreaseBidSize(address(nctBasicCollateralAuctionHouse), batchId, 1 ether, rad(100 ether));
        user2.doIncreaseBidSize(address(nctBasicCollateralAuctionHouse), batchId, 1 ether, rad(140 ether));
        user1.doIncreaseBidSize(address(nctBasicCollateralAuctionHouse), batchId, 1 ether, rad(180 ether));
        user2.doIncreaseBidSize(address(nctBasicCollateralAuctionHouse), batchId, 1 ether, rad(200 ether));

        user1.doDecreaseSoldAmount(address(nctBasicCollateralAuctionHouse), batchId, 0.8 ether, rad(200 ether));
        user2.doDecreaseSoldAmount(address(nctBasicCollateralAuctionHouse), batchId, 0.7 ether, rad(200 ether));
        hevm.warp(nctBasicCollateralAuctionHouse.totalAuctionLength() - 1);
        user1.doDecreaseSoldAmount(address(nctBasicCollateralAuctionHouse), batchId, 0.6 ether, rad(200 ether));
        hevm.warp(now + nctBasicCollateralAuctionHouse.totalAuctionLength() + 1);
        user1.doSettleAuction(address(nctBasicCollateralAuctionHouse), batchId);
    }
}
