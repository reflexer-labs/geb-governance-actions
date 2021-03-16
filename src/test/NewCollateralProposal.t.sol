pragma solidity >=0.6.7;

import "ds-test/test.sol";

import "geb-deploy/test/GebDeploy.t.base.sol";

import {DSValue} from "ds-value/value.sol";

import "../NewCollateralProposal.sol";

import {OracleLike} from "geb/OracleRelayer.sol";
import {BasicCollateralJoin} from "geb/BasicTokenAdapters.sol";

contract NewCollateralProposalEnglishAuctionTest is GebDeployTestBase {
    NewCollateralProposal proposal;

    bytes32 constant collateralType = "NCT";
    DSToken nctToken;
    BasicCollateralJoin nctBasicCollateralJoin;
    EnglishCollateralAuctionHouse nctBasicCollateralAuctionHouse;
    DSValue nctOrcl;

    function setUp() public override {
        super.setUp();
        deployStable("");

        nctToken = new DSToken("NCT", "NCT");
        nctToken.mint(1 ether);
        nctBasicCollateralJoin = new BasicCollateralJoin(address(safeEngine), collateralType, address(nctToken));
        nctOrcl = new DSValue();
        nctOrcl.updateResult(uint(300 ether));
        nctBasicCollateralAuctionHouse = englishCollateralAuctionHouseFactory.newCollateralAuctionHouse(address(safeEngine), address(liquidationEngine), collateralType);

        nctBasicCollateralAuctionHouse.modifyParameters("bidDuration", pause.delay());

        nctBasicCollateralAuctionHouse.addAuthorization(address(pause.proxy()));
        nctBasicCollateralAuctionHouse.removeAuthorization(address(this));

        proposal = new NewCollateralProposal(
            collateralType,
            address(pause),
            [
                address(safeEngine),
                address(liquidationEngine),
                address(taxCollector),
                address(oracleRelayer),
                address(globalSettlement),
                address(nctBasicCollateralJoin),
                address(nctOrcl),
                address(nctBasicCollateralAuctionHouse)
            ],
            [
                uint256(10000 * 10 ** 45), // debtCeiling [rad]
                1500000000 ether, // safetyCRatio  [ray]
                1500000000 ether, // liquidationCRatio [ray]
                1.05 * 10 ** 27, // stabilityFee [rad]
                1 ether, // liquidationPenalty [wad]
                10000 * 10 ** 45 // liquidationQuantity [rad]
            ]
        );

        authority.setRootUser(address(proposal), true);

        proposal.scheduleProposal(); 
        proposal.executeProposal();

        nctToken.approve(address(nctBasicCollateralJoin), 1 ether);
    }

    function testVariables() public {
        (,,,uint debtCeiling,,) = safeEngine.collateralTypes(collateralType);
        assertEq(debtCeiling, uint(10000 * 10 ** 45));
        (OracleLike orcl, uint safetyCRatio, uint liquidationCRatio) = oracleRelayer.collateralTypes(collateralType);
        assertEq(address(orcl), address(nctOrcl));
        assertEq(safetyCRatio, uint(1500000000 ether));
        assertEq(liquidationCRatio, uint(1500000000 ether));
        (uint tax,) = taxCollector.collateralTypes(collateralType);
        assertEq(tax, uint(1.05 * 10 ** 27));
        (address auction, uint liquidationPenalty, uint liquidationQuantity) = liquidationEngine.collateralTypes(collateralType);
        assertEq(auction, address(nctBasicCollateralAuctionHouse));
        assertEq(liquidationPenalty, 1 ether);
        assertEq(liquidationQuantity, uint(10000 * 10 ** 45));
        assertEq(safeEngine.authorizedAccounts(address(nctBasicCollateralJoin)), 1);
        assertEq(liquidationEngine.authorizedAccounts(address(nctBasicCollateralAuctionHouse)), 1);
    }

    function testModifySAFECollateralization() public {
        assertEq(coin.balanceOf(address(this)), 0);
        nctBasicCollateralJoin.join(address(this), 1 ether);

        safeEngine.modifySAFECollateralization(collateralType, address(this), address(this), address(this), 1 ether, 100 ether);

        safeEngine.approveSAFEModification(address(coinJoin));
        coinJoin.exit(address(this), 100 ether);
        assertEq(coin.balanceOf(address(this)), 100 ether);
    }

    function testEnglishAuction() public {
        this.modifyParameters(address(liquidationEngine), collateralType, "liquidationQuantity", 10 ** 45); // 1 unit of collateral per batch [rad]
        this.modifyParameters(address(liquidationEngine), collateralType, "liquidationPenalty", 1 ether);

        nctBasicCollateralJoin.join(address(this), 1 ether);
        safeEngine.modifySAFECollateralization(collateralType, address(this), address(this), address(this), 1 ether, 200 ether); // Maximun RAI generated
        nctOrcl.updateResult(uint(300 ether - 1)); // Decrease price in 1 wei
        oracleRelayer.updateCollateralPrice(collateralType);
        assertEq(safeEngine.tokenCollateral(collateralType, address(nctBasicCollateralAuctionHouse)), 0);

        uint batchId = liquidationEngine.liquidateSAFE(collateralType, address(this));
        (,uint amountToSell,,,,,,uint amountToRaise) = nctBasicCollateralAuctionHouse.bids(batchId);
        assertEq(safeEngine.tokenCollateral(collateralType, address(nctBasicCollateralAuctionHouse)), amountToSell);

        address(user1).transfer(10 ether);
        user1.doEthJoin(address(weth), address(ethJoin), address(user1), 10 ether);
        user1.doModifySAFECollateralization(address(safeEngine), "ETH", address(user1), address(user1), address(user1), 10 ether, 1000 ether);

        address(user2).transfer(10 ether);
        user2.doEthJoin(address(weth), address(ethJoin), address(user2), 10 ether);
        user2.doModifySAFECollateralization(address(safeEngine), "ETH", address(user2), address(user2), address(user2), 10 ether, 1000 ether);

        user1.doSAFEApprove(address(safeEngine), address(nctBasicCollateralAuctionHouse));
        user2.doSAFEApprove(address(safeEngine), address(nctBasicCollateralAuctionHouse));

        user1.doIncreaseBidSize(address(nctBasicCollateralAuctionHouse), batchId, amountToSell, rad(0.1 ether));
        user2.doIncreaseBidSize(address(nctBasicCollateralAuctionHouse), batchId, amountToSell, rad(0.2 ether));
        user1.doIncreaseBidSize(address(nctBasicCollateralAuctionHouse), batchId, amountToSell, rad(0.5 ether));
        user2.doIncreaseBidSize(address(nctBasicCollateralAuctionHouse), batchId, amountToSell, rad(1 ether));

        user1.doDecreaseSoldAmount(address(nctBasicCollateralAuctionHouse), batchId, 0.00008 ether, rad(1 ether));
        user2.doDecreaseSoldAmount(address(nctBasicCollateralAuctionHouse), batchId, 0.00007 ether, rad(1 ether));
        hevm.warp(nctBasicCollateralAuctionHouse.totalAuctionLength() - 1);
        user1.doDecreaseSoldAmount(address(nctBasicCollateralAuctionHouse), batchId, 0.00006 ether, rad(1 ether));
        hevm.warp(now + nctBasicCollateralAuctionHouse.totalAuctionLength() + 1);
        user1.doSettleAuction(address(nctBasicCollateralAuctionHouse), batchId);
    }
}

contract NewCollateralProposalFixedDiscountAuctionTest is GebDeployTestBase {
    NewCollateralProposal proposal;

    bytes32 constant collateralType = "NCT";
    DSToken nctToken;
    BasicCollateralJoin nctBasicCollateralJoin;
    FixedDiscountCollateralAuctionHouse nctBasicCollateralAuctionHouse;
    DSValue nctOrcl;

    function setUp() public override {
        super.setUp();
        deployStable("");

        nctToken = new DSToken("NCT", "NCT");
        nctToken.mint(1 ether);
        nctBasicCollateralJoin = new BasicCollateralJoin(address(safeEngine), collateralType, address(nctToken));
        nctOrcl = new DSValue();
        nctOrcl.updateResult(uint(300 ether));
        nctBasicCollateralAuctionHouse = fixedDiscountCollateralAuctionHouseFactory.newCollateralAuctionHouse(address(safeEngine), address(liquidationEngine), collateralType);

        
        nctBasicCollateralAuctionHouse.modifyParameters("minimumBid", 0.01 ether);
        nctBasicCollateralAuctionHouse.modifyParameters("collateralFSM", address(nctOrcl));
        nctBasicCollateralAuctionHouse.modifyParameters("oracleRelayer", address(oracleRelayer));

        nctBasicCollateralAuctionHouse.addAuthorization(address(pause.proxy()));
        nctBasicCollateralAuctionHouse.removeAuthorization(address(this));

        proposal = new NewCollateralProposal(
            collateralType,
            address(pause),
            [
                address(safeEngine),
                address(liquidationEngine),
                address(taxCollector),
                address(oracleRelayer),
                address(globalSettlement),
                address(nctBasicCollateralJoin),
                address(nctOrcl),
                address(nctBasicCollateralAuctionHouse)
            ],
            [
                uint256(10000 * 10 ** 45), // debtCeiling [rad]
                1500000000 ether, // safetyCRatio  [ray]
                1500000000 ether, // liquidationCRatio [ray]
                1.05 * 10 ** 27, // stabilityFee [rad]
                1 ether, // liquidationPenalty [wad]
                10000 * 10 ** 45 // liquidationQuantity [rad]
            ]
        );

        authority.setRootUser(address(proposal), true);

        proposal.scheduleProposal(); 
        proposal.executeProposal();

        nctToken.approve(address(nctBasicCollateralJoin), 1 ether);
    }

    function testVariablesFixedDiscount() public {
        (,,,uint debtCeiling,,) = safeEngine.collateralTypes(collateralType);
        assertEq(debtCeiling, uint(10000 * 10 ** 45));
        (OracleLike orcl, uint safetyCRatio, uint liquidationCRatio) = oracleRelayer.collateralTypes(collateralType);
        assertEq(address(orcl), address(nctOrcl));
        assertEq(safetyCRatio, uint(1500000000 ether));
        assertEq(liquidationCRatio, uint(1500000000 ether));
        (uint tax,) = taxCollector.collateralTypes(collateralType);
        assertEq(tax, uint(1.05 * 10 ** 27));
        (address auction, uint liquidationPenalty, uint liquidationQuantity) = liquidationEngine.collateralTypes(collateralType);
        assertEq(auction, address(nctBasicCollateralAuctionHouse));
        assertEq(liquidationPenalty, 1 ether);
        assertEq(liquidationQuantity, uint(10000 * 10 ** 45));
        assertEq(safeEngine.authorizedAccounts(address(nctBasicCollateralJoin)), 1);
        assertEq(liquidationEngine.authorizedAccounts(address(nctBasicCollateralAuctionHouse)), 1);
    }

    function testModifySAFECollateralization() public {
        assertEq(coin.balanceOf(address(this)), 0);
        nctBasicCollateralJoin.join(address(this), 1 ether);

        safeEngine.modifySAFECollateralization(collateralType, address(this), address(this), address(this), 1 ether, 100 ether);

        safeEngine.approveSAFEModification(address(coinJoin));
        coinJoin.exit(address(this), 100 ether);
        assertEq(coin.balanceOf(address(this)), 100 ether);
    }

    function testFixedDiscountAuction() public {
        this.modifyParameters(address(liquidationEngine), collateralType, "liquidationQuantity", 10 ** 45); // 1 unit of collateral per batch [rad]
        this.modifyParameters(address(liquidationEngine), collateralType, "liquidationPenalty", 1 ether);

        nctBasicCollateralJoin.join(address(this), 1 ether);
        safeEngine.modifySAFECollateralization(collateralType, address(this), address(this), address(this), 1 ether, 200 ether); // Maximun RAI generated
        nctOrcl.updateResult(uint(300 ether - 1)); // Decrease price in 1 wei
        oracleRelayer.updateCollateralPrice(collateralType);
        assertEq(safeEngine.tokenCollateral(collateralType, address(nctBasicCollateralAuctionHouse)), 0);

        uint batchId = liquidationEngine.liquidateSAFE(collateralType, address(this));
        (,,uint amountToSell,uint amountToRaise,,,) = nctBasicCollateralAuctionHouse.bids(batchId);
        assertEq(safeEngine.tokenCollateral(collateralType, address(nctBasicCollateralAuctionHouse)), amountToSell);

        address(user1).transfer(10 ether);
        user1.doEthJoin(address(weth), address(ethJoin), address(user1), 10 ether);
        user1.doModifySAFECollateralization(address(safeEngine), "ETH", address(user1), address(user1), address(user1), 10 ether, 1000 ether);

        address(user2).transfer(10 ether);
        user2.doEthJoin(address(weth), address(ethJoin), address(user2), 10 ether);
        user2.doModifySAFECollateralization(address(safeEngine), "ETH", address(user2), address(user2), address(user2), 10 ether, 1000 ether);

        user1.doSAFEApprove(address(safeEngine), address(nctBasicCollateralAuctionHouse));
        user2.doSAFEApprove(address(safeEngine), address(nctBasicCollateralAuctionHouse));

        user1.doBuyCollateral(address(nctBasicCollateralAuctionHouse), batchId, 0.1 ether);
        user2.doBuyCollateral(address(nctBasicCollateralAuctionHouse), batchId, 0.2 ether);
        user1.doBuyCollateral(address(nctBasicCollateralAuctionHouse), batchId, 0.3 ether);
        user2.doBuyCollateral(address(nctBasicCollateralAuctionHouse), batchId, 3 ether);

        assertEq(nctBasicCollateralAuctionHouse.remainingAmountToSell(batchId), 0);
        assertEq(nctBasicCollateralAuctionHouse.amountToRaise(batchId), 0);
    }
}