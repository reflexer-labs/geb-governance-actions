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

import "../CollateralStabilityFeeProposal.sol";

contract CollateralStabilityFeeProposalTest is GebDeployTestBase {
    CollateralStabilityFeeProposal proposal;
    bytes32[] _collateralTypes;
    uint256[] stabilityFees;
    uint256 earliestExecutionTime;

    function setUp() public override {
        super.setUp();
        deployStable("");
        earliestExecutionTime = pause.delay();
    }

    function setUpAccess() private {
        DSRoles role = DSRoles(address(pause.authority()));
        role.setRootUser(address(proposal), true);
    }

    function testConstructor() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        stabilityFees = [ 1000000564701133626865910626, 1030000000000000000000000000];  // 5% / day, 3% / second

        proposal = new CollateralStabilityFeeProposal(address(pause), address(taxCollector), _collateralTypes, stabilityFees);

        bytes memory signature = abi.encodeWithSignature("deploy(address,bytes32[],uint256[])", address(taxCollector), _collateralTypes, stabilityFees);
        assertEq(keccak256(proposal.signature()), keccak256(signature));
        assertEq(address(proposal.pause()), address(pause));

        assertEq(proposal.earliestExecutionTime(), 0);
        assertTrue(!proposal.executed());
        assertEq(proposal.expiration(), now + 30 days);
    }

    function testFailProposalEmptyCollateralTypes() public {
        stabilityFees = [ 1000000564701133626865910626 ];  // 5% / day
        proposal = new CollateralStabilityFeeProposal(address(pause), address(taxCollector), _collateralTypes, stabilityFees);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalEmptyStabilityFees() public {
        _collateralTypes = [ bytes32("GOLD") ];
        proposal = new CollateralStabilityFeeProposal(address(pause), address(taxCollector), _collateralTypes, stabilityFees);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalBothEmpty() public {
        proposal = new CollateralStabilityFeeProposal(address(pause), address(taxCollector), _collateralTypes, stabilityFees);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalMismatchedLengths() public {
        _collateralTypes = new bytes32[](1);
        stabilityFees = new uint256[](2);
        proposal = new CollateralStabilityFeeProposal(address(pause), address(taxCollector), _collateralTypes, stabilityFees);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testCollateralStabilityFeeProposalExecution() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        stabilityFees = [ 1000000564701133626865910626, 1030000000000000000000000000];  // 5% / day, 3% / second

        proposal = new CollateralStabilityFeeProposal(address(pause), address(taxCollector), _collateralTypes, stabilityFees);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();

        for (uint8 i = 0; i < _collateralTypes.length; i++) {
            (uint256 s,) = taxCollector.collateralTypes(_collateralTypes[i]);
            assertEq(stabilityFees[i], s);
        }
    }

    function testFailRepeatedProposalExecution() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        stabilityFees = [ 1000000564701133626865910626, 1030000000000000000000000000];  // 5% / day, 3% / second

        proposal = new CollateralStabilityFeeProposal(address(pause), address(taxCollector), _collateralTypes, stabilityFees);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
        proposal.executeProposal();
    }

    function testFailProposalExpired() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        stabilityFees = [ 1000000564701133626865910626, 1030000000000000000000000000];  // 5% / day, 3% / second

        proposal = new CollateralStabilityFeeProposal(address(pause), address(taxCollector), _collateralTypes, stabilityFees);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + 30 days);

        proposal.executeProposal();
    }
}
