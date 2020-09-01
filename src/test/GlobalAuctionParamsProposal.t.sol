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

import "../GlobalAuctionParamsProposal.sol";

contract GlobalAuctionParamsProposalTest is GebDeployTestBase {
    GlobalAuctionParamsProposal proposal;
    uint256 initialDebtMintedTokens;
    uint256 debtAuctionBidSize;
    uint256 earliestExecutionTime;

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
        initialDebtMintedTokens = 1000 ether;
        debtAuctionBidSize  = 1 ether;

        proposal = new GlobalAuctionParamsProposal(address(pause), address(govActions), address(accountingEngine), initialDebtMintedTokens, debtAuctionBidSize);

        assertEq(address(proposal.pause()), address(pause));
        assertEq(address(proposal.target()), address(govActions));
        assertEq(address(proposal.accountingEngine()), address(accountingEngine));
        assertEq(address(proposal.initialDebtMintedTokens()), address(initialDebtMintedTokens));
        assertEq(address(proposal.debtAuctionBidSize()), address(debtAuctionBidSize));

        assertEq(proposal.earliestExecutionTime(), 0);
        assertTrue(!proposal.executed());
    }

    function testFailProposalEmptyInitialDebtMintedTokens() public {
        debtAuctionBidSize  = 1 ether;
        proposal = new GlobalAuctionParamsProposal(address(pause), address(govActions), address(accountingEngine), initialDebtMintedTokens, debtAuctionBidSize);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalEmptyDebtAuctionBidSize() public {
        initialDebtMintedTokens = 1000 ether;

        proposal = new GlobalAuctionParamsProposal(address(pause), address(govActions), address(accountingEngine), initialDebtMintedTokens, debtAuctionBidSize);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testFailProposalBothEmpty() public {
        proposal = new GlobalAuctionParamsProposal(address(pause), address(govActions), address(accountingEngine), initialDebtMintedTokens, debtAuctionBidSize);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
    }

    function testGlobalAuctionParamsProposal() public {
        initialDebtMintedTokens = 1000 ether;
        debtAuctionBidSize  = 1 ether;

        proposal = new GlobalAuctionParamsProposal(address(pause), address(govActions), address(accountingEngine), initialDebtMintedTokens, debtAuctionBidSize);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();

        assertEq(accountingEngine.initialDebtAuctionMintedTokens(), initialDebtMintedTokens);
        assertEq(accountingEngine.debtAuctionBidSize(), debtAuctionBidSize);
    }

    function testFailRepeatedProposalExecution() public {
        initialDebtMintedTokens = 1000 ether;
        debtAuctionBidSize  = 1 ether;

        proposal = new GlobalAuctionParamsProposal(address(pause), address(govActions), address(accountingEngine), initialDebtMintedTokens, debtAuctionBidSize);
        setUpAccess();
        proposal.scheduleProposal();
        hevm.warp(now + earliestExecutionTime);

        proposal.executeProposal();
        proposal.executeProposal();
    }
}
