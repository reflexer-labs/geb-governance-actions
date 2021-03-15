pragma solidity ^0.6.7;

import {CollateralAuctionThrottler} from "geb-collateral-auction-throttler/CollateralAuctionThrottler.sol";

abstract contract LiquidationEngineLike {
    function addAuthorization(address) external virtual;
}

abstract contract StabilityFeeTreasuryLike {
    function setTotalAllowance(address, uint256) external virtual;
    function setPerBlockAllowance(address, uint256) external virtual;
}

contract DeployCollateralAuctionThottler {
    function execute(
        address _safeEngine,
        address _liquidationEngine,
        address _treasury
    ) public  returns (address) {
        uint256 updateDelay                   = 6 hours;
        uint256 backupUpdateDelay             = 7 hours;
        uint256 baseUpdateCallerReward        = 5 ether;
        uint256 maxUpdateCallerReward         = 10 ether;
        uint256 perSecondCallerRewardIncrease = 1000192559420674483977255848;
        uint256 globalDebtPercentage          = 25;
        address[] memory surplusHolders; // empty

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

        // setting maxRewardIncreaseDelay
        throttler.modifyParameters("maxRewardIncreaseDelay", 6 hours);

        // setting allowances on treasury
        StabilityFeeTreasuryLike(_treasury).setPerBlockAllowance(address(throttler), 10 ** 46); // 10 RAD
        StabilityFeeTreasuryLike(_treasury).setTotalAllowance(address(throttler), uint(-1));    // unlimited    

        // auth throttler in liquidationEngine
        LiquidationEngineLike(_liquidationEngine).addAuthorization(address(throttler));

        return address(throttler);
    }
}
