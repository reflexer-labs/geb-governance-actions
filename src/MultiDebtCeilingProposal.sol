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

abstract contract PauseLike {
    function delay() public view virtual returns (uint256);
    function scheduleTransaction(address, bytes32, bytes memory, uint256) public virtual;
    function executeTransaction(address, bytes32, bytes memory, uint256) public virtual;
}

contract MultiDebtCeilingProposal {
    PauseLike public pause;
    address   public target;
    bytes32   public codeHash;
    uint256   public earliestExecutionTime;
    address   public safeEngine;
    bytes32[] public collateralTypes;
    uint256[] public debtCeilings;
    bool      public executed;

    /**
    * @notice Constructor, sets up proposal to change multiple collateral debtCeilings
    * @param _pause - DSPause
    * @param _target - govActions
    * @param _safeEngine - final target of proposal
    * @param _collateralTypes - Array of types of collaterals
    * @param _debtCeilings - Array of new debt ceilings
    **/
    constructor(address _pause, address _target, address _safeEngine, bytes32[] memory _collateralTypes, uint256[] memory _debtCeilings) public {
        require(_collateralTypes.length == _debtCeilings.length, "mismatched lengths of collateralTypes, debtCeilings");
        require(_collateralTypes.length > 0, "no collateral types");

        pause = PauseLike(_pause);
        target  = _target;
        safeEngine   = _safeEngine;
        collateralTypes  = _collateralTypes;
        debtCeilings = _debtCeilings;
        bytes32 _codeHash;
        assembly { _codeHash := extcodehash(_target) }
        codeHash = _codeHash;
    }

    function scheduleProposal() public {
        require(earliestExecutionTime == 0, "proposal-already-scheduled");
        earliestExecutionTime = now + PauseLike(pause).delay();

        for (uint256 i = 0; i < collateralTypes.length; i++) {
            bytes memory signature =
                abi.encodeWithSignature(
                    "modifyParameters(address,bytes32,bytes32,uint256)",
                    safeEngine,
                    collateralTypes[i],
                    bytes32("debtCeiling"),
                    debtCeilings[i]
            );
            pause.scheduleTransaction(target, codeHash, signature, earliestExecutionTime);
        }
    }

    function executeProposal() public {
        require(!executed, "proposal-already-executed");

        for (uint256 i = 0; i < collateralTypes.length; i++) {
            bytes memory signature =
                abi.encodeWithSignature(
                    "modifyParameters(address,bytes32,bytes32,uint256)",
                    safeEngine,
                    collateralTypes[i],
                    bytes32("debtCeiling"),
                    debtCeilings[i]
            );
            pause.executeTransaction(target, codeHash, signature, earliestExecutionTime);
        }

        executed = true;
    }
}
