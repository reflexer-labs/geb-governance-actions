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
    bool      public executed;

    uint256   public updateDelay;
    uint256   public backupUpdateDelay;
    uint256   public maxRewardIncreaseDelay;
    uint256   public baseUpdateCallerReward;
    uint256   public maxUpdateCallerReward;
    uint256   public perSecondCallerRewardIncrease;
    uint256   public globalDebtPercentage;

    address[] public surplusHolders;

    constructor(
        uint256 updateDelay_,
        uint256 backupUpdateDelay_,
        uint256 maxRewardIncreaseDelay_,
        uint256 baseUpdateCallerReward_,
        uint256 maxUpdateCallerReward_,
        uint256 perSecondCallerRewardIncrease_,
        uint256 globalDebtPercentage_,
        address[] memory surplusHolders_
    ) public {
        updateDelay                   = updateDelay_;
        backupUpdateDelay             = backupUpdateDelay_;
        maxRewardIncreaseDelay        = maxRewardIncreaseDelay_;
        baseUpdateCallerReward        = baseUpdateCallerReward_;
        maxUpdateCallerReward         = maxUpdateCallerReward_;
        perSecondCallerRewardIncrease = perSecondCallerRewardIncrease_;
        globalDebtPercentage          = globalDebtPercentage_;

        surplusHolders                = surplusHolders_;
    }

    function executeProposal(
        address _safeEngine,
        address _liquidationEngine,
        address _treasury
    ) public returns (address) {
        require(!executed, "proposal-already-executed");
        executed = true;

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
        throttler.modifyParameters("maxRewardIncreaseDelay", maxRewardIncreaseDelay);

        // setting allowances in the SF treasury
        StabilityFeeTreasuryLike(_treasury).setPerBlockAllowance(address(throttler), maxUpdateCallerReward * RAY);
        StabilityFeeTreasuryLike(_treasury).setTotalAllowance(address(throttler), uint(-1));

        // auth throttler in LiquidationEngine
        LiquidationEngineLike(_liquidationEngine).addAuthorization(address(throttler));

        return address(throttler);
    }
}
