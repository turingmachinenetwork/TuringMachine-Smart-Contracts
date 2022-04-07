// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

contract turingWhitelist { 
        bool public paused = false;

        mapping (address => bool) private whitelisted;
        mapping (address => bool) public requestAccessList;

        event Whitelisted(address indexed account, bool isWhitelisted);
        event onRequest(address indexed account);
    
        address public owner;    
        modifier onlyOwner()
        {
                require(msg.sender == owner, 'INVALID_PERMISSION');
                _;
        }
        constructor() public {
                owner = msg.sender;
        }
        function pauseWhitelist() public onlyOwner 
        {
                paused = true;
        }
        function enableWhitelist() public onlyOwner 
        {
                paused = false;
        }

        function isWhitelisted(address _address) public view returns (bool) 
        {
                if (paused) {
                        return false;
                }
                return whitelisted[_address];
        }
        function add(address _address) public onlyOwner 
        {
                require(whitelisted[_address] != true, "WHITELISTED");
                whitelisted[_address] = true; 
                requestAccessList[_address] = false; 
                emit Whitelisted(_address, true);
        }
        function remove(address _address) public onlyOwner 
        {
                require(whitelisted[_address] != false, "NOT_WHITELISTED");
                whitelisted[_address] = false; 
                requestAccessList[_address] = false; 
                emit Whitelisted(_address, false);
        }
        function request() public 
        {
                require(requestAccessList[msg.sender] != true, "REQUESTED");
                requestAccessList[msg.sender] = true;
                emit onRequest(msg.sender);
        }
}