// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface ITuringWhitelist {
	function whitelisted(address _address) external view returns (bool);
}
interface ITuringPool {
    function harvest(address _user) external;
}

contract TuringHarvestMachine {
	ITuringWhitelist public whitelistContract; 
	address public owner;
	modifier onlyOwner()
    {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }
    modifier onlyWhitelist()
    {
        if (msg.sender != tx.origin) {
            require(whitelistContract.whitelisted(msg.sender) == true, 'INVALID_WHITELIST');
        }
        _;
    }
    constructor(
        ITuringWhitelist _whitelistContract
        ) public {
         owner = msg.sender;
         whitelistContract = _whitelistContract;
    }
    function changeOwner(address _owner) public onlyOwner {
        owner = _owner;
    }
    function setWhitelistContract(ITuringWhitelist _whitelistContract) public onlyOwner {
        whitelistContract = _whitelistContract;
    }
    function harvest(ITuringPool[] calldata _pools) public onlyWhitelist {
    	for (uint256 idx = 0; idx < _pools.length; idx++) {
            _pools[idx].harvest(msg.sender);
    	}
    }
}