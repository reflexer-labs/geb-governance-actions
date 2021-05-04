pragma solidity 0.6.7;

import {PIRateSetter} from "geb-rrfm-rate-setter/PIRateSetter.sol";
import {SetterRelayer} from "geb-rrfm-rate-setter/SetterRelayer.sol";
import {PRawPerSecondCalculator} from "geb-rrfm-calculators/calculator/PRawPerSecondCalculator.sol";

abstract contract OldRateSetterLike is PIRateSetter {
    function treasury() public virtual returns (address);
}

abstract contract Setter {
    function addAuthorization(address) external virtual;
    function removeAuthorization(address) external virtual;
    function modifyParameters(bytes32,bytes32,address) external virtual;
}

// @dev This contract is meant for upgrading from an older version of the rate setter to a new one that supports both a P only and a PI calculator
// It also deploys a P only calculator and connects it to the rate setter.
// The very last steps are not performed in order to allow for testing in prod before commiting to an upgrade (steps commented in the execute function)
contract DeployPIRateSetter {
    uint constant RAY = 10 ** 27;

    function execute(address oldRateSetter) public returns (address, address, address) {
        OldRateSetterLike oldSetter = OldRateSetterLike(oldRateSetter);

        // deploy the P only calculator
        PRawPerSecondCalculator calculator = new PRawPerSecondCalculator(
            5 * 10**8,       // sg
            21600,           // periodSize
            10**18,          // noiseBarrier
            10**45,          // feedbackUpperBound
            -int((10**27)-1) // feedbackLowerBound
        );

        // deploy the setter wrapper
        SetterRelayer relayer = new SetterRelayer(
            address(oldSetter.oracleRelayer()),
            address(oldSetter.treasury()),
            0.0001 ether,  // baseUpdateCallerReward
            0.0001 ether,  // maxUpdateCallerReward
            1 * RAY,       // perSecondCallerRewardIncrease
            21600          // relayDelay
        );

        relayer.modifyParameters("maxRewardIncreaseDelay", 10800);

        // deploy new rate setter
        PIRateSetter rateSetter = new PIRateSetter(
            address(oldSetter.oracleRelayer()),
            address(relayer),
            address(oldSetter.orcl()),
            address(calculator),
            21600 // updateRateDelay
        );

        rateSetter.modifyParameters("defaultLeak", 1);

        // auth
        calculator.modifyParameters("seedProposer", address(rateSetter));
        relayer.modifyParameters("setter", address(rateSetter));
        // Setter(address(oldSetter.oracleRelayer())).addAuthorization(address(relayer));
        // Setter(address(oldSetter.oracleRelayer())).removeAuthorization(address(oldSetter));

        return (address(calculator), address(rateSetter), address(relayer));
    }
}
