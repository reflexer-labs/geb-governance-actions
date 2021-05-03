pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "geb-deploy/test/GebDeploy.t.base.sol";

import "../DeployOSMandWrapper.sol";

contract FsmGovernanceInterfaceMock {
    mapping(bytes32 => address) public fsm;

    function setFsm(bytes32 collateralType, address _fsm) external {
        fsm[collateralType] = _fsm;
    }
}

contract FeedMock {
    bytes32 public priceFeedValue;
    bool public hasValidValue;
    constructor(uint256 initPrice, bool initHas) public {
        priceFeedValue = bytes32(initPrice);
        hasValidValue = initHas;
    }
    function getResultWithValidity() external returns (bytes32, bool) {
        return (priceFeedValue, hasValidValue);
    }
}

contract OracleRelayerMock {
    mapping (bytes32 => mapping(bytes32 => address)) public parameters;

    function modifyParameters(bytes32 collateralType, bytes32 parameter, address val) external {
        parameters[collateralType][parameter] = val;
    }
}

contract DeployOSMandWrapperTest is GebDeployTestBase {
    DeployOSMandWrapper deployProxy;

    // Main contracts
    FeedMock feed;
    FsmGovernanceInterfaceMock fsmGovernanceInterface;

    function setUp() public override {
        super.setUp();
        deployIndex("");

        feed        = new FeedMock(100 ether, true);
        fsmGovernanceInterface = new FsmGovernanceInterfaceMock();
        deployProxy = new DeployOSMandWrapper();

    }

    function test_execute() public {
        // deploy the proposal
        address      usr = address(deployProxy);
        bytes32      tag;  assembly { tag := extcodehash(usr) }
        bytes memory fax = abi.encodeWithSignature(
        "execute(address,address,address)",
        address(stabilityFeeTreasury),
        address(feed),
        address(fsmGovernanceInterface)
        );
        uint         eta = now;
        pause.scheduleTransaction(usr, tag, fax, eta);
        bytes memory out = pause.executeTransaction(usr, tag, fax, eta);

        ExternallyFundedOSM osm = ExternallyFundedOSM(abi.decode(out, (address)));
        assertEq(osm.priceSource(), address(feed));

        FSMWrapper osmWrapper = FSMWrapper(address(osm.fsmWrapper()));

        assertEq(fsmGovernanceInterface.fsm("ETH-A"), address(osmWrapper));

        // checking wrapper deployment
        assertEq(address(osmWrapper.fsm()), address(osm));
        assertEq(address(osmWrapper.treasury()), address(stabilityFeeTreasury));
        assertEq(osmWrapper.reimburseDelay(), 1 hours);
        assertEq(osmWrapper.baseUpdateCallerReward(), 0.0001 ether);
        assertEq(osmWrapper.maxUpdateCallerReward(), 0.0001 ether);
        assertEq(osmWrapper.perSecondCallerRewardIncrease(), 10**27);
        assertEq(osmWrapper.maxRewardIncreaseDelay(), 3 hours);

        // checking allowances
        (uint total, uint perBlock) = stabilityFeeTreasury.getAllowance(address(osmWrapper));
        assertEq(total, uint(-1));
        assertEq(perBlock, 0.0001 ether * 10**27);

        // checking auth in the throttler itself
        assertEq(osmWrapper.authorizedAccounts(address(pause.proxy())), 1);
        assertEq(osmWrapper.authorizedAccounts(address(deployProxy)), 0);
    }
}
