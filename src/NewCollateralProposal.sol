pragma solidity >=0.6.7;

abstract contract SpotterLike {
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

contract IlkDeployer {
    function deploy(bytes32 ilk_, address[8] calldata addrs, uint[5] calldata values) external {
        // addrs[0] = vat
        // addrs[1] = cat
        // addrs[2] = jug
        // addrs[3] = spotter
        // addrs[4] = end
        // addrs[5] = join
        // addrs[6] = orcl
        // addrs[7] = flip
        // values[0] = line
        // values[1] = mat
        // values[2] = duty
        // values[3] = chop
        // values[4] = lump

        ConfigLike(addrs[3]).modifyParameters(ilk_, "orcl", address(addrs[6])); // vat.file(ilk_, "pip", pip);

        ConfigLike(addrs[1]).modifyParameters(ilk_, "collateralAuctionHouse", addrs[7]); // cat.file(ilk_, "flip", flip);
        ConfigLike(addrs[0]).initializeCollateralType(ilk_); // vat.init(ilk_);
        ConfigLike(addrs[2]).initializeCollateralType(ilk_); // jug.init(ilk_);

        ConfigLike(addrs[0]).addAuthorization(addrs[5]); // vat.rely(join);
        ConfigLike(addrs[7]).addAuthorization(addrs[1]); // flip.rely(cat);
        ConfigLike(addrs[7]).addAuthorization(addrs[4]); // flip.rely(end);

        ConfigLike(addrs[0]).modifyParameters(ilk_, "debtCeiling", values[0]); // vat.file(ilk_, "line", line);
        ConfigLike(addrs[1]).modifyParameters(ilk_, "collateralToSell", values[4]); // cat.file(ilk_, "lump", lump);
        ConfigLike(addrs[1]).modifyParameters(ilk_, "liquidationPenalty", values[3]); // cat.file(ilk_, "chop", chop);
        ConfigLike(addrs[2]).modifyParameters(ilk_, "stabilityFee", values[2]); // jug.file(ilk_, "duty", duty);
        ConfigLike(addrs[3]).modifyParameters(ilk_, "safetyCRatio", values[1]); // spotter.file(ilk_, "mat", mat);
        ConfigLike(addrs[3]).modifyParameters(ilk_, "liquidationCRatio", values[1]); // added, check

        SpotterLike(addrs[3]).updateCollateralPrice(ilk_); // spotter.poke(ilk_);
    }
}

contract DssAddIlkSpell {
    bool      public done;
    address   public pause;

    address   public action;
    bytes32   public tag;
    uint256   public eta;
    bytes     public sig;

    constructor(bytes32 ilk_, address pause_, address[8] memory addrs, uint[5] memory values) public {
        pause = pause_;
        address ilkDeployer = address(new IlkDeployer());
        sig = abi.encodeWithSignature("deploy(bytes32,address[8],uint256[5])", ilk_, addrs, values);
        bytes32 _tag; assembly { _tag := extcodehash(ilkDeployer) }
        action = ilkDeployer;
        tag = _tag;
    }

    function schedule() external {
        require(eta == 0, "spell-already-scheduled");
        eta = now + PauseLike(pause).delay();
        PauseLike(pause).scheduleTransaction(action, tag, sig, eta);
    }

    function cast() public {
        require(!done, "spell-already-cast");
        done = true;
        PauseLike(pause).executeTransaction(action, tag, sig, eta);
    }
}
