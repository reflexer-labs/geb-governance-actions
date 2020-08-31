pragma solidity >=0.6.7;

abstract contract PauseLike {
    function delay() public view virtual returns (uint256);
    function scheduleTransaction(address, bytes32, bytes memory, uint256) public virtual;
    function executeTransaction(address, bytes32, bytes memory, uint256) public virtual;
}

abstract contract ConfigLike {
    function modifyParameters(bytes32 collateralType, uint256 position, uint256 taxPercentage, address receiverAccount) public virtual;
}

contract Proposal {
    function deploy(
        address taxCollector, 
        bytes32[] calldata collateralTypes, 
        uint256[] calldata positions, 
        uint256[] calldata percentages, 
        address[] calldata secondaryReceivers) 
        external 
    {

        for (uint i = 0; i < collateralTypes.length; i++) 
            ConfigLike(taxCollector).modifyParameters(collateralTypes[i], positions[i], percentages[i], secondaryReceivers[i]); 
    }
}

contract SecondaryTaxReceiversProposal {
    bool      public executed;
    address   public pause;
    address   public proposal;
    bytes32   public codeHash;
    uint256   public earliestExecutionTime;
    uint256   public expiration;
    bytes     public signature;

    constructor(
        address _pause, 
        address taxCollector, 
        bytes32[] memory collateralTypes, 
        uint256[] memory positions, 
        uint256[] memory percentages, 
        address[] memory secondaryReceivers) 
        public 
    {
        require(collateralTypes.length == positions.length && 
                collateralTypes.length == percentages.length &&
                collateralTypes.length == secondaryReceivers.length, "mismatched lengths of inputs");
        require(collateralTypes.length > 0, "no collateral types");

        pause = _pause;
        address deployer = address(new Proposal());
        signature = 
            abi.encodeWithSignature("deploy(address,bytes32[],uint256[],uint256[],address[])", 
            taxCollector, 
            collateralTypes,
            positions,
            percentages,
            secondaryReceivers);
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