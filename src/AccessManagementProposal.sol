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

    /**
    * @notice Adds and removes auths from any of the contracts
    *  
    **/
contract AccessManafementProposal {
    PauseLike public pause;
    address[] public gebModules;
    uint256   public earliestExecutionTime;
    address[] public addresses;
    bool[] public grantAccess;
    bool      public executed;

    constructor(address _pause, address[] memory _gebModules, address[] memory _addresses, bool[] memory _grantAccess) public {
        require(
            _gebModules.length == _addresses.length && _addresses.length  == _grantAccess.length, 
            "mismatched lengths of gebModules, addresses, and grantAccess");
        require(_gebModules.length > 0, "no modules listed");

        pause = PauseLike(_pause);
        gebModules = _gebModules;
        addresses  = _addresses;
        grantAccess = _grantAccess;
    }

    function scheduleProposal() public {
        require(earliestExecutionTime == 0, "proposal-already-scheduled");
        earliestExecutionTime = now + PauseLike(pause).delay();

        bytes32 _codeHash;
        address _module;

        // ConfigLike(addrs[0]).addAuthorization(addrs[5]); // target.addAuthorization(address);
        for (uint256 i = 0; i < gebModules.length; i++) {
            bytes memory signature =
                abi.encodeWithSignature(
                    (grantAccess[i]) ? "addAuthorization(address)" : "removeAuthorization(address)",
                    addresses[i]
            );

            _module = gebModules[i];
            assembly { _codeHash := extcodehash(_module) }
            pause.scheduleTransaction(gebModules[i], _codeHash, signature, earliestExecutionTime);
        }
    }

    function executeProposal() public {
        require(!executed, "proposal-already-executed");

        bytes32 _codeHash;
        address _module;

        for (uint256 i = 0; i < gebModules.length; i++) {
            bytes memory signature =
                abi.encodeWithSignature(
                    (grantAccess[i]) ? "addAuthorization(address)" : "removeAuthorization(address)",
                    addresses[i]
            );
            
            _module = gebModules[i];
            assembly { _codeHash := extcodehash(_module) }
            pause.executeTransaction(gebModules[i], _codeHash, signature, earliestExecutionTime);
        }

        executed = true;
    }
}
