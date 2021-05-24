pragma solidity ^0.6.7;

import "geb-deploy/test/GebDeploy.t.base.sol";
import "../DeployGlobalSettlement.sol";

contract DeployGlobalSettlementTest is GebDeployTestBase {
    DeployGlobalSettlement deployProxy;

    function setUp() public override {
        super.setUp();
        deployIndex("");
        deployProxy = new DeployGlobalSettlement();
    }

    function test_execute() public {

        ESM oldEsm = esm;
        address oldGlobalSettlement = address(globalSettlement);

        // deploy the proposal
        address      usr = address(deployProxy);
        bytes32      tag;  assembly { tag := extcodehash(usr) }
        bytes memory fax = abi.encodeWithSignature(
            "execute(address)",
            address(esm)
        );
        uint         eta = now;
        pause.scheduleTransaction(usr, tag, fax, eta);
        bytes memory out = pause.executeTransaction(usr, tag, fax, eta);

        (address globalSettlementAddress, address esmAddress, address thresholdSetterAddress) = abi.decode(out, (address,address,address));
        globalSettlement = GlobalSettlement(globalSettlementAddress);
        esm = ESM(esmAddress);
        ESMThresholdSetter thresholdSetter = ESMThresholdSetter(thresholdSetterAddress);

        // settings
        assertEq(address(globalSettlement.safeEngine()), address(safeEngine));
        assertEq(address(globalSettlement.liquidationEngine()), address(liquidationEngine));
        assertEq(address(globalSettlement.accountingEngine()), address(accountingEngine));
        assertEq(address(globalSettlement.oracleRelayer()), address(oracleRelayer));
        assertEq(address(globalSettlement.coinSavingsAccount()), address(coinSavingsAccount));
        assertEq(address(globalSettlement.stabilityFeeTreasury()), address(stabilityFeeTreasury));

        // auth
        assertEq(safeEngine.authorizedAccounts(globalSettlementAddress), 1);
        assertEq(liquidationEngine.authorizedAccounts(globalSettlementAddress), 1);
        assertEq(accountingEngine.authorizedAccounts(globalSettlementAddress), 1);
        assertEq(oracleRelayer.authorizedAccounts(globalSettlementAddress), 1);
        // assertEq(coinSavingsAccount.authorizedAccounts(globalSettlementAddress), 1);
        assertEq(stabilityFeeTreasury.authorizedAccounts(globalSettlementAddress), 1);

        // deauth
        assertEq(safeEngine.authorizedAccounts(oldGlobalSettlement), 0);
        assertEq(liquidationEngine.authorizedAccounts(oldGlobalSettlement), 0);
        assertEq(accountingEngine.authorizedAccounts(oldGlobalSettlement), 0);
        assertEq(oracleRelayer.authorizedAccounts(oldGlobalSettlement), 0);
        // assertEq(coinSavingsAccount.authorizedAccounts(oldGlobalSettlement), 0);
        assertEq(stabilityFeeTreasury.authorizedAccounts(oldGlobalSettlement), 0);

        // ESM
        assertEq(address(esm.protocolToken()), address(prot));
        assertEq(address(esm.globalSettlement()), address(globalSettlement));
        assertEq(address(esm.tokenBurner()), address(oldEsm.tokenBurner()));
        assertEq(address(esm.thresholdSetter()), address(thresholdSetterAddress));
        assertEq(esm.triggerThreshold(), 10 ether);

        // ThresholdSetter
        assertEq(address(thresholdSetter.esm()), address(esm));
        assertEq(address(thresholdSetter.protocolToken()), address(prot));
        assertEq(thresholdSetter.minAmountToBurn(), 50000 ether);
        assertEq(thresholdSetter.supplyPercentageToBurn(), 100);
    }
}

contract SwapGlobalSettlementTest is GebDeployTestBase {
    DeployGlobalSettlement deployProxy;
    SwapGlobalSettlement swapProxy;

    function setUp() public override {
        super.setUp();
        deployIndex("");
        deployProxy = new DeployGlobalSettlement();
        swapProxy = new SwapGlobalSettlement();
    }

    function test_execute() public {

        ESM oldEsm = esm;
        address oldGlobalSettlement = address(globalSettlement);

        // deploy the proposal
        address      usr = address(deployProxy);
        bytes32      tag;  assembly { tag := extcodehash(usr) }
        bytes memory fax = abi.encodeWithSignature(
            "execute(address)",
            address(esm)
        );
        uint         eta = now;
        pause.scheduleTransaction(usr, tag, fax, eta);
        bytes memory out = pause.executeTransaction(usr, tag, fax, eta);

        (address globalSettlementAddress, address esmAddress, address thresholdSetterAddress) = abi.decode(out, (address,address,address));
        globalSettlement = GlobalSettlement(globalSettlementAddress);
        esm = ESM(esmAddress);
        ESMThresholdSetter thresholdSetter = ESMThresholdSetter(thresholdSetterAddress);

        // settings
        assertEq(address(globalSettlement.safeEngine()), address(safeEngine));
        assertEq(address(globalSettlement.liquidationEngine()), address(liquidationEngine));
        assertEq(address(globalSettlement.accountingEngine()), address(accountingEngine));
        assertEq(address(globalSettlement.oracleRelayer()), address(oracleRelayer));
        assertEq(address(globalSettlement.coinSavingsAccount()), address(coinSavingsAccount));
        assertEq(address(globalSettlement.stabilityFeeTreasury()), address(stabilityFeeTreasury));

        // auth
        assertEq(safeEngine.authorizedAccounts(globalSettlementAddress), 1);
        assertEq(liquidationEngine.authorizedAccounts(globalSettlementAddress), 1);
        assertEq(accountingEngine.authorizedAccounts(globalSettlementAddress), 1);
        assertEq(oracleRelayer.authorizedAccounts(globalSettlementAddress), 1);
        // assertEq(coinSavingsAccount.authorizedAccounts(globalSettlementAddress), 1);
        assertEq(stabilityFeeTreasury.authorizedAccounts(globalSettlementAddress), 1);

        // deauth
        assertEq(safeEngine.authorizedAccounts(oldGlobalSettlement), 0);
        assertEq(liquidationEngine.authorizedAccounts(oldGlobalSettlement), 0);
        assertEq(accountingEngine.authorizedAccounts(oldGlobalSettlement), 0);
        assertEq(oracleRelayer.authorizedAccounts(oldGlobalSettlement), 0);
        // assertEq(coinSavingsAccount.authorizedAccounts(oldGlobalSettlement), 0);
        assertEq(stabilityFeeTreasury.authorizedAccounts(oldGlobalSettlement), 0);

        // ESM
        assertEq(address(esm.protocolToken()), address(prot));
        assertEq(address(esm.globalSettlement()), address(globalSettlement));
        assertEq(address(esm.tokenBurner()), address(oldEsm.tokenBurner()));
        assertEq(address(esm.thresholdSetter()), address(thresholdSetterAddress));
        assertEq(esm.triggerThreshold(), 10 ether);

        // ThresholdSetter
        assertEq(address(thresholdSetter.esm()), address(esm));
        assertEq(address(thresholdSetter.protocolToken()), address(prot));
        assertEq(thresholdSetter.minAmountToBurn(), 50000 ether);
        assertEq(thresholdSetter.supplyPercentageToBurn(), 100);

        // Swap proposal, will swap the old one back in
        usr = address(swapProxy);
        assembly { tag := extcodehash(usr) }
        fax = abi.encodeWithSignature(
            "execute(address,address)",
            globalSettlementAddress,
            oldGlobalSettlement
        );
        pause.scheduleTransaction(usr, tag, fax, eta);
        pause.executeTransaction(usr, tag, fax, eta);

        // auth
        assertEq(safeEngine.authorizedAccounts(oldGlobalSettlement), 1);
        assertEq(liquidationEngine.authorizedAccounts(oldGlobalSettlement), 1);
        assertEq(accountingEngine.authorizedAccounts(oldGlobalSettlement), 1);
        assertEq(oracleRelayer.authorizedAccounts(oldGlobalSettlement), 1);
        assertEq(stabilityFeeTreasury.authorizedAccounts(oldGlobalSettlement), 1);

        // deauth
        assertEq(safeEngine.authorizedAccounts(globalSettlementAddress), 0);
        assertEq(liquidationEngine.authorizedAccounts(globalSettlementAddress), 0);
        assertEq(accountingEngine.authorizedAccounts(globalSettlementAddress), 0);
        assertEq(oracleRelayer.authorizedAccounts(globalSettlementAddress), 0);
        assertEq(stabilityFeeTreasury.authorizedAccounts(globalSettlementAddress), 0);
    }
}