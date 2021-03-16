// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.6.7;

import "ds-test/test.sol";
import "geb-deploy/test/GebDeploy.t.base.sol";

import "../SecondaryTaxReceiversProposal.sol";

contract SecondaryTaxReceiversProposalTest is GebDeployTestBase {
    SecondaryTaxReceiversProposal proposal;
    bytes32[] _collateralTypes;
    uint256[] positions;
    uint256[] percentages;
    address[] secondaryReceivers;
    uint256   earliestExecutionTime;

    function setUp() public override {
        super.setUp();
        deployStable("");
        earliestExecutionTime = pause.delay();

        // raising secondaryTxReceiver limit from 1
        this.modifyParameters(address(taxCollector),"maxSecondaryReceivers", 3);
    }

    function setUpAccess() private {
        DSRoles role = DSRoles(address(pause.authority()));
        role.setRootUser(address(proposal), true);
    }

    function testConstructor() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        positions = [ 0, 1]; 
        percentages = [ray(1 ether), ray(1.01 ether)];
        secondaryReceivers = [0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF,0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF];

        proposal = new SecondaryTaxReceiversProposal(address(pause), address(taxCollector), _collateralTypes, positions, percentages, secondaryReceivers);

        bytes memory signature = 
            abi.encodeWithSignature("deploy(address,bytes32[],uint256[],uint256[],address[])", 
            taxCollector, 
            _collateralTypes,
            positions,
            percentages,
            secondaryReceivers);
        
        assertEq(keccak256(proposal.signature()), keccak256(signature));
        assertEq(address(proposal.pause()), address(pause));

        assertEq(proposal.earliestExecutionTime(), 0);
        assertTrue(!proposal.executed());
        assertEq(proposal.expiration(), now + 30 days);
    }

    function testFailMismatchedCollateralTypes() public {
        _collateralTypes  = [ bytes32("GOLD")];
        positions = [ 1, 2]; 
        percentages = [ray(1 ether), ray(1.01 ether)];
        secondaryReceivers = [0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF,0xDeaD00000000000000000000000000000000BEEf];

        proposal = new SecondaryTaxReceiversProposal(address(pause), address(taxCollector), _collateralTypes, positions, percentages, secondaryReceivers);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailMismatchedPositions() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        percentages = [ray(1 ether), ray(1.01 ether)];
        secondaryReceivers = [0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF,0xDeaD00000000000000000000000000000000BEEf];

        proposal = new SecondaryTaxReceiversProposal(address(pause), address(taxCollector), _collateralTypes, positions, percentages, secondaryReceivers);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailMismatchedPercentages() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        positions = [ 1, 2]; 
        percentages = [ray(1.01 ether)];
        secondaryReceivers = [0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF,0xDeaD00000000000000000000000000000000BEEf];

        proposal = new SecondaryTaxReceiversProposal(address(pause), address(taxCollector), _collateralTypes, positions, percentages, secondaryReceivers);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailMismatchedSecondaryReceivers() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        positions = [ 1, 2]; 
        percentages = [ray(1 ether), ray(1.01 ether)];
        secondaryReceivers = [0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF];

        proposal = new SecondaryTaxReceiversProposal(address(pause), address(taxCollector), _collateralTypes, positions, percentages, secondaryReceivers);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalAllEmpty() public {
        proposal = new SecondaryTaxReceiversProposal(address(pause), address(taxCollector), _collateralTypes, positions, percentages, secondaryReceivers);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testCollateralStabilityFeeProposalExecution() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        positions = [ 1, 2]; 
        percentages = [ray(1 ether), ray(1.01 ether)];
        secondaryReceivers = [0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF,0xDeaD00000000000000000000000000000000BEEf];

        proposal = new SecondaryTaxReceiversProposal(address(pause), address(taxCollector), _collateralTypes, positions, percentages, secondaryReceivers);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();

        assertEq(taxCollector.usedSecondaryReceiver(secondaryReceivers[0]), 1);
        assertEq(taxCollector.usedSecondaryReceiver(secondaryReceivers[1]), 1);
        assertEq(taxCollector.secondaryReceiverRevenueSources(secondaryReceivers[0]), 1);
        assertEq(taxCollector.secondaryReceiverRevenueSources(secondaryReceivers[1]), 1);

        // removing secondaryTaxReceiver, to remove pass percentage == 0
        _collateralTypes  = [ bytes32("GELD") ];
        positions = [ 2 ]; 
        percentages = [ 0 ];
        secondaryReceivers = [0xDeaD00000000000000000000000000000000BEEf];

        proposal = new SecondaryTaxReceiversProposal(address(pause), address(taxCollector), _collateralTypes, positions, percentages, secondaryReceivers);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();

        assertEq(taxCollector.usedSecondaryReceiver(secondaryReceivers[0]), 0);
        assertEq(taxCollector.secondaryReceiverRevenueSources(secondaryReceivers[0]), 0);
    }

    function testFailRepeatedProposalExecution() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        positions = [ 0, 1]; 
        percentages = [ray(1 ether), ray(1.01 ether)];
        secondaryReceivers = [0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF,0xDeaD00000000000000000000000000000000BEEf];

        proposal = new SecondaryTaxReceiversProposal(address(pause), address(taxCollector), _collateralTypes, positions, percentages, secondaryReceivers);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
        proposal.executeProposal();
    }

    function testFailProposalExpired() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        positions = [ 0, 1]; 
        percentages = [ray(1 ether), ray(1.01 ether)];
        secondaryReceivers = [0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF,0xDeaD00000000000000000000000000000000BEEf];

        proposal = new SecondaryTaxReceiversProposal(address(pause), address(taxCollector), _collateralTypes, positions, percentages, secondaryReceivers);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + 30 days);

        proposal.executeProposal();
    }
}
