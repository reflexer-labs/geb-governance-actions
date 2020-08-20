pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./GebGovernanceActions.sol";

contract GebGovernanceActionsTest is DSTest {
    GebGovernanceActions actions;

    function setUp() public {
        actions = new GebGovernanceActions();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
