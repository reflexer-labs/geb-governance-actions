pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "merkle-distributor/MerkleDistributorFactory.sol";

import "../DeployUniswapTWAP.sol";

contract OldTwapMock is UniswapConsecutiveSlotsPriceFeedMedianizer {
    address public treasury;

    constructor(
      address converterFeed_,
      address uniswapFactory_,
      uint256 defaultAmountIn_,
      uint256 windowSize_,
      uint256 converterFeedScalingFactor_,
      uint256 maxWindowSize_,
      uint8   granularity_,
      address treasury_
    ) public UniswapConsecutiveSlotsPriceFeedMedianizer(
        converterFeed_,
        uniswapFactory_,
        defaultAmountIn_,
        windowSize_,
        converterFeedScalingFactor_,
        maxWindowSize_,
        granularity_
    ) {
        treasury = treasury_;
    }
}

contract UniswapFactoryMock {
    address public pair = address(0x123);

    function getPair(address, address) public returns (address) {
        return pair;
    }
}

contract TreasuryMock {
    address public systemCoin = address(0xc01);
}

contract DeployUniswapTWAPTest is DSTest {
    OldTwapMock oldTwap;
    UniswapFactoryMock uniFactory;
    TreasuryMock treasury;
    DeployUniswapTWAP proxy;

    function setUp() public {
        uniFactory = new UniswapFactoryMock();

        treasury = new TreasuryMock();

        oldTwap = new OldTwapMock(
            address(0xfeed),
            address(uniFactory),
            1000000000000000000,
            57600,
            1000000000000000000,
            86400,
            4,
            address(treasury)
        );

        oldTwap.modifyParameters("targetToken", address(0xabc));
        oldTwap.modifyParameters("denominationToken", address(0xcde));

        proxy = new DeployUniswapTWAP();
    }

    function test_execute() public {
        (bool success, bytes memory out) =  address(proxy).delegatecall(abi.encodeWithSignature(
            "execute(address)",
            address(oldTwap)
        ));
        assertTrue(success);
        (address twapAddress, address relayerAddress) = abi.decode(out, (address,address));

        UniswapConsecutiveSlotsPriceFeedMedianizer newTwap = UniswapConsecutiveSlotsPriceFeedMedianizer(twapAddress);
        IncreasingRewardRelayer relayer = IncreasingRewardRelayer(relayerAddress);

        // test twap
        assertEq(address(newTwap.converterFeed()), address(oldTwap.converterFeed()));
        assertEq(address(newTwap.uniswapFactory()), address(oldTwap.uniswapFactory()));
        assertEq(newTwap.defaultAmountIn(), oldTwap.defaultAmountIn());
        assertEq(newTwap.windowSize(), 64800);
        assertEq(newTwap.converterFeedScalingFactor(), oldTwap.converterFeedScalingFactor());
        assertEq(newTwap.maxWindowSize(), 86400);
        assertEq(uint(newTwap.granularity()), 3);
        assertEq(newTwap.targetToken(), oldTwap.targetToken());
        assertEq(newTwap.denominationToken(), oldTwap.denominationToken());
        assertEq(address(newTwap.relayer()), address(relayer));

        // test relayer
        assertEq(address(relayer.refundRequestor()), address(newTwap));
        assertEq(address(relayer.treasury()), address(treasury));
        assertEq(relayer.baseUpdateCallerReward(), 0.0001 ether);
        assertEq(relayer.maxUpdateCallerReward(), 0.0001 ether);
        assertEq(relayer.perSecondCallerRewardIncrease(), proxy.RAY());
        assertEq(relayer.reimburseDelay(), 21600);
        assertEq(relayer.maxRewardIncreaseDelay(), 10800);

        // checking treasury allowances
        (uint total, uint perBlock) = stabilityFeeTreasury.getAllowance(address(relayer));
        assertEq(total, uint(-1));
        assertEq(perBlock, 0.0001 ether * 10**27);

        (total, perBlock) = stabilityFeeTreasury.getAllowance(address(oldTwap));
        assertEq(total, 0);
        assertEq(perBlock, 0);
    }
}
