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

contract AccessManagementProposal {
    PauseLike public pause;
    address   public target;
    address[] public gebModules;
    address[] public addresses;
    uint8[]   public grantAccess;    
    uint256   public earliestExecutionTime;
    bytes32   public codeHash;
    bool      public executed;

    /**
    * @notice Constructor, sets up proposal
    * @param _pause - DSPause
    * @param _target - govActions
    * @param _gebModules - Geb modules in which access will be edited
    * @param _addresses - List of addresses to grant/revoke access
    * @param _grantAccess - set to 1 to grant access, 0 to revokes
    **/
    constructor(address _pause, address _target, address[] memory _gebModules, address[] memory _addresses, uint8[] memory _grantAccess) public {
        require(
            _gebModules.length == _addresses.length && _addresses.length  == _grantAccess.length, 
            "mismatched lengths of gebModules, addresses, and grantAccess");
        require(_gebModules.length > 0, "no modules listed");

        pause = PauseLike(_pause);
        target  = _target;
        gebModules = _gebModules;
        addresses  = _addresses;
        grantAccess = _grantAccess;

        bytes32 _codeHash;
        assembly { _codeHash := extcodehash(_target) }
        codeHash = _codeHash;
    }

    function scheduleProposal() public {
        require(earliestExecutionTime == 0, "proposal-already-scheduled");
        earliestExecutionTime = now + PauseLike(pause).delay();

        // ConfigLike(addrs[0]).addAuthorization(addrs[5]); // target.addAuthorization(address);
        for (uint256 i = 0; i < gebModules.length; i++) {
            bytes memory signature =
                abi.encodeWithSignature(
                    (grantAccess[i] != 0) ? "addAuthorization(address,address)" : "removeAuthorization(address,address)",
                    gebModules[i],
                    addresses[i]
            );

            pause.scheduleTransaction(target, codeHash, signature, earliestExecutionTime);
        }
    }

    function executeProposal() public {
        require(!executed, "proposal-already-executed");

        for (uint256 i = 0; i < gebModules.length; i++) {
            bytes memory signature =
                abi.encodeWithSignature(
                    (grantAccess[i] != 0) ? "addAuthorization(address,address)" : "removeAuthorization(address,address)",
                    gebModules[i],
                    addresses[i]
            );
            
            pause.executeTransaction(target, codeHash, signature, earliestExecutionTime);
        }

        executed = true;
    }
}
