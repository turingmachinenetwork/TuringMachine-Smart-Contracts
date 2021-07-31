// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IMiningMachine.sol';
import './interfaces/IPancakeSwapRouter.sol';
import './interfaces/IPancakeMasterChef.sol';
import './interfaces/IBEP20.sol';
import './library/SafeMath.sol';
import './library/ReentrancyGuard.sol';

contract TuringFarmCake is ReentrancyGuard {

    using SafeMath for uint256;
    uint256 public version = 100;
    address public owner;
    
    IBEP20 public want; // 
    IBEP20 public TURING; // TURING
    address public wbnb;
    address public busd;

    IPancakeMasterChef public pankaceMasterChef;
    IMiningMachine public miningMachine;
    IPancakeSwapRouter public pancakeSwap;

    uint256 public pidOfMining;
    uint256 public totalShare = 0;
    uint256 public accWantPerShare = 0;
    uint256 public timeOfHarvest = 0;
    uint256 public periodOfDay = 1 days;

    mapping(address => uint256) public shareOf;
    mapping(address => uint256) public rewardWantDebtOf;

    uint256 public rateOfPerformanceFee = 50; // 0.5 % on profit.
    uint256 public rateOfControllerFee = 10; // 0.1 % on profit.
    address public performanceMachine; // the contract will use fee to Buy tUR on pankace swap , then burn the turs token
    address public controllerMachine;

    mapping(bytes32 => TimeLock) public timeLockOf;

    uint public constant GRACE_PERIOD = 30 days;
    uint public constant MINIMUM_DELAY = 2 days;
    uint public constant MAXIMUM_DELAY = 30 days;
    uint public delay;

    struct TimeLock {
        bool queuedTransactions;
        uint256 timeOfExecute;
        mapping(bytes32 => address) addressOf;
        mapping(bytes32 => uint256) uintOf;
    }

    modifier onlyOwner()
    {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }

    event onDeposit(address _user, uint256 _amount);
    event onWithdraw(address _user, uint256 _amount);

    event onQueuedTransactionsChangeAddress(string _functionName, string _fieldName, address _value);
    event onQueuedTransactionsChangeUint(string _functionName, string _fieldName, uint256 _value);
    event onCancelTransactions(string _functionName);

    constructor(
        IPancakeSwapRouter _pancakeSwap,
        IPancakeMasterChef _pancakeMasterChef,
        IBEP20 _want,
        IBEP20 _turing,
        address _wbnb,
        address _busd
        ) public {
        owner = msg.sender;
        pancakeSwap = _pancakeSwap;
        pankaceMasterChef = _pancakeMasterChef;
        want = _want;
        TURING = _turing;
        wbnb = _wbnb;
        busd = _busd;
    }

    receive() external payable {
        
    }

    function setDelay(uint delay_) public onlyOwner {
        require(delay_ >= MINIMUM_DELAY, "Timelock::setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Timelock::setDelay: Delay must not exceed maximum delay.");

        delay = delay_;
    }

    function approveConnectToPancake() public 
    {
        want.approve(address(pankaceMasterChef), uint256(-1));
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

    function transferOwnership() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('transferOwnership'))];
        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('owner'))] != address(0), "INVALID_ADDRESS");

        owner = _timelock.addressOf[keccak256(abi.encode('owner'))];
        delete _timelock.addressOf[keccak256(abi.encode('owner'))];
        _timelock.queuedTransactions = false;
    }

     function setMiningMachine() public onlyOwner 
     {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setMiningMachine'))];
        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('miningMachine'))] != address(0), "INVALID_ADDRESS");
        miningMachine = IMiningMachine(_timelock.addressOf[keccak256(abi.encode('miningMachine'))]);

        delete _timelock.addressOf[keccak256(abi.encode('miningMachine'))];
        _timelock.queuedTransactions = false;
    }

     function setPerformanceMachine() public onlyOwner 
     {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPerformanceMachine'))];
        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('performanceMachine'))] != address(0), "INVALID_ADDRESS");
        performanceMachine = _timelock.addressOf[keccak256(abi.encode('performanceMachine'))];

        delete _timelock.addressOf[keccak256(abi.encode('performanceMachine'))];
        _timelock.queuedTransactions = false;
    }

    function setRateOfPerformanceFee() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setRateOfPerformanceFee'))];
        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('rateOfPerformanceFee'))] > 0, "INVALID_AMOUNT");

        rateOfPerformanceFee = _timelock.uintOf[keccak256(abi.encode('rateOfPerformanceFee'))];
        delete _timelock.uintOf[keccak256(abi.encode('rateOfPerformanceFee'))];
        _timelock.queuedTransactions = false;
    }

    function setControllerMachine() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setControllerMachine'))];
        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('controllerMachine'))] != address(0), "INVALID_ADDRESS");

        controllerMachine = _timelock.addressOf[keccak256(abi.encode('controllerMachine'))];
        delete _timelock.addressOf[keccak256(abi.encode('controllerMachine'))];
        _timelock.queuedTransactions = false;
    }   
    
    function changeTokenAddress() public onlyOwner
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('changeTokenAddress'))];

        _validateTimelock(_timelock);
    
        if (_timelock.addressOf[keccak256(abi.encode('want'))] != address(0)) {
            want = IBEP20(_timelock.addressOf[keccak256(abi.encode('want'))]);
            delete _timelock.addressOf[keccak256(abi.encode('want'))];
        } 
        if (_timelock.addressOf[keccak256(abi.encode('TURING'))] != address(0)) {
            TURING = IBEP20(_timelock.addressOf[keccak256(abi.encode('TURING'))]);
            delete _timelock.addressOf[keccak256(abi.encode('TURING'))];
        } 
        if (_timelock.addressOf[keccak256(abi.encode('wbnb'))] != address(0)) {
            wbnb = _timelock.addressOf[keccak256(abi.encode('wbnb'))];
            delete _timelock.addressOf[keccak256(abi.encode('wbnb'))];
        } 
        if (_timelock.addressOf[keccak256(abi.encode('busd'))] != address(0)) {
            busd = _timelock.addressOf[keccak256(abi.encode('busd'))];
            delete _timelock.addressOf[keccak256(abi.encode('busd'))];
        } 
        _timelock.queuedTransactions = false;
    }

    function setRateOfControllerFee() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setRateOfControllerFee'))];
        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('rateOfControllerFee'))] > 0, "INVALID_AMOUNT");

        rateOfControllerFee = _timelock.uintOf[keccak256(abi.encode('rateOfControllerFee'))];
        delete _timelock.uintOf[keccak256(abi.encode('rateOfControllerFee'))];
        _timelock.queuedTransactions = false;
    }

    function setPidOfMining() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPidOfMining'))];
        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('pidOfMining'))] > 0, "INVALID_AMOUNT");

        pidOfMining = _timelock.uintOf[keccak256(abi.encode('pidOfMining'))];
        delete _timelock.uintOf[keccak256(abi.encode('pidOfMining'))];
        _timelock.queuedTransactions = false;
    }

    function _validateTimelock(TimeLock memory _timelock) private view
    {
        require(_timelock.queuedTransactions == true, "Transaction hasn't been queued.");
        require(_timelock.timeOfExecute <= block.timestamp, "Transaction hasn't surpassed time lock.");
        require(_timelock.timeOfExecute.add(GRACE_PERIOD) >= block.timestamp, "Transaction is stale.");
    }

    function deposit(uint256 _wantAmt) external nonReentrant {
        require(_wantAmt > 0, 'INVALID_INPUT');
        require(want.balanceOf(msg.sender) >= _wantAmt, 'INVALID_INPUT');

        harvest(msg.sender);
        want.transferFrom(msg.sender, address(this), _wantAmt);
        // update total principal
        shareOf[msg.sender] = shareOf[msg.sender].add(_wantAmt);
        totalShare = totalShare.add(_wantAmt);
        pankaceMasterChef.enterStaking(_wantAmt);
        _updateUser(msg.sender);
        emit onDeposit(msg.sender, _wantAmt);
    }
    function withdraw(uint256 _wantAmt) external nonReentrant 
    {
        harvest(msg.sender);

        if (shareOf[msg.sender] < _wantAmt) {
            _wantAmt = shareOf[msg.sender];
        }
        require(_wantAmt > 0, 'INVALID_INPUT');
        pankaceMasterChef.leaveStaking(_wantAmt);
        uint256 _wantBal = want.balanceOf(address(this)); 
        if (_wantBal < _wantAmt) {
            _wantAmt = _wantBal;
        }

        shareOf[msg.sender] = shareOf[msg.sender].sub(_wantAmt);
        totalShare = totalShare.sub(_wantAmt);

        want.transfer(msg.sender, _wantAmt);

        _updateUser(msg.sender);
        // 
        emit onWithdraw(msg.sender, _wantAmt);
    }

    function harvest(address _user) public {
        timeOfHarvest = block.timestamp;
        miningMachine.harvest(pidOfMining, _user);
        
        uint256 _reward = pankaceMasterChef.pendingCake(0, address(this));
        if (
            _reward > 0 &&
            totalShare > 0
            ) {
            pankaceMasterChef.leaveStaking(0);
            uint256 _cakeBalance = want.balanceOf(address(this));
            if (_reward > _cakeBalance) {
                _reward = _cakeBalance;
            }
            // update reward for system
            uint256 _performanceFee = _reward.mul(rateOfPerformanceFee).div(10000);
            uint256 _controllerFee = _reward.mul(rateOfControllerFee).div(10000);
            want.transfer(performanceMachine, _performanceFee);
            want.transfer(controllerMachine, _controllerFee);
            _reward = _reward.sub(_performanceFee).sub(_controllerFee);
            accWantPerShare = accWantPerShare.add(_reward.mul(1e24).div(totalShare));

            _cakeBalance = want.balanceOf(address(this));
            if (_cakeBalance > 0) {
                pankaceMasterChef.enterStaking(_cakeBalance);
            }
        }

        uint256 _userRewardDebt  = shareOf[_user].mul(accWantPerShare).div(1e24);

        if (_userRewardDebt > rewardWantDebtOf[_user]) {
            uint256 _userPendingWant = _userRewardDebt.sub(rewardWantDebtOf[_user]);
            shareOf[_user] = shareOf[_user].add(_userPendingWant);
            totalShare = totalShare.add(_userPendingWant); 
            miningMachine.harvest(pidOfMining, _user);
        }

        rewardWantDebtOf[_user] = shareOf[_user].mul(accWantPerShare).div(1e24);
    }
   
    function _updateUser(address _user) private 
    {
        miningMachine.updateUser(pidOfMining, _user);
        rewardWantDebtOf[_user] = shareOf[_user].mul(accWantPerShare).div(1e24);
    }
    /**
    *
        data_[0] int256 miningSpeed_,
        data_[1] uint256 userWantBal_, 
        data_[2] uint256 turingPrice_, 
        data_[3] uint256 wantPrice_, 
        data_[4] uint256 totalMintPerDay_, 
        data_[5] uint256 totalWantRewardPerDay_, 
        data_[6] uint256 userBNBBal_, 
        data_[7] uint256 userTuringPending_, 
        data_[8] uint256 userWantShare_, 
        data_[9] uint256 turingRewardAPY_,
        data_[10] uint256 wantRewardAPY_,
        data_[11] uint256 tvl_
    */
    function getData(
        address _user
    ) 
    public 
    view
    returns(
        uint256[12] memory data_
    ) {
        data_[2] = getTuringPrice();
        data_[3] = getWantPrice();
        data_[4] = miningMachine.getTotalMintPerDayOf(pidOfMining);
        data_[5] = getTotalRewardPerDay();

        data_[0] = miningMachine.getMiningSpeedOf(pidOfMining);
        data_[6] = address(_user).balance;
        (data_[7], , ) = miningMachine.getUserInfo(pidOfMining, _user);

        data_[1] = want.balanceOf(_user);

        data_[8] = shareOf[_user].add(pendingWantOf(_user));

        (data_[11], ) = pankaceMasterChef.userInfo(0, address(this));

        if (data_[11] > 0) {
            data_[10] = data_[5].mul(365).mul(10000).div(data_[11]);
            data_[9] = data_[4].mul(data_[2]).mul(365).mul(10000).div(data_[11].mul(data_[3]));
        }
    } 

    function getTuringPrice() public view returns(uint256) {

        address[] memory path = new address[](3);

        path[0] = address(TURING);
        path[1] = wbnb;
        path[2] = busd;
        uint256 _price;
        try pancakeSwap.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
            _price = amounts[2];
        } catch {
            _price = 0;   
        }
        return _price;
    }

    function getWantPrice() public view returns(uint256) {

        address[] memory path = new address[](3);

        path[0] = address(want);
        path[1] = wbnb;
        path[2] = busd;
        uint256 _price;
        try pancakeSwap.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
            _price = amounts[2];
        } catch {
            _price = 0;   
        }
        return _price;
    }

    function getTotalRewardPerDay() public view returns(uint256) {
        uint256 _reward = pankaceMasterChef.pendingCake(0, address(this));
        uint256 _rewardPerSec = 0;
        if (block.timestamp > timeOfHarvest) {
           _rewardPerSec = _reward.div(block.timestamp.sub(timeOfHarvest));     
        }
        return _rewardPerSec.mul(periodOfDay);
    }

    function pendingWantOf(address _user) public view returns (uint256 _pendingWant) {

        uint256 _accWantPerShare  = accWantPerShare;
        uint256 _reward = pankaceMasterChef.pendingCake(0, address(this));
        if (
            _reward > 0 &&
            totalShare > 0
            ) {
            uint256 _performanceFee = _reward.mul(rateOfPerformanceFee).div(10000);
            uint256 _controllerFee  = _reward.mul(rateOfControllerFee).div(10000);
            _reward = _reward.sub(_performanceFee).sub(_controllerFee);
            _accWantPerShare = _accWantPerShare.add(_reward.mul(1e24).div(totalShare));
        }

        uint256 _rewardDebt  = shareOf[_user].mul(_accWantPerShare).div(1e24);

        if (_rewardDebt > rewardWantDebtOf[_user]) {
            _pendingWant = _rewardDebt.sub(rewardWantDebtOf[_user]);
        }
    }

    function getAddressChangeOnTimeLock(string memory _functionName, string memory _fieldName) public view returns(address) {
        return timeLockOf[keccak256(abi.encode(_functionName))].addressOf[keccak256(abi.encode(_fieldName))];
    }

    function getUintChangeOnTimeLock(string memory _functionName, string memory _fieldName) public view returns(uint256) {
        return timeLockOf[keccak256(abi.encode(_functionName))].uintOf[keccak256(abi.encode(_fieldName))];
    }
}