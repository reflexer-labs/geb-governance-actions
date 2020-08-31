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

contract LiquidationCRatioProposal {
    PauseLike public pause;
    address   public target;
    bytes32   public codeHash;
    uint256   public earliestExecutionTime;
    address   public oracleRelayer;
    bytes32[] public collateralTypes;
    uint256[] public liquidationCRatios;
    bool      public executed;

    /**
    * @notice Constructor, sets up proposal
    * @param _pause - DSPause
    * @param _target - govActions
    * @param _oracleRelayer - target of proposal
    * @param _collateralTypes - Array of types of collaterals
    * @param _liquidationCRatios - Array of new liquidation collateral ratios
    **/
    constructor(address _pause, address _target, address _oracleRelayer, bytes32[] memory _collateralTypes, uint256[] memory _liquidationCRatios) public {
        require(_collateralTypes.length == _liquidationCRatios.length, 
            "mismatched lengths of collateralTypes, _liquidationCRatios");
        require(_collateralTypes.length > 0, "no collateral types");

        pause = PauseLike(_pause);
        target  = _target;
        oracleRelayer   = _oracleRelayer;
        collateralTypes  = _collateralTypes;
        liquidationCRatios = _liquidationCRatios;
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
                    oracleRelayer,
                    collateralTypes[i],
                    bytes32("liquidationCRatio"),
                    liquidationCRatios[i]
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
                    oracleRelayer,
                    collateralTypes[i],
                    bytes32("liquidationCRatio"),
                    liquidationCRatios[i]
            );
            pause.executeTransaction(target, codeHash, signature, earliestExecutionTime);
        }

        executed = true;
    }
}
