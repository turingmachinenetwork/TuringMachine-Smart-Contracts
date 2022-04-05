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
    
    modifier isQueued(string memory _functionName) {
        require(turingTimeLockContract.isQueuedTransaction(address(this), _functionName) == true, "INVALID_PERMISTION");
        _;
        turingTimeLockContract.doneTransaction(_functionName);
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

    function setMiningMachine(IMiningMachine _miningMachine) public onlyOwner isQueued("setMiningMachine"){
        miningMachineContract = _miningMachine;
    }

    function setFeeMachine(uint256 _feeMachine) public onlyOwner isQueued("setFeeMachine"){
        feeMachineAddr = _feeMachine;
    }


    function setPidOfFarm(uint256 _pidOfFarm) public onlyOwner isQueued("setPidOfFarm"){
        pidOfFarm = _pidOfFarm;
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