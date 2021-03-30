pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "merkle-distributor/MerkleDistributorFactory.sol";

import "../MerkleDistributionManagement.sol";

contract MerkleDistributionManagementTest is DSTest {
    MerkleDistributionManagement proxy;
    MerkleDistributorFactory factory;
    DSToken rewardsToken;
    bytes32 merkleRoot = bytes32("0xabc");

    function setUp() public {
        rewardsToken      = new DSToken("FLX", "FLX");
        proxy             = new MerkleDistributionManagement();
        factory           = new MerkleDistributorFactory(address(rewardsToken));

        rewardsToken.mint(address(factory), 1000 ether);
    }

    function test_deployDistributor() public {
        (bool success, ) =  address(proxy).delegatecall(abi.encodeWithSignature(
            "deployDistributor(address,bytes32,uint256,bool)",
            address(factory),
            merkleRoot,
            100 ether,
            true
        ));
        assertTrue(success);

        MerkleDistributor dist = MerkleDistributor(factory.distributors(1));

        assertEq(factory.nonce(), 1);
        assertEq(rewardsToken.balanceOf(address(factory)), 900 ether);
        assertEq(dist.token(), address(rewardsToken));
        assertEq(dist.owner(), address(factory));
        assertEq(dist.merkleRoot(), merkleRoot);
        assertEq(dist.deploymentTime(), now);
        assertEq(rewardsToken.balanceOf(address(dist)), 100 ether);
    }

    function test_sendTokensToDistributor() public {
        (bool success, ) =  address(proxy).delegatecall(abi.encodeWithSignature(
            "deployDistributor(address,bytes32,uint256,bool)",
            address(factory),
            merkleRoot,
            100 ether,
            false
        ));
        assertTrue(success);

        MerkleDistributor dist = MerkleDistributor(factory.distributors(1));

        assertEq(rewardsToken.balanceOf(address(factory)), 1000 ether);
        assertEq(rewardsToken.balanceOf(address(dist)), 0);

        (success, ) =  address(proxy).delegatecall(abi.encodeWithSignature(
            "sendTokensToDistributor(address,uint256)",
            address(factory),
            1
        ));
        assertTrue(success);
        assertEq(rewardsToken.balanceOf(address(factory)), 900 ether);
        assertEq(rewardsToken.balanceOf(address(dist)), 100 ether);
    }

    function test_sendTokensToCustom() public {
        (bool success, ) =  address(proxy).delegatecall(abi.encodeWithSignature(
            "sendTokensToCustom(address,address,uint256)",
            address(factory),
            address(0xfab),
            1000 ether
        ));
        assertTrue(success);
        assertEq(rewardsToken.balanceOf(address(factory)), 0);
        assertEq(rewardsToken.balanceOf(address(0xfab)), 1000 ether);
    }

    function test_dropDistributorAuth() public {
        (bool success, ) =  address(proxy).delegatecall(abi.encodeWithSignature(
            "deployDistributor(address,bytes32,uint256,bool)",
            address(factory),
            merkleRoot,
            100 ether,
            true
        ));
        assertTrue(success);

        MerkleDistributor dist = MerkleDistributor(factory.distributors(1));

        assertEq(dist.authorizedAccounts(address(factory)), 1);

        (success, ) =  address(proxy).delegatecall(abi.encodeWithSignature(
            "dropDistributorAuth(address,uint256)",
            address(factory),
            1
        ));
        assertTrue(success);
        assertEq(dist.authorizedAccounts(address(factory)), 0);
    }

    function test_getTokensBackFromDistributor() public {
        (bool success, ) =  address(proxy).delegatecall(abi.encodeWithSignature(
            "deployDistributor(address,bytes32,uint256,bool)",
            address(factory),
            merkleRoot,
            100 ether,
            true
        ));
        assertTrue(success);

        MerkleDistributor dist = MerkleDistributor(factory.distributors(1));

        assertEq(rewardsToken.balanceOf(address(factory)), 900 ether);
        assertEq(rewardsToken.balanceOf(address(dist)), 100 ether);

        (success, ) =  address(proxy).delegatecall(abi.encodeWithSignature(
            "getBackTokensFromDistributor(address,uint256,uint256)",
            address(factory),
            1,
            50 ether
        ));
        assertTrue(success);
        assertEq(rewardsToken.balanceOf(address(factory)), 950 ether);
        assertEq(rewardsToken.balanceOf(address(dist)), 50 ether);
    }
}
