// spell.sol - An un-owned object that performs one action one time only

// Copyright (C) 2017, 2018 DappHub, LLC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.6.7;

import "ds-exec/exec.sol";
import "ds-note/note.sol";

contract Proposal is DSExec, DSNote {
    address public target;
    uint256 public value;
    bytes   public data;
    bool    public executed;

    constructor(address target_, uint256 value_, bytes memory data_) public {
        target = target_;
        value = value_;
        data = data_;
    }
    // Only marked 'done' if CALL succeeds (not exceptional condition).
    function executeProposal() public note {
        require(!executed, "proposal-already-executed");
        exec(target, data, value);
        executed = true;
    }
}

contract ProposalFactory {
    function newProposal(address target, uint256 value, bytes memory data) public returns (Proposal) {
        return new Proposal(target, value, data);
    }
}
