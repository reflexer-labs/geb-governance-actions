pragma solidity >=0.6.7;

abstract contract PauseLike {
    function delay() public view virtual returns (uint256);
    function scheduleTransaction(address, bytes32, bytes memory, uint256) public virtual;
    function executeTransaction(address, bytes32, bytes memory, uint256) public virtual;
}

abstract contract ConfigLike {
    function modifyParameters(bytes32, uint) public virtual;
    function addAuthorization(address) public virtual;
}

contract Proposal {
    function deploy(address taxCollector, uint256 globalStabilityFee) external {

        ConfigLike(taxCollector).modifyParameters("globalStabilityFee", globalStabilityFee); 
    }
}

contract GlobalStabilityFeeProposal {
    bool      public executed;
    address   public pause;

    address   public proposal;
    bytes32   public codeHash;
    uint256   public earliestExecutionTime;
    bytes     public signature;

    constructor(address _pause, address taxCollector, uint256 globalStabilityFee) public {
        pause = _pause;
        address deployer = address(new Proposal());
        signature = abi.encodeWithSignature("deploy(address,uint256)", taxCollector, globalStabilityFee);
        bytes32 _codeHash; assembly { _codeHash := extcodehash(deployer) }
        proposal = deployer;
        codeHash = _codeHash;
    }

    function scheduleProposal() external {
        require(earliestExecutionTime == 0, "proposal-already-scheduled");
        earliestExecutionTime = now + PauseLike(pause).delay();
        PauseLike(pause).scheduleTransaction(proposal, codeHash, signature, earliestExecutionTime);
    }

    function executeProposal() public {
        require(!executed, "proposal-already-executed");
        executed = true;
        PauseLike(pause).executeTransaction(proposal, codeHash, signature, earliestExecutionTime);
    }
}