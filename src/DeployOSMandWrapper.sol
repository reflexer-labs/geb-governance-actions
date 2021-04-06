pragma solidity 0.6.7;

import {ExternallyFundedOSM} from "geb-fsm/OSM.sol";
import {FSMWrapper} from "geb-fsm/FSMWrapper.sol";

abstract contract LiquidationEngineLike {
    function addAuthorization(address) external virtual;
}

abstract contract StabilityFeeTreasuryLike {
    function setTotalAllowance(address, uint256) external virtual;
    function setPerBlockAllowance(address, uint256) external virtual;
}

abstract contract FsmGovernanceInterfaceLike {
    function setFsm(bytes32, address) external virtual;
}

abstract contract OracleRelayerLike {
    function modifyParameters(bytes32, bytes32, address) external virtual;
}

contract DeployOSMandWrapper {
    // --- Variables ---
    uint256 public constant RAY = 10**27;

    function execute(address _treasury, address ethMedianizer, address fsmGovernanceInterface, address oracleRelayer) public returns (address) {
        // Define params (kovan 1.3)
        StabilityFeeTreasuryLike treasury     = StabilityFeeTreasuryLike(_treasury);
        bytes32 collateralType                = bytes32("ETH-A");
        uint256 reimburseDelay                = 6 hours;
        uint256 maxRewardIncreaseDelay        = 6 hours;
        uint256 baseUpdateCallerReward        = 5 ether;
        uint256 maxUpdateCallerReward         = 10 ether;
        uint256 perSecondCallerRewardIncrease = 1000192559420674483977255848;

        // deploy new OSM
        ExternallyFundedOSM osm = new ExternallyFundedOSM(ethMedianizer);

        // deploy OSM Wrapper
        FSMWrapper osmWrapper = new FSMWrapper(
            address(osm),
            reimburseDelay
        );

        // set the wrapper on the OSM
        osm.modifyParameters("fsmWrapper", address(osmWrapper));

        FsmGovernanceInterfaceLike(fsmGovernanceInterface).setFsm(collateralType, address(osmWrapper));
        OracleRelayerLike(oracleRelayer).modifyParameters(collateralType, "orcl", address(osmWrapper));

        // Setup treasury allowance
        treasury.setTotalAllowance(address(osmWrapper), uint(-1));
        treasury.setPerBlockAllowance(address(osmWrapper), maxUpdateCallerReward * RAY);

        // Set the remaining params
        osmWrapper.modifyParameters("treasury", address(treasury));
        osmWrapper.modifyParameters("maxUpdateCallerReward", maxUpdateCallerReward);
        osmWrapper.modifyParameters("baseUpdateCallerReward", baseUpdateCallerReward);
        osmWrapper.modifyParameters("perSecondCallerRewardIncrease", perSecondCallerRewardIncrease);
        osmWrapper.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay);

        return address(osm);
    }
}
