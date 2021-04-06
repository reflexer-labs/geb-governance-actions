pragma solidity 0.6.7;

import {CollateralAuctionThrottler} from "geb-collateral-auction-throttler/CollateralAuctionThrottler.sol";

abstract contract LiquidationEngineLike {
    function addAuthorization(address) external virtual;
}

abstract contract StabilityFeeTreasuryLike {
    function setTotalAllowance(address, uint256) external virtual;
    function setPerBlockAllowance(address, uint256) external virtual;
}

contract DeployCollateralAuctionThottler {
    // --- Variables ---
    uint256 public constant RAY = 10**27;
    uint256 public constant RAD = 10**45;

    function execute(
        address _safeEngine,
        address _liquidationEngine,
        address _treasury
    ) public returns (address) {
        // Define params
        uint256 updateDelay                   = 1 weeks;
        uint256 backupUpdateDelay             = 8 days;
        uint256 maxRewardIncreaseDelay        = 3 hours;
        uint256 baseUpdateCallerReward        = 0;
        uint256 maxUpdateCallerReward         = 10 ether;
        uint256 perSecondCallerRewardIncrease = RAY;
        uint256 globalDebtPercentage          = 20;
        uint256 minAuctionLimit               = 500000 * RAD;

        address[] memory surplusHolders;

        // deploy the throttler
        CollateralAuctionThrottler throttler = new CollateralAuctionThrottler(
            _safeEngine,
            _liquidationEngine,
            _treasury,
            updateDelay,
            backupUpdateDelay,
            baseUpdateCallerReward,
            maxUpdateCallerReward,
            perSecondCallerRewardIncrease,
            globalDebtPercentage,
            surplusHolders
        );

        // setting params
        throttler.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay);
        throttler.modifyParameters("minAuctionLimit", minAuctionLimit);

        // setting allowances in the SF treasury
        StabilityFeeTreasuryLike(_treasury).setPerBlockAllowance(address(throttler), maxUpdateCallerReward * RAY);
        StabilityFeeTreasuryLike(_treasury).setTotalAllowance(address(throttler), uint(-1));

        // auth throttler in LiquidationEngine
        LiquidationEngineLike(_liquidationEngine).addAuthorization(address(throttler));

        return address(throttler);
    }
}
