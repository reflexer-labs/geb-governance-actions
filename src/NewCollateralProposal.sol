pragma solidity >=0.6.7;

abstract contract OracleRelayerLike {
    function updateCollateralPrice(bytes32) public virtual;
}

abstract contract PauseLike {
    function delay() public view virtual returns (uint256);
    function scheduleTransaction(address, bytes32, bytes memory, uint256) public virtual;
    function executeTransaction(address, bytes32, bytes memory, uint256) public virtual;
}

abstract contract ConfigLike {
    function initializeCollateralType(bytes32) public virtual;
    function modifyParameters(bytes32, bytes32, address) public virtual;
    function modifyParameters(bytes32, bytes32, uint) public virtual;
    function addAuthorization(address) public virtual;
}

contract CollateralDeployer {
    function deploy(bytes32 _collateralType, address[8] calldata addrs, uint[6] calldata values) external {
        // addrs[0] = cdpEngine
        // addrs[1] = liquidationEngine
        // addrs[2] = taxCollector
        // addrs[3] = oracleRelayer
        // addrs[4] = globalSettlement
        // addrs[5] = join
        // addrs[6] = orcl
        // addrs[7] = collateralAuctionHouse
        // values[0] = debtCeiling
        // values[1] = safetyCRatio
        // values[2] = liquidationCRatio
        // values[3] = stabilityFee
        // values[4] = liquidationPenalty
        // values[5] = liquidationQuantity

        ConfigLike(addrs[3]).modifyParameters(_collateralType, "orcl", address(addrs[6])); // cdpEngine.modifyParameters(...);

        ConfigLike(addrs[1]).modifyParameters(_collateralType, "collateralAuctionHouse", addrs[7]); // liquidationEngine.modifyParameters(...);
        ConfigLike(addrs[0]).initializeCollateralType(_collateralType); // cdpEngine.initializeCollateralType(collateralType);
        ConfigLike(addrs[2]).initializeCollateralType(_collateralType); // taxCollector.initializeCollateralType(collateralType);

        ConfigLike(addrs[0]).addAuthorization(addrs[5]); // cdpEngine.addAuthorization(join);
        ConfigLike(addrs[1]).addAuthorization(addrs[7]); // liquidationEngine.addAuthorization(collateralAuctionHouse);
        ConfigLike(addrs[7]).addAuthorization(addrs[1]); // collateralAuctionHouse.addAuthorization(liquidationEngine);
        ConfigLike(addrs[7]).addAuthorization(addrs[4]); // collateralAuctionHouse.addAuthorization(auctionDeadline);

        ConfigLike(addrs[0]).modifyParameters(_collateralType, "debtCeiling", values[0]); // cdpEngine.modifyParameters(...);
        ConfigLike(addrs[1]).modifyParameters(_collateralType, "liquidationQuantity", values[5]); // liquidationEngine.modifyParameters(...);
        ConfigLike(addrs[1]).modifyParameters(_collateralType, "liquidationPenalty", values[4]); // liquidationEngine.modifyParameters(...);
        ConfigLike(addrs[2]).modifyParameters(_collateralType, "stabilityFee", values[3]); // taxCollector.modifyParameters(...);            
        ConfigLike(addrs[3]).modifyParameters(_collateralType, "safetyCRatio", values[1]); // oracleRelayer.modifyParameters(...);
        ConfigLike(addrs[3]).modifyParameters(_collateralType, "liquidationCRatio", values[2]); // liquidationEngine.modifyParameters(...);

        OracleRelayerLike(addrs[3]).updateCollateralPrice(_collateralType); // oracleRelayer.updateCollateralPrice(collateralType);
    }
}

contract NewCollateralProposal {
    bool      public executed;
    address   public pause;

    address   public collateralDeployer;
    bytes32   public codeHash;
    uint256   public earliestExecutionTime;
    bytes     public signature;

    /**
    * @notice Constructor, sets up proposal to change multiple collateral debtCeilings
    * @param collateralType_ - new collateral type
    * @param pause_ - DSPause
    * @param addrs - addresses of supporting contracts, check comments in CollateralDeployer for details
    * @param values - parameters of new collateral, check comments in CollateralDeployer for details
    **/
    constructor(bytes32 collateralType_, address pause_, address[8] memory addrs, uint[6] memory values) public {
        pause = pause_;
        address deployer = address(new CollateralDeployer());
        signature = abi.encodeWithSignature("deploy(bytes32,address[8],uint256[6])", collateralType_, addrs, values);
        bytes32 _codeHash; assembly { _codeHash := extcodehash(deployer) }
        collateralDeployer = deployer;
        codeHash = _codeHash;
    }

    function scheduleProposal() external {
        require(earliestExecutionTime == 0, "proposal-already-scheduled");
        earliestExecutionTime = now + PauseLike(pause).delay();
        PauseLike(pause).scheduleTransaction(collateralDeployer, codeHash, signature, earliestExecutionTime);
    }

    function executeProposal() public {
        require(!executed, "proposal-already-executed");
        executed = true;
        PauseLike(pause).executeTransaction(collateralDeployer, codeHash, signature, earliestExecutionTime);
    }
}
