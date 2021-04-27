pragma solidity 0.6.7;

import {DebtPopperRewards} from "geb-debt-popper-rewards/DebtPopperRewards.sol";

// abstract contract SAFEEngineLike {
//     function addAuthorization(address) external virtual;
// }

abstract contract StabilityFeeTreasuryLike {
    function setTotalAllowance(address, uint256) external virtual;
    function setPerBlockAllowance(address, uint256) external virtual;
}

contract DeployDebtPopperRewards {
    // --- Variables ---
    uint256 public constant WAD = 10**18;
    uint256 public constant RAY = 10**27;
    uint256 public constant RAD = 10**45;

    function execute(
        address _accountingEngine,
        address _treasury
    ) public returns (address) {
        // Define params
        uint256 rewardPeriodStart = 1619602729;
        uint256 interPeriodDelay = 1209600;
        uint256 rewardTimeline = 4838400;
        uint256 fixedReward = 1 * WAD;
        uint256 maxPerPeriodPops = 10;
        uint256 rewardStartTime = 1619602729;

        // deploy the throttler
        DebtPopperRewards popperRewards = new DebtPopperRewards(
            _accountingEngine,
            _treasury,
            rewardPeriodStart,
            interPeriodDelay,
            rewardTimeline,
            fixedReward,
            maxPerPeriodPops,
            rewardStartTime

        );

        // setting allowances in the SF treasury
        StabilityFeeTreasuryLike(_treasury).setPerBlockAllowance(address(popperRewards), 1 * RAD);
        StabilityFeeTreasuryLike(_treasury).setTotalAllowance(address(popperRewards), uint(-1));

        return address(popperRewards);
    }
}
