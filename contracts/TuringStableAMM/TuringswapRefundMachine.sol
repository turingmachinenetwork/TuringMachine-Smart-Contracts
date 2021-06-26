// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import '../interfaces/IMiningMachine.sol';
import './interfaces/IBEP20.sol';
import './interfaces/ITuringTimeLock.sol';

contract TuringswapRefundMachine {

    uint256 public version = 100;
    address public owner;
    
    IBEP20 public TUR; // TUR
    IBEP20 public want; // 

    address public feeMachineAddr;

    ITuringTimeLock public turingTimeLockContract;
    IMiningMachine public miningMachineContract;

    mapping(address => uint256) public shareOf;

    uint256 public totalShare;

    uint256 public pidOfFarm;

    modifier onlyOwner()
    {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }

    event onHarvest(address _feeMachineAddr, uint256 _turBalance);

    constructor(IBEP20 _tur, ITuringTimeLock _turingTimeLockContract, IMiningMachine _miningMachineContract) public {
        owner = msg.sender;
        turingTimeLockContract = _turingTimeLockContract;
        miningMachineContract = _miningMachineContract;
        TUR = _tur;

        shareOf[address(this)] = 1e18;
        totalShare = 1e18;
    }

    receive() external payable {
        
    }

    function setMiningMachine() public onlyOwner {
        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setMiningMachine'), "INVALID_PERMISSION");

        address _miningMachine = turingTimeLockContract.getAddressChangeOnTimeLock(address(this), 'setMiningMachine', 'miningMachine');

        require(_miningMachine != address(0), "INVALID_ADDRESS");

        miningMachineContract = IMiningMachine(_miningMachine);

        turingTimeLockContract.clearFieldValue('setMiningMachine', 'miningMachine', 1);
        turingTimeLockContract.doneTransactions('setMiningMachine');
    }

    function setFeeMachine() public onlyOwner {
        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setFeeMachine'), "INVALID_PERMISSION");

        address _feeMachine = turingTimeLockContract.getAddressChangeOnTimeLock(address(this), 'setFeeMachine', 'feeMachine');

        require(_feeMachine != address(0), "INVALID_ADDRESS");

        feeMachineAddr = _feeMachine;

        turingTimeLockContract.clearFieldValue('setFeeMachine', 'feeMachine', 1);
        turingTimeLockContract.doneTransactions('setFeeMachine');
    }


    function setPidOfFarm() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setPidOfFarm'), "INVALID_PERMISSION");

        pidOfFarm = turingTimeLockContract.getUintChangeOnTimeLock(address(this), 'setPidOfFarm', 'pidOfFarm');

        turingTimeLockContract.clearFieldValue('setPidOfFarm', 'pidOfFarm', 2);
        turingTimeLockContract.doneTransactions('setPidOfFarm');
    }

    function transferOwnership(address _owner) public onlyOwner {
        require(_owner != address(0), "INVALID_ADDRESS");
        owner = _owner;
    }

    function harvest() public { 

        miningMachineContract.harvest(pidOfFarm, address(this));

        uint256 _turBalance = TUR.balanceOf(address(this));
        if (_turBalance > 0) {
            TUR.transfer(feeMachineAddr, _turBalance);
            emit onHarvest(feeMachineAddr, _turBalance);
        }
    }
}