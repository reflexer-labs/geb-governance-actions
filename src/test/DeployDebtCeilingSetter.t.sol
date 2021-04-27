pragma solidity ^0.6.7;

import "geb-deploy/test/GebDeploy.t.base.sol";
import "../DeployDebtCeilingSetter.sol";

contract DeployDebtCeilingSetterTest is GebDeployTestBase {
    DeploySingleSpotDebtCeilingSetter deployProxy;
    uint256 public constant RAY = 10**27;
    uint256 public constant RAD = 10**45;
    uint256 public baseUpdateCallerReward        = 0;
    uint256 public maxUpdateCallerReward         = 10 ether;
    uint256 public perSecondCallerRewardIncrease = RAY;
    uint256 public updateDelay                   = 1 weeks;
    uint256 public maxRewardIncreaseDelay        = 3 hours;
    uint256 public ceilingPercentageChange       = 120;
    uint256 public maxCollateralCeiling          = 1000e45;
    uint256 public minCollateralCeiling          = 1e45;

    function setUp() public override {
        super.setUp();
        deployIndex("");
        deployProxy = new DeploySingleSpotDebtCeilingSetter();
    }

    function test_execute() public {
        // deploy the proposal
        address      usr = address(deployProxy);
        bytes32      tag;  assembly { tag := extcodehash(usr) }
        bytes memory fax = abi.encodeWithSignature(
            "execute(address,address,address,bytes32)",
            address(safeEngine),
            address(oracleRelayer),
            address(stabilityFeeTreasury),
            bytes32("ETH")
        );
        uint         eta = now;
        pause.scheduleTransaction(usr, tag, fax, eta);
        bytes memory out = pause.executeTransaction(usr, tag, fax, eta);

        SingleSpotDebtCeilingSetter ceilingSetter = SingleSpotDebtCeilingSetter(abi.decode(out, (address)));
        assertEq(ceilingSetter.baseUpdateCallerReward(), baseUpdateCallerReward);
        assertEq(ceilingSetter.baseUpdateCallerReward(), baseUpdateCallerReward);
        assertEq(ceilingSetter.maxUpdateCallerReward(), maxUpdateCallerReward);
        assertEq(ceilingSetter.perSecondCallerRewardIncrease(), perSecondCallerRewardIncrease);
        assertEq(ceilingSetter.updateDelay(), updateDelay);
        assertEq(ceilingSetter.maxRewardIncreaseDelay(), maxRewardIncreaseDelay);
        assertEq(ceilingSetter.ceilingPercentageChange(), ceilingPercentageChange);
        assertEq(ceilingSetter.maxCollateralCeiling(), maxCollateralCeiling);
        assertEq(ceilingSetter.minCollateralCeiling(), minCollateralCeiling);

        assertEq(address(ceilingSetter.safeEngine()), address(safeEngine));
        assertEq(address(ceilingSetter.oracleRelayer()), address(oracleRelayer));

        (uint total, uint perBlock) = stabilityFeeTreasury.getAllowance(address(ceilingSetter));
        assertEq(total, uint(-1));
        assertEq(perBlock, maxUpdateCallerReward * RAY);

        assertEq(safeEngine.authorizedAccounts(address(ceilingSetter)), 1);
        assertEq(ceilingSetter.authorizedAccounts(address(pause.proxy())), 1);

    }
}
