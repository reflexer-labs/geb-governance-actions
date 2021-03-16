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

// import "ds-test/test.sol";
import "geb-deploy/test/GebDeploy.t.base.sol";

import "../GlobalSettlementProposal.sol";

// abstract contract GlobalSettlementLike {
//     function shutdownTime() virtual public returns (uint);
// }

contract GlobalSettlementProposalTest is GebDeployTestBase {
    GlobalSettlementProposal proposal;
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

        proposal = new GlobalSettlementProposal(address(pause), address(govActions), address(globalSettlement));

        assertEq(address(proposal.pause()), address(pause));
        assertEq(address(proposal.target()), address(govActions));
        assertEq(address(proposal.globalSettlement()), address(globalSettlement));
        assertEq(proposal.earliestExecutionTime(), 0);
        assertTrue(!proposal.executed());
    }

    function testGlobalSettlementProposal() public {

        proposal = new GlobalSettlementProposal(address(pause), address(govActions), address(globalSettlement));
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();

        assertEq(globalSettlement.shutdownTime(), now);
    }

    function testFailRepeatedProposalExecution() public {
        proposal = new GlobalSettlementProposal(address(pause), address(govActions), address(globalSettlement));
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
        proposal.executeProposal();
    }
}
