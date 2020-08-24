pragma solidity >=0.6.7;

import "ds-test/test.sol";

import "geb-deploy/test/GebDeploy.t.base.sol";

import {DSValue} from "ds-value/value.sol";

import "../DssAddIlkSpell.sol";

import {OracleLike} from "geb/OracleRelayer.sol";
import {BasicCollateralJoin} from "geb/BasicTokenAdapters.sol";

contract DssAddIlkSpellTest is GebDeployTestBase {
    DssAddIlkSpell spell;

    bytes32 constant ilk = "NCT"; // New Collateral Type
    DSToken     nct;
    BasicCollateralJoin     nctJoin;
    EnglishCollateralAuctionHouse     nctFlip;
    DSValue     nctPip;

    function setUp() public override {
        super.setUp();
        deployStable("");

        nct = new DSToken(ilk);
        nct.mint(1 ether);
        nctJoin = new BasicCollateralJoin(address(cdpEngine), ilk, address(nct));
        nctPip = new DSValue();
        nctPip.updateResult(uint(300 ether));
        nctFlip = englishCollateralAuctionHouseFactory.newCollateralAuctionHouse(address(cdpEngine), ilk);

        
        nctFlip.modifyParameters("osm", address(nctPip));
        nctFlip.modifyParameters("oracleRelayer", address(oracleRelayer));
        nctFlip.modifyParameters("bidDuration", 172800);

        nctFlip.addAuthorization(address(pause.proxy()));
        nctFlip.removeAuthorization(address(this));

        spell = new DssAddIlkSpell(
            ilk,
            address(pause),
            [
                address(cdpEngine),
                address(liquidationEngine),
                address(taxCollector),
                address(oracleRelayer),
                address(globalSettlement),
                address(nctJoin),
                address(nctPip),
                address(nctFlip)
            ],
            [
                10000 * 10 ** 45, // debtCeiling
                1500000000 ether, // safetyCRatio
                // 1500000000 ether, // liquidationCRatio
                1.05 * 10 ** 27, // tax
                ONE, // liquidationPenalty
                10000 ether // lump
            ]
        );

        authority.setRootUser(address(spell), true);

        spell.schedule(); 
        spell.cast();

        nct.approve(address(nctJoin), 1 ether);
    }

    function testVariables() public {
        (,,,uint line,,) = cdpEngine.collateralTypes(ilk);
        assertEq(line, uint(10000 * 10 ** 45));
        (OracleLike pip, uint mat,) = oracleRelayer.collateralTypes(ilk);
        assertEq(address(pip), address(nctPip));
        assertEq(mat, uint(1500000000 ether));
        (uint tax,) = taxCollector.collateralTypes(ilk);
        assertEq(tax, uint(1.05 * 10 ** 27));
        (address flip, uint chop, uint lump) = liquidationEngine.collateralTypes(ilk);
        assertEq(flip, address(nctFlip));
        assertEq(chop, ONE);
        assertEq(lump, uint(10000 ether));
        assertEq(cdpEngine.authorizedAccounts(address(nctJoin)), 1);
    }

    function testFrob() public {
        assertEq(coin.balanceOf(address(this)), 0);
        nctJoin.join(address(this), 1 ether);

        cdpEngine.modifyCDPCollateralization(ilk, address(this), address(this), address(this), 1 ether, 100 ether);

        cdpEngine.approveCDPModification(address(coinJoin));
        coinJoin.exit(address(this), 100 ether);
        assertEq(coin.balanceOf(address(this)), 100 ether);
    }

    function testFlip() public {
        this.modifyParameters(address(liquidationEngine), ilk, "collateralToSell", 1 ether); // 1 unit of collateral per batch
        this.modifyParameters(address(liquidationEngine), ilk, "liquidationPenalty", ONE);
        nctJoin.join(address(this), 1 ether);
        cdpEngine.modifyCDPCollateralization(ilk, address(this), address(this), address(this), 1 ether, 200 ether); // Maximun DAI generated
        nctPip.updateResult(uint(300 ether - 1)); // Decrease price in 1 wei
        oracleRelayer.updateCollateralPrice(ilk);
        assertEq(cdpEngine.tokenCollateral(ilk, address(nctFlip)), 0);
        uint batchId = liquidationEngine.liquidateCDP(ilk, address(this));
        assertEq(cdpEngine.tokenCollateral(ilk, address(nctFlip)), 1 ether);

        address(user1).transfer(10 ether);
        user1.doEthJoin(address(weth), address(ethJoin), address(user1), 10 ether);
        user1.doModifyCDPCollateralization(address(cdpEngine), "ETH", address(user1), address(user1), address(user1), 10 ether, 1000 ether);

        address(user2).transfer(10 ether);
        user2.doEthJoin(address(weth), address(ethJoin), address(user2), 10 ether);
        user2.doModifyCDPCollateralization(address(cdpEngine), "ETH", address(user2), address(user2), address(user2), 10 ether, 1000 ether);

        user1.doCDPApprove(address(cdpEngine), address(nctFlip));
        user2.doCDPApprove(address(cdpEngine), address(nctFlip));

        user1.doIncreaseBidSize(address(nctFlip), batchId, 1 ether, rad(100 ether));
        user2.doIncreaseBidSize(address(nctFlip), batchId, 1 ether, rad(140 ether));
        user1.doIncreaseBidSize(address(nctFlip), batchId, 1 ether, rad(180 ether));
        user2.doIncreaseBidSize(address(nctFlip), batchId, 1 ether, rad(200 ether));

        user1.doDecreaseSoldAmount(address(nctFlip), batchId, 0.8 ether, rad(200 ether));
        user2.doDecreaseSoldAmount(address(nctFlip), batchId, 0.7 ether, rad(200 ether));
        hevm.warp(nctFlip.totalAuctionLength() - 1);
        user1.doDecreaseSoldAmount(address(nctFlip), batchId, 0.6 ether, rad(200 ether));
        hevm.warp(now + nctFlip.totalAuctionLength() + 1);
        user1.doSettleAuction(address(nctFlip), batchId);
    }
}
