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

import "../LiquidationPenaltyProposal.sol";

contract MultiDebtCeilingProposalTest is GebDeployTestBase {
    LiquidationPenaltyProposal proposal;
    bytes32[] _collateralTypes;
    uint256[] liquidationPenalties;
    uint256   earliestExecutionTime;

    function setUp() public override {
        super.setUp();
        deployBond("");
        earliestExecutionTime = pause.delay();
    }

    function setUpAccess() private {
        DSRoles role = DSRoles(address(pause.authority()));
        role.setRootUser(address(proposal), true);
    }

    function testConstructor() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        liquidationPenalties = [ 1 ether, 2 ether ];

        proposal = new LiquidationPenaltyProposal(address(pause), address(govActions), address(liquidationEngine), _collateralTypes, liquidationPenalties);

        for (uint256 i = 0; i < _collateralTypes.length; i++) {
            assertEq(proposal.collateralTypes(i), _collateralTypes[i]);
        }
        for (uint256 i = 0; i < liquidationPenalties.length; i++) {
            assertEq(proposal.liquidationPenalties(i), liquidationPenalties[i]);
        }

        assertEq(address(proposal.pause()), address(pause));
        assertEq(address(proposal.target()), address(govActions));
        assertEq(address(proposal.liquidationEngine()), address(liquidationEngine));

        assertEq(proposal.earliestExecutionTime(), 0);
        assertTrue(!proposal.executed());
    }

    function testFailProposalEmptyCollateralTypes() public {
        liquidationPenalties = [ 1 ether ];
        proposal = new LiquidationPenaltyProposal(address(pause), address(govActions), address(liquidationEngine), _collateralTypes, liquidationPenalties);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalEmptyLiquidationPenalties() public {
        _collateralTypes = [ bytes32("GOLD") ];
        proposal = new LiquidationPenaltyProposal(address(pause), address(govActions), address(liquidationEngine), _collateralTypes, liquidationPenalties);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalBothEmpty() public {
        proposal = new LiquidationPenaltyProposal(address(pause), address(govActions), address(liquidationEngine), _collateralTypes, liquidationPenalties);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalMismatchedLengths() public {
        _collateralTypes = new bytes32[](1);
        liquidationPenalties = new uint256[](2);
        proposal = new LiquidationPenaltyProposal(address(pause), address(govActions), address(liquidationEngine), _collateralTypes, liquidationPenalties);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testLiquidationPenaltyProposal() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        liquidationPenalties = [ 1 ether, 2 ether ];

        proposal = new LiquidationPenaltyProposal(address(pause), address(govActions), address(liquidationEngine), _collateralTypes, liquidationPenalties);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();

        for (uint8 i = 0; i < _collateralTypes.length; i++) {
            (, uint256 l,) = liquidationEngine.collateralTypes(_collateralTypes[i]);
            assertEq(liquidationPenalties[i], l);
        }
    }

    function testFailRepeatedProposalExecution() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        liquidationPenalties = [ 1 ether, 2 ether ];

        proposal = new LiquidationPenaltyProposal(address(pause), address(govActions), address(liquidationEngine), _collateralTypes, liquidationPenalties);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
        proposal.executeProposal();
    }
}
