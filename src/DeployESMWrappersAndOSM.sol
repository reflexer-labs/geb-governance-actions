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

contract DeployESMWrappersAndOSM {
    // --- Variables ---
    uint256 public constant RAY = 10**27;

    function execute() public returns (address) {
        // Define params (kovan 1.3)
        address safeEngine                    = address(0x7550E6031BaF80A0251A1A7b018f6716596a8a5D);
        address liquidationEngine             = address(0x28CC9041d60C7420F794C78198829E2CE3610b6E);
        StabilityFeeTreasuryLike treasury     = address(0x5F74aEb02E7f951B6fCC3c7731C76C5fB89E0e9d);
        address ethMedianizer                 = address(0xd7D94c15e55D365d8aeE13Af9182D169BEc493D9);
        address fsm                           = address();
        bytes32 collateralType                = bytes32("ETH-A");
        uint256 reimburseDelay                = 6 hours;
        uint256 maxRewardIncreaseDelay        = 6 hours;
        uint256 baseUpdateCallerReward        = 5 ether;
        uint256 maxUpdateCallerReward         = 10 ether;
        uint256 perSecondCallerRewardIncrease = 1000192559420674483977255848;

        // deploy new OSM
        ExternallyFundedOSM osm = address(new ExternallyFundedOSM(ethMedianizer));

        // deploy OSM Wrapper
        FSMWrapper osmWrapper = new FSMWrapper(
            osm,
            reimburseDelay
        );

        // set the wrapper on the OSM
        osm.modifyParameters("fsmWrapper", address(osmWrapper));

        // Setup treasury allowance
        treasury.setTotalAllowance(address(wrapper), maxUpdateCallerReward * RAY);
        treasury.setPerBlockAllowance(address(wrapper), uint(-1));

        // Set the remaining params
        osmWrapper.modifyParameters("treasury", address(treasury));
        osmWrapper.modifyParameters("maxUpdateCallerReward", maxUpdateCallerReward);
        osmWrapper.modifyParameters("baseUpdateCallerReward", baseUpdateCallerReward);
        osmWrapper.modifyParameters("perSecondCallerRewardIncrease", perSecondCallerRewardIncrease);
        osmWrapper.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay);
    }
}
