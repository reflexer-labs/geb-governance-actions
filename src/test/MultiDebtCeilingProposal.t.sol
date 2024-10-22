// Copyright (C) 2019 Lorenzo Manacorda <lorenzo@mailbox.org>
//
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

import "../MultiDebtCeilingProposal.sol";

contract MultiDebtCeilingProposalTest is GebDeployTestBase {
    MultiDebtCeilingProposal proposal;
    bytes32[] _collateralTypes;
    uint256[] debtCeilings;
    uint256 earliestExecutionTime;

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
        debtCeilings = [ 100, 200 ];

        proposal = new MultiDebtCeilingProposal(address(pause), address(govActions), address(safeEngine), _collateralTypes, debtCeilings);

        for (uint256 i = 0; i < _collateralTypes.length; i++) {
            assertEq(proposal.collateralTypes(i), _collateralTypes[i]);
        }
        for (uint256 i = 0; i < debtCeilings.length; i++) {
            assertEq(proposal.debtCeilings(i), debtCeilings[i]);
        }

        assertEq(address(proposal.pause()), address(pause));
        assertEq(address(proposal.target()),  address(govActions));
        assertEq(address(proposal.safeEngine()),   address(safeEngine));

        assertEq(proposal.earliestExecutionTime(), 0);
        assertTrue(!proposal.executed());
    }

    function testFailProposalEmptyCollateralTypes() public {
        debtCeilings = [ 1 ];
        proposal = new MultiDebtCeilingProposal(address(pause), address(govActions), address(safeEngine), _collateralTypes, debtCeilings);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalEmptyDebtCeilings() public {
        _collateralTypes = [ bytes32("GOLD") ];
        proposal = new MultiDebtCeilingProposal(address(pause), address(govActions), address(safeEngine), _collateralTypes, debtCeilings);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalBothEmpty() public {
        proposal = new MultiDebtCeilingProposal(address(pause), address(govActions), address(safeEngine), _collateralTypes, debtCeilings);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalMismatchedLengths() public {
        _collateralTypes = new bytes32[](1);
        debtCeilings = new uint256[](2);
        proposal = new MultiDebtCeilingProposal(address(pause), address(govActions), address(safeEngine), _collateralTypes, debtCeilings);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testMultiDebtCeilingProposal() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        debtCeilings = [ 100, 200 ];

        proposal = new MultiDebtCeilingProposal(address(pause), address(govActions), address(safeEngine), _collateralTypes, debtCeilings);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();

        for (uint8 i = 0; i < _collateralTypes.length; i++) {
            (,,, uint256 l,,) = safeEngine.collateralTypes(_collateralTypes[i]);
            assertEq(debtCeilings[i], l);
        }
    }

    function testFailRepeatedProposalExecution() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        debtCeilings = [ 100, 200 ];

        proposal = new MultiDebtCeilingProposal(address(pause), address(govActions), address(safeEngine), _collateralTypes, debtCeilings);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
        proposal.executeProposal();
    }
}
