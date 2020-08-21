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

import "../MultiLineSpell.sol";

contract MultiLineSpellTest is GebDeployTestBase {
    MultiLineSpell spell;
    bytes32[] ilks;
    uint256[] lines;
    uint256 wait;

    function setUp() public override {
        super.setUp();
        deployStable("");
        wait = pause.delay();
    }

    function elect() private {
        DSRoles role = DSRoles(address(pause.authority()));
        role.setRootUser(address(spell), true);
    }

    function testConstructor() public {
        ilks  = [ bytes32("GOLD"), bytes32("GELD") ];
        lines = [ 100, 200 ];

        spell = new MultiLineSpell(address(pause), address(govActions), address(cdpEngine), ilks, lines);

        for (uint256 i = 0; i < ilks.length; i++) {
            assertEq(spell.ilks(i), ilks[i]);
        }
        for (uint256 i = 0; i < lines.length; i++) {
            assertEq(spell.lines(i), lines[i]);
        }

        assertEq(address(spell.pause()), address(pause));
        assertEq(address(spell.plan()),  address(govActions));
        assertEq(address(spell.vat()),   address(cdpEngine));

        assertEq(spell.eta(), 0);
        assertTrue(!spell.done());
    }

    function testFailCastEmptyIlks() public {
        lines = [ 1 ];
        spell = new MultiLineSpell(address(pause), address(govActions), address(cdpEngine), ilks, lines);
        elect();
        spell.schedule();
        hevm.warp(now + wait);

        spell.cast();
    }

    function testFailCastEmptyLines() public {
        ilks = [ bytes32("GOLD") ];
        spell = new MultiLineSpell(address(pause), address(govActions), address(cdpEngine), ilks, lines);
        elect();
        spell.schedule();
        hevm.warp(now + wait);

        spell.cast();
    }

    function testFailCastBothEmpty() public {
        spell = new MultiLineSpell(address(pause), address(govActions), address(cdpEngine), ilks, lines);
        elect();
        spell.schedule();
        hevm.warp(now + wait);

        spell.cast();
    }

    function testFailCastMismatchedLengths() public {
        ilks = new bytes32[](1);
        lines = new uint256[](2);
        spell = new MultiLineSpell(address(pause), address(govActions), address(cdpEngine), ilks, lines);
        elect();
        spell.schedule();
        hevm.warp(now + wait);

        spell.cast();
    }

    function testMultiLineCast() public {
        ilks  = [ bytes32("GOLD"), bytes32("GELD") ];
        lines = [ 100, 200 ];

        spell = new MultiLineSpell(address(pause), address(govActions), address(cdpEngine), ilks, lines);
        elect();
        spell.schedule();
        hevm.warp(now + wait);

        spell.cast();

        for (uint8 i = 0; i < ilks.length; i++) {
            (,,, uint256 l,,) = cdpEngine.collateralTypes(ilks[i]);
            assertEq(lines[i], l);
        }
    }

    function testFailRepeatedCast() public {
        ilks  = [ bytes32("GOLD"), bytes32("GELD") ];
        lines = [ 100, 200 ];

        spell = new MultiLineSpell(address(pause), address(govActions), address(cdpEngine), ilks, lines);
        elect();
        spell.schedule();
        hevm.warp(now + wait);

        spell.cast();
        spell.cast();
    }
}
