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

abstract contract PauseLike {
    function delay() public view virtual returns (uint256);
    function scheduleTransaction(address, bytes32, bytes memory, uint256) public virtual;
    function executeTransaction(address, bytes32, bytes memory, uint256) public virtual;
}

contract DebtCeilingProposal {
    PauseLike public pause;
    address   public target; // plan
    bytes32   public codeHash; // tag
    uint256   public earliestExecutionTime; // eta
    bytes     public signature; // sig
    address   public cdpEngine; // vay
    bytes32   public collateralType; // ilk
    uint256   public debtCeiling; // line
    bool      public executed; // done

    constructor(address _pause, address _target, address _cdpEngine, bytes32 _collateralType, uint256 _debtCeiling) public {
        pause = PauseLike(_pause);
        target  = _target;
        cdpEngine   = _cdpEngine;
        collateralType   = _collateralType;
        debtCeiling  = _debtCeiling;
        signature   = abi.encodeWithSignature(
                "modifyParameters(address,bytes32,bytes32,uint256)",
                _cdpEngine,
                _collateralType,
                bytes32("debtCeiling"),
                _debtCeiling
        );
        bytes32 _codeHash;
        assembly { _codeHash := extcodehash(_target) }
        codeHash = _codeHash;
    }

    function scheduleProposal() public { // schedule
        require(earliestExecutionTime == 0, "proposal-already-scheduled");
        earliestExecutionTime = now + PauseLike(pause).delay();

        pause.scheduleTransaction(target, codeHash, signature, earliestExecutionTime);
    }

    function executeProposal() public { // exec
        require(!executed, "proposal-already-executed");

        pause.executeTransaction(target, codeHash, signature, earliestExecutionTime);

        executed = true;
    }
}

