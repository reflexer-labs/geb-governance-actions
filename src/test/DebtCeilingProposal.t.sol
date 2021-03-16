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

import "../DebtCeilingProposal.sol";

contract DebtCeilingProposalTest is GebDeployTestBase {
    DebtCeilingProposal proposal;
    bytes32 collateralType = "GOLD";
    uint256 constant debtCeiling = 10 * 10**18;
    uint256 proposalDelay;

    function setUpAccess() private {
        DSRoles role = DSRoles(address(pause.authority()));
        role.setRootUser(address(proposal), true);
    }

    function setUp() public override {
        super.setUp();
        deployStable("");
        proposalDelay = pause.delay();
    }

    function testConstructor() public {
        proposal = new DebtCeilingProposal(address(pause), address(govActions), address(safeEngine), collateralType, debtCeiling);

        bytes memory expectedSig = abi.encodeWithSignature(
            "modifyParameters(address,bytes32,bytes32,uint256)",
            safeEngine, collateralType, bytes32("debtCeiling"), debtCeiling
        );
        assertEq0(proposal.signature(), expectedSig);

        assertEq(address(proposal.pause()), address(pause));
        assertEq(address(proposal.target()),  address(govActions));
        assertEq(address(proposal.cdpEngine()),   address(safeEngine));

        assertEq(proposal.debtCeiling(), debtCeiling);
        assertEq(proposal.collateralType(),  collateralType);
        assertEq(proposal.earliestExecutionTime(), 0);

        assertTrue(!proposal.executed());
    }

    function testExecution() public {
        proposal = new DebtCeilingProposal(address(pause), address(govActions), address(safeEngine), collateralType, debtCeiling);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + proposalDelay);

        proposal.executeProposal();
        (,,, uint256 l,,) = safeEngine.collateralTypes(collateralType);
        assertEq(debtCeiling, l);
    }

    function testFailToReexecuteProposal() public {
        proposal = new DebtCeilingProposal(address(pause), address(govActions), address(safeEngine), collateralType, debtCeiling);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + proposalDelay);

        proposal.executeProposal();
        proposal.executeProposal();
    }
}
