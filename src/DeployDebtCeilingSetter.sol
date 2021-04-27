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
        bytes32 _collateralName
    ) public returns (address) {
        // Define params
        uint256 baseUpdateCallerReward        = 0;
        uint256 maxUpdateCallerReward         = 10 ether;
        uint256 perSecondCallerRewardIncrease = RAY;
        uint256 updateDelay                   = 1 weeks;
        uint256 maxRewardIncreaseDelay        = 3 hours;
        uint256 ceilingPercentageChange       = 120;
        uint256 maxCollateralCeiling          = 1000e45;
        uint256 minCollateralCeiling          = 1e45;

        address[] memory surplusHolders;

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
        StabilityFeeTreasuryLike(_treasury).setPerBlockAllowance(address(ceilingSetter), maxUpdateCallerReward * RAY);
        StabilityFeeTreasuryLike(_treasury).setTotalAllowance(address(ceilingSetter), uint(-1));

        // auth throttler in LiquidationEngine
        SAFEEngineLike(_safeEngine).addAuthorization(address(ceilingSetter));

        return address(ceilingSetter);
    }
}
