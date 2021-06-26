// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

import './interfaces/ITuringFarm.sol';
import './interfaces/ITuringDevLock.sol';
import './interfaces/ITuringBonus.sol';
import './library/SafeMath.sol'; 

contract MiningMachine {

    uint256 public version = 100;

    using SafeMath for uint256;

    address public owner;
    // Dev Locked Contract.
    ITuringDevLock public devLockedTokenContract; 

    ITuringBonus public turingBonus;

    IBEP20 public TUR;

    uint256 public totalBlockPerDay = 28800;// just use for dislay at UI
    // Turing each block.
    uint256 public turPerBlock = 50000000000000000;
    // The total point for all pools
    uint256 public totalAllocPoint = 1000;
    // The block when mining start
    uint256 public startBlock;

    PoolInfo[] public poolInfo;

    mapping(uint256 => mapping(address => uint256)) public rewardDebtOf;

    uint public constant GRACE_PERIOD = 30 days;
    uint public constant MINIMUM_DELAY = 2 days;
    uint public constant MAXIMUM_DELAY = 30 days;
    uint public delay;

    mapping(bytes32 => TimeLock) public timeLockOf;

    struct TimeLock {
        bool queuedTransactions;
        uint256 timeOfExecute;
        mapping(bytes32 => address) addressOf;
        mapping(bytes32 => uint256) uintOf;
    }
    
    struct PoolInfo {
    	address want; // LP token Addess
        ITuringFarm turingFarm;             // Address of Turing Farm Contract.
        uint256 allocPoint;                 // Mining speef for the pool.
        uint256 lastRewardBlock;            // Last block number when the pool get reward.
        uint256 accTurPerShare;             // Turing Per Share of the pool.
    }

    modifier onlyOwner()
    {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }

    event onHarvest(uint256 _pid, address _user, uint256 _amt);
    event onBonus(uint256 _pid, address _user, uint256 _amt);

    event onQueuedTransactionsChangeAddress(string _functionName, string _fieldName, address _value);
    event onQueuedTransactionsChangeUint(string _functionName, string _fieldName, uint256 _value);
    event onQueuedTransactionSsetPoolPoint(uint256 _pid, uint256 _allocPoint);
    event onCancelTransactions(string _functionName);

    constructor(
        IBEP20 _tur,
        ITuringDevLock _devLockedTokenContract,
        uint256 _turPerBlock,
        uint256 _startBlock
    ) public {
        owner = msg.sender;
        devLockedTokenContract = _devLockedTokenContract;
        TUR = _tur;
        turPerBlock = _turPerBlock;
        startBlock = _startBlock;
    }

    receive() external payable {
        
    }

    function setDelay(uint delay_) public onlyOwner 
    {
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");

        delay = delay_;
    }

    function cancelTransactions(string memory _functionName) public onlyOwner 
    {
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

    function queuedTransactionsChangeUint(string memory _functionName, string memory _fieldName, uint256 _value) public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode(_functionName))];

        _timelock.uintOf[keccak256(abi.encode(_fieldName))] = _value;
        _timelock.queuedTransactions = true;
        _timelock.timeOfExecute = block.timestamp.add(delay);

        emit onQueuedTransactionsChangeUint(_functionName, _fieldName, _value);
    }

     function queuedTransactionSsetPoolPoint(uint256 _pid, uint256 _allocPoint) public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPoolPoint', _pid))];

        _timelock.uintOf[keccak256(abi.encode('allocPoint'))] = _allocPoint;
        _timelock.queuedTransactions = true;
        _timelock.timeOfExecute = block.timestamp.add(delay);

        emit onQueuedTransactionSsetPoolPoint(_pid, _allocPoint);
    }

    function transferOwnership() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('transferOwnership'))];
        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('owner'))] != address(0), "INVALID_ADDRESS");

        owner = _timelock.addressOf[keccak256(abi.encode('owner'))];
        delete _timelock.addressOf[keccak256(abi.encode('owner'))];
        _timelock.queuedTransactions = false;
    }

    function setTotalBlockPerDay() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setTotalBlockPerDay'))];
        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('totalBlockPerDay'))] > 0, "INVALID_AMOUNT");

        totalBlockPerDay = _timelock.uintOf[keccak256(abi.encode('totalBlockPerDay'))];
        delete _timelock.uintOf[keccak256(abi.encode('totalBlockPerDay'))];
        _timelock.queuedTransactions = false;
    }

    function setTotalAllocPoint() public onlyOwner
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setTotalAllocPoint'))];
        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('totalAllocPoint'))] > 0, "INVALID_AMOUNT");

        totalAllocPoint = _timelock.uintOf[keccak256(abi.encode('totalAllocPoint'))];
        delete _timelock.uintOf[keccak256(abi.encode('totalAllocPoint'))];
        _timelock.queuedTransactions = false;
    }

    function setTuringBonusContract() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setTuringBonusContract'))];

        _validateTimelock(_timelock);
        
        require(_timelock.addressOf[keccak256(abi.encode('turingBonus'))] != address(0), "INVALID_ADDRESS");

        turingBonus = ITuringBonus(_timelock.addressOf[keccak256(abi.encode('turingBonus'))]);

        delete _timelock.addressOf[keccak256(abi.encode('turingBonus'))];

        _timelock.queuedTransactions = false;
    }

    function setTuringTokenContract() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setTuringTokenContract'))];

        _validateTimelock(_timelock);
        
        require(_timelock.addressOf[keccak256(abi.encode('TUR'))] != address(0), "INVALID_ADDRESS");

        TUR = IBEP20(_timelock.addressOf[keccak256(abi.encode('TUR'))]);

        delete _timelock.addressOf[keccak256(abi.encode('TUR'))];

        _timelock.queuedTransactions = false;
    }

    function setDevLockedTokenContract() public onlyOwner  
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setDevLockedTokenContract'))];

        _validateTimelock(_timelock);
        
        require(_timelock.addressOf[keccak256(abi.encode('devLockedTokenContract'))] != address(0), "INVALID_ADDRESS");

        devLockedTokenContract = ITuringDevLock(_timelock.addressOf[keccak256(abi.encode('devLockedTokenContract'))]);

        delete _timelock.addressOf[keccak256(abi.encode('devLockedTokenContract'))];

        _timelock.queuedTransactions = false;
    }
    // Add a new pool. Can only be called by the owner.
    function addPool(uint256 _allocPoint, ITuringFarm _turFarm) public onlyOwner { 

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('addPool'))];
        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('turingFarm'))] == address(_turFarm), 'INVALID_ADDRESS');

    	address want = address(_turFarm.want());
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        poolInfo.push(PoolInfo({
            want: want,
            turingFarm: _turFarm,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accTurPerShare: 0
        }));
        delete _timelock.addressOf[keccak256(abi.encode('turingFarm'))];
        _timelock.queuedTransactions = false;
    }

    //Update the given pool's allocation point. Can only be called by the owner.
    function setPoolPoint(uint256 _pid) public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPoolPoint', _pid))];

        _validateTimelock(_timelock);

    	require(poolInfo[_pid].allocPoint != _timelock.uintOf[keccak256(abi.encode('allocPoint'))], 'INVALID_INPUT');

    	updatePool(_pid);
        
        poolInfo[_pid].allocPoint = _timelock.uintOf[keccak256(abi.encode('allocPoint'))];
        delete _timelock.uintOf[keccak256(abi.encode('allocPoint'))];
        _timelock.queuedTransactions = false;
    }

    function _validateTimelock(TimeLock memory _timelock) private view {
        require(_timelock.queuedTransactions == true, "Transaction hasn't been queued.");
        require(_timelock.timeOfExecute <= block.timestamp, "Transaction hasn't surpassed time lock.");
        require(_timelock.timeOfExecute.add(GRACE_PERIOD) >= block.timestamp, "Transaction is stale.");
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {

        PoolInfo storage pool = poolInfo[_pid];

        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 _totalShare = pool.turingFarm.totalShare();
        
        uint256 _multiplier = getBlockFrom(pool.lastRewardBlock, block.number);

        uint256 _reward = _multiplier.mul(turPerBlock).mul(pool.allocPoint).div(totalAllocPoint);

        if (_totalShare == 0) {

            pool.lastRewardBlock = block.number;

            return;
        }

        TUR.mint(address(this), _reward);

        TUR.mint(address(devLockedTokenContract), _reward.div(10)); //Give the dev 10% of TURING token to a locked contract

        devLockedTokenContract.addDevFund(_reward.div(10));

        pool.accTurPerShare = pool.accTurPerShare.add(_reward.mul(1e12).div(_totalShare));

        pool.lastRewardBlock = block.number;
    }

    function harvest(uint256 _pid, address _user) external returns(uint256 _pendingTur, uint256 _bonus) 
    {	
    	updatePool(_pid);
    
    	uint256 _rewardDebt;
    	(_pendingTur, _rewardDebt, ) = getUserInfo(_pid, _user);

    	uint256 _turBal = TUR.balanceOf(address(this));

    	rewardDebtOf[_pid][_user] = _rewardDebt;

    	if (_pendingTur > _turBal) {
            _pendingTur = _turBal;
    	}
        if (_pendingTur > 0) {
            _bonus = turingBonus.getBonusAmount(poolInfo[_pid].turingFarm, _user, _pendingTur);

            if (_bonus > 0) {
                TUR.mint(address(this), _bonus);
                emit onBonus(_pid, _user, _bonus);
            }
            TUR.transfer(_user, _pendingTur.add(_bonus));
            emit onHarvest(_pid, _user, _pendingTur);
        }
    }

    function updateUser(uint256 _pid, address _user) public returns(bool)
    {
        PoolInfo memory pool = poolInfo[_pid];
        require(address(pool.turingFarm) == msg.sender, 'INVALID_PERMISSION');

        uint256 _userShare  = pool.turingFarm.shareOf(_user);
        rewardDebtOf[_pid][_user] = _userShare.mul(pool.accTurPerShare).div(1e12);

        return true;
    }


    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getBlockFrom(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    function getMiningSpeedOf(uint256 _pid) public view returns(uint256) {
        return poolInfo[_pid].allocPoint.mul(100).div(totalAllocPoint);
    }

    function getTotalMintPerDayOf(uint256 _pid) public view returns(uint256) {
        return totalBlockPerDay.mul(turPerBlock).mul(poolInfo[_pid].allocPoint).div(totalAllocPoint);
    }

    function getTurAddr() public view returns(address) {
        return address(TUR);
    }

    // View function to get User's Info in a pool.
    function getUserInfo(uint256 _pid, address _user) public view returns (uint256 _pendingTur, uint256 _rewardDebt, uint256 _userShare) { 

        PoolInfo memory pool = poolInfo[_pid];

        uint256 accTurPerShare = pool.accTurPerShare;

        // uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        uint256 _totalShare = pool.turingFarm.totalShare();
        _userShare  = pool.turingFarm.shareOf(_user);

        if (block.number > pool.lastRewardBlock && _totalShare != 0) {
            uint256 _multiplier = getBlockFrom(pool.lastRewardBlock, block.number);
            uint256 _reward = _multiplier.mul(turPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accTurPerShare = accTurPerShare.add(_reward.mul(1e12).div(_totalShare));
        }
        _rewardDebt  = _userShare.mul(accTurPerShare).div(1e12);

        if (_rewardDebt > rewardDebtOf[_pid][_user]) {
            _pendingTur = _rewardDebt.sub(rewardDebtOf[_pid][_user]);
        }
    }

    function getAddressChangeOnTimeLock(string memory _functionName, string memory _fieldName) public view returns(address) {
        return timeLockOf[keccak256(abi.encode(_functionName))].addressOf[keccak256(abi.encode(_fieldName))];
    }

    function getUintChangeOnTimeLock(string memory _functionName, string memory _fieldName) public view returns(uint256) {
        return timeLockOf[keccak256(abi.encode(_functionName))].uintOf[keccak256(abi.encode(_fieldName))];
    }
}