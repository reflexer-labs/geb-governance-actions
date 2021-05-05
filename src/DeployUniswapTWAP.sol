pragma solidity 0.6.7;

import {UniswapConsecutiveSlotsPriceFeedMedianizer} from "geb-uniswap-median/UniswapConsecutiveSlotsPriceFeedMedianizer.sol";
import {IncreasingRewardRelayer} from "geb-treasury-reimbursement/relayer/IncreasingRewardRelayer.sol";

abstract contract OldTwapLike is UniswapConsecutiveSlotsPriceFeedMedianizer {
    function treasury() public virtual returns (address);
}

// @notice Proposal to deploy and setup new Uniswap TWAP
// @notice The contract will be deployed/setup, but not yet connected to the system (to allow for testing)
// Missing steps:
// - connect to the RateSetter
contract DeployUniswapTWAP {
    // --- Variables ---
    uint256 public constant RAY = 10**27;

    function execute(address oldTwapAddress) public returns (address, address) {
        OldTwapLike oldTwap = OldTwapLike(oldTwapAddress);

        // deploy new TWAP
        UniswapConsecutiveSlotsPriceFeedMedianizer newTwap = new UniswapConsecutiveSlotsPriceFeedMedianizer(
            address(oldTwap.converterFeed()),
            address(oldTwap.uniswapFactory()),
            oldTwap.defaultAmountIn(),
            64800, // windowSize
            oldTwap.converterFeedScalingFactor(),
            86400, // maxWindowSize
            3      // granularity
        );

        newTwap.modifyParameters("targetToken", oldTwap.targetToken());
        newTwap.modifyParameters("denominationToken", oldTwap.denominationToken());

        // deploy increasing reward relayer:
        IncreasingRewardRelayer rewardRelayer = new IncreasingRewardRelayer(
            address(newTwap), // refundRequestor
            address(oldTwap.treasury()),
            0.0001 ether,     // baseUpdateCallerReward
            0.0001 ether,     // maxUpdateCallerReward
            1 * RAY,          // perSecondCallerRewardIncrease,
            21600             // reimburseDelay
        );

        rewardRelayer.modifyParameters("maxRewardIncreaseDelay", 10800);

        // setting relayer on twap
        newTwap.modifyParameters("relayer", address(rewardRelayer));

        return (address(newTwap), address(rewardRelayer));
    }
}
