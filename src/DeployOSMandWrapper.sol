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

// @notice Proposal to deploy and setup new OSM and wrapper
// missing steps for upgrade (to allow for testing before commiting to the deployment)
// - change orcl for the collateral in oracleRelayer
// - change collateralFSM in collateralAuctionHouse
contract DeployOSMandWrapper {
    // --- Variables ---
    uint256 public constant RAY = 10**27;

    function execute(address _treasury, address ethMedianizer, address fsmGovernanceInterface) public returns (address) {
        // Define params (kovan 1.3)
        StabilityFeeTreasuryLike treasury     = StabilityFeeTreasuryLike(_treasury);
        bytes32 collateralType                = bytes32("ETH-A");
        uint256 reimburseDelay                = 3600;
        uint256 maxRewardIncreaseDelay        = 10800;
        uint256 baseUpdateCallerReward        = 0.0001 ether;
        uint256 maxUpdateCallerReward         = 0.0001 ether;
        uint256 perSecondCallerRewardIncrease = 1 * RAY;

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

        // Setup treasury allowance
        treasury.setTotalAllowance(address(osmWrapper), uint(-1));
        treasury.setPerBlockAllowance(address(osmWrapper), 0.0001 ether * RAY);

        // Set the remaining params
        osmWrapper.modifyParameters("treasury", address(treasury));
        osmWrapper.modifyParameters("maxUpdateCallerReward", maxUpdateCallerReward);
        osmWrapper.modifyParameters("baseUpdateCallerReward", baseUpdateCallerReward);
        osmWrapper.modifyParameters("perSecondCallerRewardIncrease", perSecondCallerRewardIncrease);
        osmWrapper.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay);

        return address(osm);
    }
}
