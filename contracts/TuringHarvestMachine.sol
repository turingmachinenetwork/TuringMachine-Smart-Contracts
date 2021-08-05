// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface ITuringWhitelist {
	function whitelisted(address _address) external view returns (bool);
}
interface IMiningMachine {
	function harvest(uint256 _pid, address _user) external returns(uint256 _pendingTur, uint256 _bonus);
}
interface ITuringPool {
    function harvest(address _user) external;
	function pidOfMining() external view returns(uint256);  
}

contract TuringHarvestMachine {
	ITuringWhitelist public whitelistContract; 
	IMiningMachine public miningMachineContract; 
    mapping(address => bool) public harvestTURINGList;
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
        ITuringWhitelist _whitelistContract,
        IMiningMachine _miningMachineContract
        ) public {
         owner = msg.sender;
         whitelistContract = _whitelistContract;
         miningMachineContract = _miningMachineContract;
    }
    function changeOwner(address _owner) public onlyOwner {
        owner = _owner;
    }
    function setHarvestTURINGList(address _pool) public onlyOwner {
        harvestTURINGList[_pool] = !harvestTURINGList[_pool];
    }
    function setWhitelistContract(ITuringWhitelist _whitelistContract) public onlyOwner {
        whitelistContract = _whitelistContract;
    }
    function setMiningMachineContract(IMiningMachine _miningMachineContract) public onlyOwner {
        miningMachineContract = _miningMachineContract;
    }
    function harvest(ITuringPool[] calldata _pools) public onlyWhitelist {
    	for (uint256 idx = 0; idx < _pools.length; idx++) {
            if (harvestTURINGList[address(_pools[idx])] == true) {
                uint256 _pid = _pools[idx].pidOfMining();
                miningMachineContract.harvest(_pid, msg.sender);
            } else {
                _pools[idx].harvest(msg.sender);
            }
    	}
    }
}