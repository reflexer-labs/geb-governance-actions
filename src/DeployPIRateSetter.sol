pragma solidity 0.6.7;

import {PIRateSetter} from "geb-rrfm-rate-setter/PIRateSetter.sol";
import {DirectRateSetter} from "geb-rrfm-rate-setter/DirectRateSetter.sol";
import {SetterRelayer} from "geb-rrfm-rate-setter/SetterRelayer.sol";

abstract contract oldRateSetterLike is PIRateSetter {
    function treasury() public virtual returns (address);
}

abstract contract Setter {
    function addAuthorization(address) external virtual;
    function removeAuthorization(address) external virtual;
    function modifyParameters(bytes32,bytes32,address) external virtual;
}

// @dev This contract is made for upgrading from an older version of the rate setter.
contract DeployPIRateSetter {
    uint constant RAY = 10 ** 27;

    function execute(address oldRateSetter) public returns (address, address) {

        oldRateSetterLike oldSetter = oldRateSetterLike(oldRateSetter);

        // deploy the Wrapper
        SetterRelayer relayer = new SetterRelayer(
            address(oldSetter.oracleRelayer()),
            address(oldSetter.treasury()),
            0.0001 ether,  // baseUpdateCallerReward
            0.0001 ether,  // maxUpdateCallerReward
            1 * RAY,       // perSecondCallerRewardIncrease
            6 hours        // relayDelay
        );

        // deploy new rateSetter
        PIRateSetter rateSetter = new PIRateSetter(
            address(oldSetter.oracleRelayer()),
            address(relayer),
            address(oldSetter.orcl()),
            address(oldSetter.pidCalculator()),
            6 hours // updateRateDelay
        );

        Setter(address(oldSetter.oracleRelayer())).addAuthorization(address(relayer));
        Setter(address(oldSetter.oracleRelayer())).removeAuthorization(address(oldSetter));

        return (address(rateSetter), address(relayer));
    }
}
