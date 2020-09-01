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

contract GlobalAuctionParamsProposal {
    PauseLike public pause;
    address   public target;
    bytes32   public codeHash;
    uint256   public earliestExecutionTime;
    address   public accountingEngine;
    uint256   public initialDebtMintedTokens;
    uint256   public debtAuctionBidSize;
    bool      public executed;

    /**
    * @notice Constructor, sets up proposal for updating global auction parameters
    * @param _pause - DSPause
    * @param _target - target of proposal (govActions)
    * @param _accountingEngine - accountingEngine
    * @param _initialDebtMintedTokens - initialDebtMintedTokens
    * @param _debtAuctionBidSize - New debtAuctionBidSize
    **/
    constructor(address _pause, address _target, address _accountingEngine, uint256 _initialDebtMintedTokens, uint256 _debtAuctionBidSize) public {
        require(_initialDebtMintedTokens > 0, "initialDebtMintedTokens = 0");
        require(_debtAuctionBidSize > 0, "debtAuctionBidSize = 0");

        pause = PauseLike(_pause);
        target  = _target;
        accountingEngine   = _accountingEngine;
        initialDebtMintedTokens  = _initialDebtMintedTokens;
        debtAuctionBidSize = _debtAuctionBidSize;
        bytes32 _codeHash;
        assembly { _codeHash := extcodehash(_target) }
        codeHash = _codeHash;
    }

    function scheduleProposal() public {
        require(earliestExecutionTime == 0, "proposal-already-scheduled");
        earliestExecutionTime = now + PauseLike(pause).delay();

        bytes memory signature =
            abi.encodeWithSignature(
                "modifyParameters(address,bytes32,uint256)",
                accountingEngine,
                bytes32("initialDebtAuctionMintedTokens"),
                initialDebtMintedTokens
        );
        pause.scheduleTransaction(target, codeHash, signature, earliestExecutionTime);

        signature = abi.encodeWithSignature(
                "modifyParameters(address,bytes32,uint256)",
                accountingEngine,
                bytes32("debtAuctionBidSize"),
                debtAuctionBidSize
        );
        pause.scheduleTransaction(target, codeHash, signature, earliestExecutionTime);
    }

    function executeProposal() public {
        require(!executed, "proposal-already-executed");

        bytes memory signature =
            abi.encodeWithSignature(
                "modifyParameters(address,bytes32,uint256)",
                accountingEngine,
                bytes32("initialDebtAuctionMintedTokens"),
                initialDebtMintedTokens
        );
        pause.executeTransaction(target, codeHash, signature, earliestExecutionTime);

        signature = abi.encodeWithSignature(
                "modifyParameters(address,bytes32,uint256)",
                accountingEngine,
                bytes32("debtAuctionBidSize"),
                debtAuctionBidSize
        );
        pause.executeTransaction(target, codeHash, signature, earliestExecutionTime);

        executed = true;
    }
}