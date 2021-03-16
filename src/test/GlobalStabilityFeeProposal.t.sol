pragma solidity >=0.6.7;

import "ds-test/test.sol";

import "geb-deploy/test/GebDeploy.t.base.sol";

import "../GlobalStabilityFeeProposal.sol";

contract GlobalStabilityFeeProposalTest is GebDeployTestBase {
    GlobalStabilityFeeProposal proposal;

    uint public newGlobalStabilityFee = 24500000000000000000000000; // 2.45% / second,

    function setUp() public override {
        super.setUp();
        deployStable("");

        proposal = new GlobalStabilityFeeProposal(
            address(pause),
            address(taxCollector),
            newGlobalStabilityFee
        );

        authority.setRootUser(address(proposal), true);

        proposal.scheduleProposal(); 
        proposal.executeProposal();
    }

    function testExecution() public {
        
        assertEq(taxCollector.globalStabilityFee(), newGlobalStabilityFee);
    }

    function testFailRepeatedProposalExecution() public {

        proposal.executeProposal();
    }
}
