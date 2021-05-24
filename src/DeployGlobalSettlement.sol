pragma solidity 0.6.7;

import {GlobalSettlement} from "geb/GlobalSettlement.sol";
import {ESM} from "esm/ESM.sol";
import {ESMThresholdSetter} from "geb-esm-threshold-setter/ESMThresholdSetter.sol";

abstract contract Setter {
    function addAuthorization(address) external virtual;
    function removeAuthorization(address) external virtual;
    function modifyParameters(bytes32,bytes32,address) external virtual;
    function modifyParameters(bytes32,address) external virtual;
}

contract DeployGlobalSettlement {

    function execute(address currentEsm) public returns (address, address, address) {

        // get old GlobalSettlement
        ESM oldEsm = ESM(currentEsm);
        GlobalSettlement oldGlobalSettlement = GlobalSettlement(address(oldEsm.globalSettlement()));

        // getting old GlobalSettlement vars
        address safeEngine = address(oldGlobalSettlement.safeEngine());
        address liquidationEngine = address(oldGlobalSettlement.liquidationEngine());
        address accountingEngine = address(oldGlobalSettlement.accountingEngine());
        address oracleRelayer = address(oldGlobalSettlement.oracleRelayer());
        address coinSavingsAccount = address(oldGlobalSettlement.coinSavingsAccount());
        address stabilityFeeTreasury = address(oldGlobalSettlement.stabilityFeeTreasury());

        // deploy new GlobalSettlement
        GlobalSettlement globalSettlement = new GlobalSettlement();

        // Settings
        globalSettlement.modifyParameters("shutdownCooldown", 345600);
        globalSettlement.modifyParameters("safeEngine", safeEngine);
        globalSettlement.modifyParameters("liquidationEngine", liquidationEngine);
        globalSettlement.modifyParameters("accountingEngine", accountingEngine);
        globalSettlement.modifyParameters("oracleRelayer", oracleRelayer);
        globalSettlement.modifyParameters("coinSavingsAccount", coinSavingsAccount);
        globalSettlement.modifyParameters("stabilityFeeTreasury", stabilityFeeTreasury);

        // Authing new GlobalSettlement
        Setter(safeEngine).addAuthorization(address(globalSettlement));
        Setter(liquidationEngine).addAuthorization(address(globalSettlement));
        Setter(accountingEngine).addAuthorization(address(globalSettlement));
        Setter(oracleRelayer).addAuthorization(address(globalSettlement));
        if (coinSavingsAccount != address(0)) {
          Setter(coinSavingsAccount).addAuthorization(address(globalSettlement));
        }
        if (stabilityFeeTreasury != address(0)) {
          Setter(stabilityFeeTreasury).addAuthorization(address(globalSettlement));
        }

        // Deauthing old GlobalSettlement
        Setter(safeEngine).removeAuthorization(address(oldGlobalSettlement));
        Setter(liquidationEngine).removeAuthorization(address(oldGlobalSettlement));
        Setter(accountingEngine).removeAuthorization(address(oldGlobalSettlement));
        Setter(oracleRelayer).removeAuthorization(address(oldGlobalSettlement));
        if (coinSavingsAccount != address(0)) {
          Setter(coinSavingsAccount).removeAuthorization(address(oldGlobalSettlement));
        }
        if (stabilityFeeTreasury != address(0)) {
          Setter(stabilityFeeTreasury).removeAuthorization(address(oldGlobalSettlement));
        }

        // deploying new threshold setter
        address thresholdSetter = address(new ESMThresholdSetter(
          address(oldEsm.protocolToken()),
          50000 ether, // minAmountToBurn
          100          // 10%, supplyPercentageToBurn
        ));

        // Deploying new ESM
        address esm = address(new ESM(
            address(oldEsm.protocolToken()),
            address(globalSettlement),
            address(oldEsm.tokenBurner()),
            address(thresholdSetter),
            10 ether
        ));
        globalSettlement.addAuthorization(esm);

        Setter(thresholdSetter).modifyParameters("esm", esm);

        return (address(globalSettlement), esm, thresholdSetter);
    }
}

abstract contract GlobalSettlementLike {
    function safeEngine() public virtual returns (address);
    function liquidationEngine() public virtual returns (address);
    function accountingEngine() public virtual returns (address);
    function oracleRelayer() public virtual returns (address);
    function stabilityFeeTreasury() public virtual returns (address);
}

// @notice Swaps auth of a pre deployed Global Settlement with the active one
contract SwapGlobalSettlement {

    function execute(address oldGlobalSettlement, address newGlobalSettlement) public {

        // get old GlobalSettlement
        GlobalSettlementLike oldContract = GlobalSettlementLike(oldGlobalSettlement);

        // getting old GlobalSettlement vars
        address safeEngine = oldContract.safeEngine();
        address liquidationEngine = oldContract.liquidationEngine();
        address accountingEngine = oldContract.accountingEngine();
        address oracleRelayer = oldContract.oracleRelayer();
        address stabilityFeeTreasury = oldContract.stabilityFeeTreasury();

        // Authing new GlobalSettlement
        Setter(safeEngine).addAuthorization(newGlobalSettlement);
        Setter(liquidationEngine).addAuthorization(newGlobalSettlement);
        Setter(accountingEngine).addAuthorization(newGlobalSettlement);
        Setter(oracleRelayer).addAuthorization(newGlobalSettlement);
        Setter(stabilityFeeTreasury).addAuthorization(newGlobalSettlement);

        // Deauthing old GlobalSettlement
        Setter(safeEngine).removeAuthorization(oldGlobalSettlement);
        Setter(liquidationEngine).removeAuthorization(oldGlobalSettlement);
        Setter(accountingEngine).removeAuthorization(oldGlobalSettlement);
        Setter(oracleRelayer).removeAuthorization(oldGlobalSettlement);
        Setter(stabilityFeeTreasury).removeAuthorization(address(oldGlobalSettlement));
    }
}