pragma solidity >=0.6.7;

abstract contract PauseLike {
    function delay() public view virtual returns (uint256);
    function scheduleTransaction(address, bytes32, bytes memory, uint256) public virtual;
    function executeTransaction(address, bytes32, bytes memory, uint256) public virtual;
}

abstract contract ConfigLike {
    function modifyParameters(bytes32, uint) public virtual;
    function modifyParameters(bytes32, address) public virtual;
}

contract Proposal {
    function deploy(address FixedDiscountCollateralAuctionHouse, bytes32[] calldata parameters, bytes32[] calldata data) external {

        for (uint i = 0; i < parameters.length; i++)
        if (isAddress(parameters[i]))
            ConfigLike(FixedDiscountCollateralAuctionHouse).modifyParameters(parameters[i], address(uint160(uint256(data[i]))) );
        else
            ConfigLike(FixedDiscountCollateralAuctionHouse).modifyParameters(parameters[i], uint256(data[i]));
    }

    function isAddress(bytes32 param) public pure returns (bool) {
        if  ( param == bytes32("oracleRelayer")    ||
              param == bytes32("collateralFSM")    ||
              param == bytes32("systemCoinOracle") ||
              param == bytes32("liquidationEngine") )
            return true;
    }
}

contract FixedDiscountCollateralAuctionHouseProposal {
    bool      public executed;
    address   public pause;
    address   public proposal;
    bytes32   public codeHash;
    uint256   public earliestExecutionTime;
    uint256   public expiration;
    bytes     public signature;

    /**
    * @notice Constructor, sets up proposal
    * @param _pause - DSPause
    * @param FixedDiscountCollateralAuctionHouse - FixedDiscountCollateralAuctionHouse
    * @param parameters - parameters to change
    * @param data - New values (convert both uint and addresses to bytes32)
    **/
    constructor(address _pause, address FixedDiscountCollateralAuctionHouse, bytes32[] memory parameters, bytes32[] memory data) public {
        require(parameters.length == data.length, "mismatched array lengths");
        require(parameters.length > 0, "no collateral types");

        pause = _pause;
        address deployer = address(new Proposal());
        signature = abi.encodeWithSignature("deploy(address,bytes32[],bytes32[])", FixedDiscountCollateralAuctionHouse, parameters, data);
        bytes32 _codeHash; assembly { _codeHash := extcodehash(deployer) }
        proposal = deployer;
        codeHash = _codeHash;
        expiration = now + 30 days;
    }

    function scheduleProposal() external {
        require(earliestExecutionTime == 0, "proposal-already-scheduled");
        earliestExecutionTime = now + PauseLike(pause).delay();
        PauseLike(pause).scheduleTransaction(proposal, codeHash, signature, earliestExecutionTime);
    }

    function executeProposal() public {
        require(!executed, "proposal-already-executed");
        require(now < expiration, "proposal-expired");
        executed = true;
        PauseLike(pause).executeTransaction(proposal, codeHash, signature, earliestExecutionTime);
    }
}
