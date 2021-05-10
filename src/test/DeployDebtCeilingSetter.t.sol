pragma solidity ^0.6.7;

import "geb-deploy/test/GebDeploy.t.base.sol";
import "../DeployDebtCeilingSetter.sol";

contract DeployDebtCeilingSetterTest is GebDeployTestBase {
    DeploySingleSpotDebtCeilingSetter deployProxy;
    uint256 public constant RAY = 10**27;
    uint256 public constant RAD = 10**45;
    uint256 baseUpdateCallerReward        = 10e13;
    uint256 maxUpdateCallerReward         = 10e13;
    uint256 perSecondCallerRewardIncrease = RAY;
    uint256 updateDelay                   = 86400;
    uint256 maxRewardIncreaseDelay        = 3 hours;
    uint256 ceilingPercentageChange       = 125;
    uint256 maxCollateralCeiling          = uint(-1);
    uint256 minCollateralCeiling          = 10e5 * RAD;

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
            "execute(address,address,address,bytes32,address)",
            address(safeEngine),
            address(oracleRelayer),
            address(stabilityFeeTreasury),
            bytes32("ETH"),
            address(0xfab)
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
        assertEq(perBlock, 10e40);

        // assertEq(safeEngine.authorizedAccounts(address(ceilingSetter)), 1);
        assertEq(ceilingSetter.authorizedAccounts(address(pause.proxy())), 1);

    }
}
