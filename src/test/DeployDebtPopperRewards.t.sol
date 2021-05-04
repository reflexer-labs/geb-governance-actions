pragma solidity ^0.6.7;

import "geb-deploy/test/GebDeploy.t.base.sol";
import "../DeployDebtPopperRewards.sol";

contract DeployDebtPopperRewardsTest is GebDeployTestBase {
    DeployDebtPopperRewards deployProxy;
    uint256 public constant RAY = 10**27;
    uint256 public constant RAD = 10**45;

    uint256 rewardPeriodStart = 1619602729;
    uint256 interPeriodDelay = 1209600;
    uint256 rewardTimeline = 4838400;
    uint256 fixedReward = 1 * WAD;
    uint256 maxPerPeriodPops = 10;
    uint256 rewardStartTime = 1619602729;

    function setUp() public override {
        super.setUp();
        deployIndex("");
        deployProxy = new DeployDebtPopperRewards();
    }

    function test_execute() public {
        // deploy the proposal
        address      usr = address(deployProxy);
        bytes32      tag;  assembly { tag := extcodehash(usr) }
        bytes memory fax = abi.encodeWithSignature(
            "execute(address,address)",
            address(accountingEngine),
            address(stabilityFeeTreasury)
        );
        uint         eta = now;
        pause.scheduleTransaction(usr, tag, fax, eta);
        bytes memory out = pause.executeTransaction(usr, tag, fax, eta);

        DebtPopperRewards popperRewards = DebtPopperRewards(abi.decode(out, (address)));

        assertEq(popperRewards.rewardPeriodStart(), rewardPeriodStart);
        assertEq(popperRewards.interPeriodDelay(), interPeriodDelay);
        assertEq(popperRewards.rewardTimeline(), rewardTimeline);
        assertEq(popperRewards.maxPerPeriodPops(), maxPerPeriodPops);
        assertEq(popperRewards.rewardStartTime(), rewardStartTime);
        assertEq(popperRewards.fixedReward(), fixedReward);

        assertEq(address(popperRewards.accountingEngine()), address(accountingEngine));
        assertEq(address(popperRewards.treasury()), address(stabilityFeeTreasury));

        (uint total, uint perBlock) = stabilityFeeTreasury.getAllowance(address(popperRewards));
        assertEq(total, uint(-1));
        assertEq(perBlock, 1 * RAD);

        assertEq(popperRewards.authorizedAccounts(address(pause.proxy())), 1);

    }
}
