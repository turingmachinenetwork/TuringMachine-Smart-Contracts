// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IBEP20.sol';
import './library/SafeMath.sol';

contract TuringDevLock {
    
    address public owner;

    mapping(bytes32 => TimeLock) public timeLockOf;

    using SafeMath for uint256;

    uint256 public version = 100;

    IBEP20 public turingTokenContract;

    uint256 public totalDevFund = 0;

    uint256 public startUnlockBlock;

    uint256 public lastUnlockBlock;

    address public distributeTuring;

    uint public constant GRACE_PERIOD = 30 days;
    uint public constant MINIMUM_DELAY = 2 days;
    uint public constant MAXIMUM_DELAY = 30 days;
    uint public delay;

    struct TimeLock {
        bool queuedTransactions;
        uint256 timeOfExecute;
        mapping(bytes32 => address) addressOf;
    }

    modifier onlyOwner()
    {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }

    modifier onlyDistributeTuring()
    {
        require(msg.sender == distributeTuring, 'INVALID_PERMISSION');
        _;
    }

    event onQueuedTransactionsChangeAddress(string _functionName, string _fieldName, address _value);
    event onCancelTransactions(string _functionName);

    constructor(IBEP20 _turingContract) public {
        owner = msg.sender;
        turingTokenContract = _turingContract;
        startUnlockBlock = now + 90 days; //first unlock is 3 months
        // startUnlockBlock = now + 1 days; //first unlock is 3 months
        lastUnlockBlock = 0;
    }

    function setDelay(uint delay_) public onlyOwner {
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");

        delay = delay_;
    }

    function cancelTransactions(string memory _functionName) public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode(_functionName))];
        _timelock.queuedTransactions = false;

        emit onCancelTransactions(_functionName);
    }

    function queuedTransactionsChangeAddress(string memory _functionName, string memory _fieldName, address _newAddr) public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode(_functionName))];

        _timelock.addressOf[keccak256(abi.encode(_fieldName))] = _newAddr;
        _timelock.queuedTransactions = true;
        _timelock.timeOfExecute = block.timestamp.add(delay);

        emit onQueuedTransactionsChangeAddress(_functionName, _fieldName, _newAddr);
    } 

    function transferOwnership() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('transferOwnership'))];

        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('owner'))] != address(0), "INVALID_ADDRESS");

        owner = _timelock.addressOf[keccak256(abi.encode('owner'))];
        delete _timelock.addressOf[keccak256(abi.encode('owner'))];
        _timelock.queuedTransactions = false;
    }

    function setDistributeTuring() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setDistributeTuring'))];

        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('distributeTuring'))] != address(0), "INVALID_ADDRESS");

         distributeTuring = _timelock.addressOf[keccak256(abi.encode('distributeTuring'))];
         delete _timelock.addressOf[keccak256(abi.encode('distributeTuring'))];
        _timelock.queuedTransactions = false;
    }

    function setTuringTokenContract() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setTuringTokenContract'))];
        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('turingTokenContract'))] != address(0), "INVALID_ADDRESS");

         turingTokenContract = IBEP20(_timelock.addressOf[keccak256(abi.encode('turingTokenContract'))]);
         delete _timelock.addressOf[keccak256(abi.encode('turingTokenContract'))];
        _timelock.queuedTransactions = false;
    }

    function _validateTimelock(TimeLock memory _timelock) private view {
        require(_timelock.queuedTransactions == true, "Transaction hasn't been queued.");
        require(_timelock.timeOfExecute <= block.timestamp, "Transaction hasn't surpassed time lock.");
        require(_timelock.timeOfExecute.add(GRACE_PERIOD) >= block.timestamp, "Transaction is stale.");
    }

    function unlock() public {
        require(now > startUnlockBlock, 'NOT_TIME');
        require(now > lastUnlockBlock + 30 days, 'NOT_30_DAYS'); // only unlock each 30 days
        // require(now > lastUnlockBlock + 1 days, 'NOT_30_DAYS'); // only unlock each 30 days

        uint256 unlockAmt  = totalDevFund.div(10); //unlock 1/10 of dev fund to owner wallet
        uint256 turingBalance = turingTokenContract.balanceOf(address(this)); 

        if (unlockAmt > turingBalance) {
            unlockAmt = turingBalance;
        }
        turingTokenContract.transfer(owner, unlockAmt); 
        lastUnlockBlock = now;
    }


    function addDevFund(uint256 _amount) public onlyDistributeTuring {
        if (_amount > 0) {
            totalDevFund = totalDevFund.add(_amount);
        }
    }

    function getAddressChangeOnTimeLock(string memory _functionName, string memory _fieldName) public view returns(address) {
        return timeLockOf[keccak256(abi.encode(_functionName))].addressOf[keccak256(abi.encode(_fieldName))];
    }
}