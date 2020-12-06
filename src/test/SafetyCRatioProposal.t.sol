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

import "../SafetyCRatioProposal.sol";

contract SafetyCRatioProposalTest is GebDeployTestBase {
    SafetyCRatioProposal proposal;
    bytes32[] _collateralTypes;
    uint256[] safetyCRatios;
    uint256   earliestExecutionTime;

    function setUp() public override {
        super.setUp();
        deployIndex("");
        earliestExecutionTime = pause.delay();

    }

    function setUpAccess() private {
        DSRoles role = DSRoles(address(pause.authority()));
        role.setRootUser(address(proposal), true);
    }

    function testConstructor() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        safetyCRatios = [ 1500000000 ether, 2000000000 ether ];

        proposal = new SafetyCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, safetyCRatios);

        for (uint256 i = 0; i < _collateralTypes.length; i++) {
            assertEq(proposal.collateralTypes(i), _collateralTypes[i]);
        }
        for (uint256 i = 0; i < safetyCRatios.length; i++) {
            assertEq(proposal.safetyCRatios(i), safetyCRatios[i]);
        }

        assertEq(address(proposal.pause()), address(pause));
        assertEq(address(proposal.target()), address(govActions));
        assertEq(address(proposal.oracleRelayer()), address(oracleRelayer));

        assertEq(proposal.earliestExecutionTime(), 0);
        assertTrue(!proposal.executed());
    }

    function testFailProposalEmptyCollateralTypes() public {
        safetyCRatios = [ 1500000000 ether, 2000000000 ether ];

        proposal = new SafetyCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, safetyCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalEmptySafetyCRatios() public {
        _collateralTypes = [ bytes32("GOLD") ];
        proposal = new SafetyCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, safetyCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalBothEmpty() public {
        proposal = new SafetyCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, safetyCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalMismatchedLengths() public {
        _collateralTypes  = [ bytes32("GOLD")];
        safetyCRatios = [ 1500000000 ether, 2000000000 ether ];
        proposal = new SafetyCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, safetyCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testSafetyCRatioProposal() public {

        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        safetyCRatios = [ 1500000000 ether, 2000000000 ether ];

        proposal = new SafetyCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, safetyCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();

        for (uint8 i = 0; i < _collateralTypes.length; i++) {
            (, uint256 s,) = oracleRelayer.collateralTypes(_collateralTypes[i]);
            assertEq(safetyCRatios[i], s);
        }
    }

    function testFailRepeatedProposalExecution() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        safetyCRatios = [ 1500000000 ether, 2000000000 ether ];

        proposal = new SafetyCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, safetyCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
        proposal.executeProposal();
    }
}
