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

contract GlobalSettlementProposal {
    PauseLike public pause;
    address   public target; 
    address   public globalSettlement;
    uint256   public earliestExecutionTime;
    bytes32   public codeHash;
    bool      public executed;

    /**
    * @notice Constructor, sets up proposal to initiate global settlement
    * @param _pause - DSPause
    * @param _target - govActions
    * @param _globalSettlement - global settlement contract
    **/
    constructor(address _pause, address _target, address _globalSettlement) public {

        pause = PauseLike(_pause);
        target  = _target;
        globalSettlement = _globalSettlement;

        bytes32 _codeHash;
        assembly { _codeHash := extcodehash(_target) }
        codeHash = _codeHash;
    }

    function scheduleProposal() public {
        require(earliestExecutionTime == 0, "proposal-already-scheduled");
        earliestExecutionTime = now + PauseLike(pause).delay();

        bytes memory signature =
                abi.encodeWithSignature("shutdownSystem(address)", globalSettlement);

        pause.scheduleTransaction(target, codeHash, signature, earliestExecutionTime);
    }

    function executeProposal() public {
        require(!executed, "proposal-already-executed");

        bytes memory signature =
                abi.encodeWithSignature("shutdownSystem(address)", globalSettlement);

        pause.executeTransaction(target, codeHash, signature, earliestExecutionTime);

        executed = true;
    }
}
