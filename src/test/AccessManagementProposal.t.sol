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

import "../AccessManagementProposal.sol";

contract AccessManagementProposalTest is GebDeployTestBase {
    AccessManagementProposal proposal;
    address[] gebModules;
    address[] addresses;
    uint8[] grantAccess;
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
        gebModules  = [address(safeEngine), address(liquidationEngine)];
        addresses = [address(this), address(this)];
        grantAccess = [1, 1];

        proposal = new AccessManagementProposal(address(pause), address(govActions), gebModules, addresses, grantAccess);

        for (uint256 i = 0; i < gebModules.length; i++) {
            assertEq(proposal.gebModules(i), gebModules[i]);
        }
        for (uint256 i = 0; i < addresses.length; i++) {
            assertEq(proposal.addresses(i), addresses[i]);
        }
        for (uint256 i = 0; i < grantAccess.length; i++) {
            assertEq(uint(proposal.grantAccess(i)), uint(grantAccess[i]));
        }

        assertEq(address(proposal.pause()), address(pause));
        assertEq(address(proposal.target()), address(govActions));
        assertEq(proposal.earliestExecutionTime(), 0);
        assertTrue(!proposal.executed());
    }

    function testAccessManagementProposal() public {
        gebModules  = [address(safeEngine), address(liquidationEngine)];
        addresses = [address(this), address(this)];
        grantAccess = [1, 1];

        proposal = new AccessManagementProposal(address(pause), address(govActions), gebModules, addresses, grantAccess);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();


        assertEq(liquidationEngine.authorizedAccounts(address(this)), 1);    
        assertEq(safeEngine.authorizedAccounts(address(this)), 1);


        // revoking back the access
        grantAccess = [0, 0];

        proposal = new AccessManagementProposal(address(pause), address(govActions), gebModules, addresses, grantAccess);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();


        assertEq(liquidationEngine.authorizedAccounts(address(this)), 0);    
        assertEq(safeEngine.authorizedAccounts(address(this)), 0);
    }

    function testFailProposalMismatchedLengths() public {
        gebModules  = [address(safeEngine), address(liquidationEngine)];
        addresses = [address(this), address(this)];
        grantAccess = [1, 1, 1];

        proposal = new AccessManagementProposal(address(pause), address(govActions), gebModules, addresses, grantAccess);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalMismatchedLengths2() public {
        gebModules  = [address(safeEngine), address(liquidationEngine)];
        addresses = [address(this), address(this), address(this)];
        grantAccess = [1, 1];

        proposal = new AccessManagementProposal(address(pause), address(govActions), gebModules, addresses, grantAccess);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }    

    function testFailProposalEmpty() public {
        proposal = new AccessManagementProposal(address(pause), address(govActions), gebModules, addresses, grantAccess);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailRepeatedProposalExecution() public {
        gebModules  = [address(safeEngine), address(liquidationEngine)];
        addresses = [address(this), address(this)];
        grantAccess = [1, 1];

        proposal = new AccessManagementProposal(address(pause), address(govActions), gebModules, addresses, grantAccess);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
        proposal.executeProposal();
    }
}
