pragma solidity ^0.6.7;

import "geb-deploy/test/GebDeploy.t.base.sol";
import "geb/OracleRelayer.sol";
import "../DeployPIRateSetter.sol";

contract OldRateSetterMock {
    address public treasury;
    address public oracleRelayer;
    address public orcl;
    address public pidCalculator;

    constructor(
        address _treasury,
        address _oracleRelayer,
        address _orcl,
        address _pidCalculator
    ) public {
        treasury = _treasury;
        oracleRelayer = _oracleRelayer;
        orcl = _orcl;
        pidCalculator = _pidCalculator;
    }
}

contract DeployPIRateSetterTest is GebDeployTestBase {
    DeployPIRateSetter deployProxy;
    OldRateSetterMock oldSetter;
    OracleLike orcl;

    uint constant RAY = 10 ** 27;

    function setUp() public override {
        super.setUp();
        deployIndex("");
        deployProxy = new DeployPIRateSetter();

        (orcl,,) = oracleRelayer.collateralTypes("ETH");

        oldSetter = new OldRateSetterMock(
            address(stabilityFeeTreasury),
            address(oracleRelayer),
            address(orcl),
            address(0xfab)
        );

        // auth mock setter on oracleRelayer
        address      usr = address(govActions);
        bytes32      tag;  assembly { tag := extcodehash(usr) }
        bytes memory fax = abi.encodeWithSignature(
            "addAuthorization(address,address)",
            address(oracleRelayer),
            address(oldSetter)
        );
        uint         eta = now;
        pause.scheduleTransaction(usr, tag, fax, eta);
        bytes memory out = pause.executeTransaction(usr, tag, fax, eta);

        assertEq(oracleRelayer.authorizedAccounts(address(oldSetter)), 1);
    }

    function test_execute() public {

        // deploy the proposal
        address      usr = address(deployProxy);
        bytes32      tag;  assembly { tag := extcodehash(usr) }
        bytes memory fax = abi.encodeWithSignature(
            "execute(address)",
            address(oldSetter)
        );
        uint         eta = now;
        pause.scheduleTransaction(usr, tag, fax, eta);
        bytes memory out = pause.executeTransaction(usr, tag, fax, eta);

        (address calculatorAddress, address rateSetterAddress, address relayerAddress) = abi.decode(out, (address,address,address));
        PRawPerSecondCalculator calculator = PRawPerSecondCalculator(calculatorAddress);
        PIRateSetter rateSetter = PIRateSetter(rateSetterAddress);
        SetterRelayer relayer = SetterRelayer(relayerAddress);

        // auth
        // assertEq(oracleRelayer.authorizedAccounts(address(oldSetter)), 0);
        // assertEq(oracleRelayer.authorizedAccounts(address(relayer)), 1);
        assertEq(calculator.authorities(address(rateSetter)), 1);
        assertEq(relayer.authorizedAccounts(address(rateSetter)), 1);

        // calculator params
        usr = address(govActions);
        assembly { tag := extcodehash(usr) }
        fax = abi.encodeWithSignature(
            "addReader(address,address)",
            address(calculator),
            address(this)
        );
        pause.scheduleTransaction(usr, tag, fax, eta);
        bytes memory out2 = pause.executeTransaction(usr, tag, fax, eta);

        assertEq(calculator.sg(), 750 * 10**6);
        assertEq(calculator.ps(), 21600);
        assertEq(calculator.nb(), 10**18);
        assertEq(calculator.foub(), 10**45);
        assertEq(calculator.folb(), -int((10**27)-1));

        // relayer params
        assertEq(address(relayer.oracleRelayer()), address(oracleRelayer));
        assertEq(address(relayer.treasury()), address(stabilityFeeTreasury));
        assertEq(relayer.baseUpdateCallerReward(), 0.0001 ether);
        assertEq(relayer.maxUpdateCallerReward(), 0.0001 ether);
        assertEq(relayer.perSecondCallerRewardIncrease(), 1 * RAY);
        assertEq(relayer.relayDelay(), 6 hours);

        // setter params
        assertEq(address(rateSetter.oracleRelayer()), address(oracleRelayer));
        assertEq(address(rateSetter.setterRelayer()), address(relayer));
        assertEq(address(rateSetter.orcl()), address(orcl));
        assertEq(address(rateSetter.pidCalculator()), address(0xfab));
        assertEq(rateSetter.updateRateDelay(), 6 hours);
    }
}
