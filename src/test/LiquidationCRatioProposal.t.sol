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

import "../LiquidationCRatioProposal.sol";

contract LiquidationCRatioProposalTest is GebDeployTestBase {
    LiquidationCRatioProposal proposal;
    bytes32[] _collateralTypes;
    uint256[] liquidationCRatios;
    uint256   earliestExecutionTime;

    function setUp() public override {
        super.setUp();
        deployBond("");
        earliestExecutionTime = pause.delay();

        // raising safetyCRatio from 0 (has to be larger than liquidationCRatio)
        this.modifyParameters(address(oracleRelayer),bytes32("GOLD"), "safetyCRatio", 2100000000 ether);
        this.modifyParameters(address(oracleRelayer),bytes32("GELD"), "safetyCRatio", 2100000000 ether);
    }

    function setUpAccess() private {
        DSRoles role = DSRoles(address(pause.authority()));
        role.setRootUser(address(proposal), true);
    }

    function testConstructor() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        liquidationCRatios = [ 1500000000 ether, 2000000000 ether ];

        proposal = new LiquidationCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, liquidationCRatios);

        for (uint256 i = 0; i < _collateralTypes.length; i++) {
            assertEq(proposal.collateralTypes(i), _collateralTypes[i]);
        }
        for (uint256 i = 0; i < liquidationCRatios.length; i++) {
            assertEq(proposal.liquidationCRatios(i), liquidationCRatios[i]);
        }

        assertEq(address(proposal.pause()), address(pause));
        assertEq(address(proposal.target()), address(govActions));
        assertEq(address(proposal.oracleRelayer()), address(oracleRelayer));

        assertEq(proposal.earliestExecutionTime(), 0);
        assertTrue(!proposal.executed());
    }

    function testFailProposalEmptyCollateralTypes() public {
        liquidationCRatios = [ 1.05 ether, 1.15 ether ];

        proposal = new LiquidationCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, liquidationCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalEmptyLiquidationCRatios() public {
        _collateralTypes = [ bytes32("GOLD") ];
        proposal = new LiquidationCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, liquidationCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalBothEmpty() public {
        proposal = new LiquidationCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, liquidationCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalMismatchedLengths() public {
        _collateralTypes = new bytes32[](1);
        liquidationCRatios = new uint256[](2);
        proposal = new LiquidationCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, liquidationCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testLiquidationCRatioProposal() public {

        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        liquidationCRatios = [ 1500000000 ether, 1900000000 ether ];

        proposal = new LiquidationCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, liquidationCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        emit log_named_uint("liquidationCRatio", oracleRelayer.liquidationCRatio(bytes32("GOLD")));
        emit log_named_uint("safetyCRatio", oracleRelayer.safetyCRatio(bytes32("GOLD")));
        proposal.executeProposal();

        for (uint8 i = 0; i < _collateralTypes.length; i++) {
            (,, uint256 l) = oracleRelayer.collateralTypes(_collateralTypes[i]);
            assertEq(liquidationCRatios[i], l);
        }
    }

    function testFailRepeatedProposalExecution() public {
        _collateralTypes  = [ bytes32("GOLD"), bytes32("GELD") ];
        liquidationCRatios = [ 1500000000 ether, 2100000000 ether ];

        proposal = new LiquidationCRatioProposal(address(pause), address(govActions), address(oracleRelayer), _collateralTypes, liquidationCRatios);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
        proposal.executeProposal();
    }
}
