pragma solidity 0.6.7;

import {PIRateSetter} from "geb-rrfm-rate-setter/PIRateSetter.sol";
import {SetterRelayer} from "geb-rrfm-rate-setter/SetterRelayer.sol";
import {PRawPerSecondCalculator} from "geb-rrfm-calculators/calculator/PRawPerSecondCalculator.sol";

abstract contract oldRateSetterLike is PIRateSetter {
    function treasury() public virtual returns (address);
}

abstract contract Setter {
    function addAuthorization(address) external virtual;
    function removeAuthorization(address) external virtual;
    function modifyParameters(bytes32,bytes32,address) external virtual;
}

// @dev This contract is made for upgrading from an older version of the rate setter and to a P only calculator
// Last steps are not performed, to allow for testing before commiting to the upgrade (steps commented in the execute function)
contract DeployPIRateSetter {
    uint constant RAY = 10 ** 27;

    function execute(address oldRateSetter) public returns (address, address, address) {

        oldRateSetterLike oldSetter = oldRateSetterLike(oldRateSetter);

        // deploy the P only calculator
        PRawPerSecondCalculator calculator = new PRawPerSecondCalculator(
            750 * 10**6,     // sg
            21600,           // periodSize
            10**18,          // noiseBarrier
            10**45,          // feedbackUpperBound
            -int((10**27)-1) // feedbackLowerBound
        );

        // deploy the Wrapper
        SetterRelayer relayer = new SetterRelayer(
            address(oldSetter.oracleRelayer()),
            address(oldSetter.treasury()),
            0.0001 ether,  // baseUpdateCallerReward
            0.0001 ether,  // maxUpdateCallerReward
            1 * RAY,       // perSecondCallerRewardIncrease
            21600          // relayDelay
        );

        relayer.modifyParameters("maxRewardIncreaseDelay", 10800);

        // deploy new rateSetter
        PIRateSetter rateSetter = new PIRateSetter(
            address(oldSetter.oracleRelayer()),
            address(relayer),
            address(oldSetter.orcl()),
            address(oldSetter.pidCalculator()),
            21600 // updateRateDelay
        );

        rateSetter.modifyParameters("defaultLeak", 1);

        // auth
        calculator.addAuthority(address(rateSetter));
        relayer.addAuthorization(address(rateSetter));
        // Setter(address(oldSetter.oracleRelayer())).addAuthorization(address(relayer));
        // Setter(address(oldSetter.oracleRelayer())).removeAuthorization(address(oldSetter));

        return (address(calculator), address(rateSetter), address(relayer));
    }
}
