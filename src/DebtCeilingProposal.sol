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

contract LineSpell {
    PauseLike public pause;
    address   public plan;
    bytes32   public tag;
    uint256   public eta;
    bytes     public sig;
    address   public vat;
    bytes32   public ilk;
    uint256   public line;
    bool      public done;

    constructor(address _pause, address _plan, address _vat, bytes32 _ilk, uint256 _line) public {
        pause = PauseLike(_pause);
        plan  = _plan;
        vat   = _vat;
        ilk   = _ilk;
        line  = _line;
        sig   = abi.encodeWithSignature(
                "modifyParameters(address,bytes32,bytes32,uint256)",
                vat,
                ilk,
                bytes32("debtCeiling"),
                line
        );
        bytes32 _tag;
        assembly { _tag := extcodehash(_plan) }
        tag = _tag;
    }

    function schedule() public {
        require(eta == 0, "spell-already-scheduled");
        eta = now + PauseLike(pause).delay();

        pause.scheduleTransaction(plan, tag, sig, eta);
    }

    function cast() public {
        require(!done, "spell-already-cast");

        pause.executeTransaction(plan, tag, sig, eta);

        done = true;
    }
}

