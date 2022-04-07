// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IBEP20.sol';

contract TuringswapSafu { 
 
    address public owner;
    
    modifier onlyOwner()
    {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event onWithdraw(address _to, uint256 _amount);

    constructor() public {
         owner = msg.sender;
    }
    
    /**
    * @dev Transfers ownership of the contract to a new account (`newOwner`).
    * Can only be called by the current owner.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function withdraw(IBEP20 _token, uint256 _amount) public onlyOwner {

        require(address(_token) != address(0), "INVALID_TOKEN");
        
        _token.transfer(owner, _amount);

        emit onWithdraw(owner, _amount);
    }
}