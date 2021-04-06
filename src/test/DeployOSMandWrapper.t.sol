pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "geb/SAFEEngine.sol";
import "./mock/MockTreasury.sol";

import "../DeployOSMandWrapper.sol";

contract Feed {
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

contract FsmGovernanceInterfaceMock {
    mapping(bytes32 => address) public fsm;

    function setFsm(bytes32 collateralType, address _fsm) external {
        fsm[collateralType] = _fsm;
    }
}

contract OracleRelayerMock {
    mapping (bytes32 => mapping(bytes32 => address)) public parameters;

    function modifyParameters(bytes32 collateralType, bytes32 parameter, address val) external {
        parameters[collateralType][parameter] = val;
    }
}

contract DeployOSMandWrapperTest is DSTest {
    DeployOSMandWrapper deployProxy;

    // Main contracts
    DSToken systemCoin;
    MockTreasury treasury;
    Feed feed;
    FsmGovernanceInterfaceMock fsmGovernanceInterface;
    OracleRelayerMock oracleRelayer;

    function setUp() public {
        systemCoin             = new DSToken("RAI", "RAI");
        treasury               = new MockTreasury(address(systemCoin));
        feed                   = new Feed(100 ether, true);
        fsmGovernanceInterface = new FsmGovernanceInterfaceMock();
        oracleRelayer          = new OracleRelayerMock();

        deployProxy = new DeployOSMandWrapper();
    }

    function test_execute2() public {
        (bool success, bytes memory returnData) =  address(deployProxy).delegatecall(abi.encodeWithSignature(
            "execute(address,address,address,address)",
            address(treasury),
            address(feed),
            address(fsmGovernanceInterface),
            address(oracleRelayer)
        ));
        assertTrue(success);

        ExternallyFundedOSM osm = ExternallyFundedOSM(abi.decode(returnData, (address)));
        assertEq(osm.priceSource(), address(feed));

        FSMWrapper osmWrapper = FSMWrapper(address(osm.fsmWrapper()));

        assertEq(fsmGovernanceInterface.fsm("ETH-A"), address(osmWrapper));
        assertEq(oracleRelayer.parameters("ETH-A","orcl"), address(osmWrapper));

        // // checking wrapper deployment
        assertEq(address(osmWrapper.fsm()), address(osm));
        assertEq(osmWrapper.reimburseDelay(), 6 hours);
        assertEq(address(osmWrapper.treasury()), address(treasury));

        assertEq(osmWrapper.reimburseDelay(), 6 hours);
        assertEq(osmWrapper.baseUpdateCallerReward(), 5 ether);
        assertEq(osmWrapper.maxUpdateCallerReward(), 10 ether);
        assertEq(osmWrapper.perSecondCallerRewardIncrease(), 1000192559420674483977255848);
        assertEq(osmWrapper.maxRewardIncreaseDelay(), 6 hours);

        // checking allowances
        (uint total, uint perBlock) = treasury.getAllowance(address(osmWrapper));
        assertEq(total, uint(-1));
        assertEq(perBlock, 10 ** 46);

        // checking auth in the throttler itself
        assertEq(osmWrapper.authorizedAccounts(address(this)), 1);
        assertEq(osmWrapper.authorizedAccounts(address(deployProxy)), 0);
    }
}
