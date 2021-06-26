// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

contract TuringswapWhitelist { 

    bool public paused = false;

    mapping (address => bool) private whitelistedMap;
    mapping (address => bool) public requestAccessList;

    event Whitelisted(address indexed account, bool isWhitelisted);
    event onRequestAccess(address indexed account);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    address public owner;
    
    modifier onlyOwner()
    {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }

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

    function stopWhitelist() public onlyOwner {
        paused = true;
    }
    
    function openWhitelist() public onlyOwner {
        paused = false;
    }

    function whitelisted(address _address) public view returns (bool) {
        if (paused) {
            return false;
        }

        return whitelistedMap[_address];
    }

    function addAddress(address _address) public onlyOwner {
        require(whitelistedMap[_address] != true, "WHITELISTED");
        whitelistedMap[_address] = true; //open access to Turing protocol
        requestAccessList[_address] = false; //remove from request list
        emit Whitelisted(_address, true);
    }

    function removeAddress(address _address) public onlyOwner {
        require(whitelistedMap[_address] != false, "NOT_WHITELISTED");
        whitelistedMap[_address] = false; //disable access to Turing protocol
        requestAccessList[_address] = false; //remove from request list
        emit Whitelisted(_address, false);
    }
    
    function requestAccess() public {
        require(requestAccessList[msg.sender] != true, "YOU_ARE_IN_THE_LIST");
        requestAccessList[msg.sender] = true;
        emit onRequestAccess(msg.sender);
    }
}