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

import "../FixedDiscountCollateralAuctionHouseProposal.sol";

contract FixedDiscountCollateralAuctionHouseProposalTest is GebDeployTestBase {
    FixedDiscountCollateralAuctionHouseProposal proposal;
    bytes32[] parameters;
    bytes32[] values;
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
        parameters  = [ bytes32("discount"), bytes32("lowerCollateralMedianDeviation") ];
        values = [ bytes32(uint(1 ether)), bytes32(uint(0.9 ether))];

        proposal = new FixedDiscountCollateralAuctionHouseProposal(address(pause), address(ethFixedDiscountCollateralAuctionHouse), parameters, values);

        bytes memory signature = abi.encodeWithSignature("deploy(address,bytes32[],bytes32[])", address(ethFixedDiscountCollateralAuctionHouse), parameters, values);
        assertEq(keccak256(proposal.signature()), keccak256(signature));
        assertEq(address(proposal.pause()), address(pause));

        assertEq(proposal.earliestExecutionTime(), 0);
        assertTrue(!proposal.executed());
        assertEq(proposal.expiration(), now + 30 days);
    }

    function testFailProposalEmptyParams() public {
        values = [
            bytes32(uint(0.9 ether)),
            bytes32(uint(0.8 ether))];

        proposal = new FixedDiscountCollateralAuctionHouseProposal(address(pause), address(ethFixedDiscountCollateralAuctionHouse), parameters, values);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalEmptyData() public {
        parameters  = [
            bytes32("discount"),
            bytes32("lowerCollateralMedianDeviation"),
            bytes32("upperCollateralMedianDeviation")];

        proposal = new FixedDiscountCollateralAuctionHouseProposal(address(pause), address(ethFixedDiscountCollateralAuctionHouse), parameters, values);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalBothEmpty() public {
        proposal = new FixedDiscountCollateralAuctionHouseProposal(address(pause), address(ethFixedDiscountCollateralAuctionHouse), parameters, values);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalMismatchedLengths() public {
        parameters  = [
            bytes32("discount"),
            bytes32("lowerCollateralMedianDeviation"),
            bytes32("upperCollateralMedianDeviation")];
        values = [
            bytes32(uint(0.9 ether)),
            bytes32(uint(0.8 ether))];

        proposal = new FixedDiscountCollateralAuctionHouseProposal(address(pause), address(ethFixedDiscountCollateralAuctionHouse), parameters, values);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFixedDiscountAuctionParameterProposalExecution() public {
        parameters  = [
            bytes32("discount"),
            bytes32("lowerCollateralMedianDeviation"),
            bytes32("upperCollateralMedianDeviation"),
            bytes32("lowerSystemCoinMedianDeviation"),
            bytes32("upperSystemCoinMedianDeviation"),
            bytes32("minSystemCoinMedianDeviation"),
            bytes32("minimumBid"),
            bytes32("oracleRelayer"),
            bytes32("systemCoinOracle"),
            bytes32("liquidationEngine") ];
        values = [
            bytes32(uint(0.9 ether)),
            bytes32(uint(0.8 ether)),
            bytes32(uint(0.7 ether)),
            bytes32(uint(0.6 ether)),
            bytes32(uint(0.5 ether)),
            bytes32(uint(0.4 ether)),
            bytes32(uint(0.3 ether)),
            bytes32(uint256(0x0c1E0001714F516c232dEbE2bB0E9876f679470E) << 96),
            bytes32(uint256(0xC012002dCbcFC7486C97c67412181cbd9A662ab7) << 96),
            bytes32(uint256(0x1101dA48A3f269618e068837f3ae5EB9a5b49F67) << 96)];

        proposal = new FixedDiscountCollateralAuctionHouseProposal(address(pause), address(ethFixedDiscountCollateralAuctionHouse), parameters, values);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();

        assertEq(ethFixedDiscountCollateralAuctionHouse.discount(), uint(values[0]));
        assertEq(ethFixedDiscountCollateralAuctionHouse.lowerCollateralMedianDeviation(), uint(values[1]));
        assertEq(ethFixedDiscountCollateralAuctionHouse.upperCollateralMedianDeviation(), uint(values[2]));
        assertEq(ethFixedDiscountCollateralAuctionHouse.lowerSystemCoinMedianDeviation(), uint(values[3]));
        assertEq(ethFixedDiscountCollateralAuctionHouse.upperSystemCoinMedianDeviation(), uint(values[4]));
        assertEq(ethFixedDiscountCollateralAuctionHouse.minSystemCoinMedianDeviation(), uint(values[5]));
        assertEq(ethFixedDiscountCollateralAuctionHouse.minimumBid(), uint(values[6]));

        assertEq(address(ethFixedDiscountCollateralAuctionHouse.oracleRelayer()), address(uint160(uint256(values[7]))) );
        assertEq(address(ethFixedDiscountCollateralAuctionHouse.systemCoinOracle()), address(uint160(uint256(values[8]))) );
        assertEq(address(ethFixedDiscountCollateralAuctionHouse.liquidationEngine()), address(uint160(uint256(values[9]))) );
    }

    function testFailRepeatedProposalExecution() public {
        parameters  = [
            bytes32("discount"),
            bytes32("lowerCollateralMedianDeviation") ];
        values = [
            bytes32(uint(0.9 ether)),
            bytes32(uint(0.8 ether))];

        proposal = new FixedDiscountCollateralAuctionHouseProposal(address(pause), address(ethFixedDiscountCollateralAuctionHouse), parameters, values);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
        proposal.executeProposal();
    }

    function testFailProposalExpired() public {
        parameters  = [
            bytes32("discount"),
            bytes32("lowerCollateralMedianDeviation") ];
        values = [
            bytes32(uint(0.9 ether)),
            bytes32(uint(0.8 ether))];

        proposal = new FixedDiscountCollateralAuctionHouseProposal(address(pause), address(ethFixedDiscountCollateralAuctionHouse), parameters, values);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + 30 days);

        proposal.executeProposal();
    }
}
