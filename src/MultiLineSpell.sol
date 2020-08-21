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

contract MultiLineSpell {
    PauseLike public pause;
    address   public plan;
    bytes32   public tag;
    uint256   public eta;
    address   public vat;
    bytes32[] public ilks;
    uint256[] public lines;
    bool      public done;

    constructor(address _pause, address _plan, address _vat, bytes32[] memory _ilks, uint256[] memory _lines) public {
        require(_ilks.length == _lines.length, "mismatched lengths of ilks, lines");
        require(_ilks.length > 0, "no ilks");

        pause = PauseLike(_pause);
        plan  = _plan;
        vat   = _vat;
        ilks  = _ilks;
        lines = _lines;
        bytes32 _tag;
        assembly { _tag := extcodehash(_plan) }
        tag = _tag;
    }

    function schedule() public {
        require(eta == 0, "spell-already-scheduled");
        eta = now + PauseLike(pause).delay();

        for (uint256 i = 0; i < ilks.length; i++) {
            bytes memory sig =
                abi.encodeWithSignature(
                    "modifyParameters(address,bytes32,bytes32,uint256)",
                    vat,
                    ilks[i],
                    bytes32("debtCeiling"),
                    lines[i]
            );
            pause.scheduleTransaction(plan, tag, sig, eta);
        }
    }

    function cast() public {
        require(!done, "spell-already-cast");

        for (uint256 i = 0; i < ilks.length; i++) {
            bytes memory sig =
                abi.encodeWithSignature(
                    "modifyParameters(address,bytes32,bytes32,uint256)",
                    vat,
                    ilks[i],
                    bytes32("debtCeiling"),
                    lines[i]
            );
            pause.executeTransaction(plan, tag, sig, eta);
        }

        done = true;
    }
}
