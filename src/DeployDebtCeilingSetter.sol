pragma solidity 0.6.7;

import {SingleSpotDebtCeilingSetter} from "geb-debt-ceiling-setter/SingleSpotDebtCeilingSetter.sol";

abstract contract SAFEEngineLike {
    function addAuthorization(address) external virtual;
}

abstract contract StabilityFeeTreasuryLike {
    function setTotalAllowance(address, uint256) external virtual;
    function setPerBlockAllowance(address, uint256) external virtual;
}

contract DeploySingleSpotDebtCeilingSetter {
    // --- Variables ---
    uint256 public constant RAY = 10**27;
    uint256 public constant RAD = 10**45;

    function execute(
        address _safeEngine,
        address _oracleRelayer,
        address _treasury,
        bytes32 _collateralName,
        address oldCeilingSetter
    ) public returns (address) {
        // Define params
        uint256 baseUpdateCallerReward        = 10e13;
        uint256 maxUpdateCallerReward         = 10e13;
        uint256 perSecondCallerRewardIncrease = RAY;
        uint256 updateDelay                   = 86400;
        uint256 maxRewardIncreaseDelay        = 3 hours;
        uint256 ceilingPercentageChange       = 125;
        uint256 maxCollateralCeiling          = uint(-1);
        uint256 minCollateralCeiling          = 10e5 * RAD;

        // deploy the throttler
        SingleSpotDebtCeilingSetter ceilingSetter = new SingleSpotDebtCeilingSetter(
            _safeEngine,
            _oracleRelayer,
            _treasury,
            _collateralName,
            baseUpdateCallerReward,
            maxUpdateCallerReward,
            perSecondCallerRewardIncrease,
            updateDelay,
            ceilingPercentageChange,
            maxCollateralCeiling,
            minCollateralCeiling
        );

        // setting params
        ceilingSetter.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay);

        // setting allowances in the SF treasury
        StabilityFeeTreasuryLike(_treasury).setPerBlockAllowance(address(ceilingSetter), 10e40);
        StabilityFeeTreasuryLike(_treasury).setTotalAllowance(address(ceilingSetter), uint(-1));

        StabilityFeeTreasuryLike(_treasury).setPerBlockAllowance(address(oldCeilingSetter), 0);
        StabilityFeeTreasuryLike(_treasury).setTotalAllowance(address(oldCeilingSetter), 0);

        // auth setter in safeEngine
        // SAFEEngineLike(_safeEngine).addAuthorization(address(ceilingSetter));
        // SAFEEngineLike(_safeEngine).removeAuthorization(address(oldCeilingSetter));

        return address(ceilingSetter);
    }
}
