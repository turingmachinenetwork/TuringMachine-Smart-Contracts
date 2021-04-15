// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

contract Ownable {
    address public owner;

    modifier onlyOwner()
    {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }

    constructor() public {
        owner = msg.sender;
    }
}