// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IBEP20.sol';
import './interfaces/IPancakeMasterChef.sol';
import './interfaces/IPancakeSwapRouter.sol';
import './interfaces/IMiningMachine.sol';
import './library/Ownable.sol';
import './library/SafeMath.sol';
import './library/ReentrancyGuard.sol';
import './library/SortitionSumTreeFactory.sol';

contract TuringNoLossLotteryCake is ReentrancyGuard, Ownable {

    using SafeMath for uint256;
    uint256 public version = 100;
    bytes32 TREE_KEY;
    uint256 constant MAX_TREE_LEAVES = 5;
    uint256 public pidOfMining;
    IBEP20 public want; // CAKE
    IBEP20 public TURING; // TURING
    address public wbnb; // TURING
    address public busd; // TURING

    using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;

    SortitionSumTreeFactory.SortitionSumTrees sumTreeFactory;

    IPancakeSwapRouter public pancakeSwap;
    IPancakeMasterChef public pankaceMasterChef;
    IMiningMachine public miningMachine;

    uint256 public totalShare = 0;
    uint256 public totalPlayer = 0;

    mapping(address => uint256) public shareOf;
    mapping(address => uint256) public lastDepositTimeOf;

    uint256 public halftime = 7 days;
    uint256 public endLoteryTime;

    address public performanceMachine; // the contract will use fee to Buy tUR on pankace swap , then burn the turs token
    address public controllerMachine;

    uint256 public rateOfPerformanceFee = 500; // 5 % on profit.
    uint256 public rateOfControllerFee = 50; // 0.5 % on profit.
    uint256 public rateFeeOfWithdrawEarly = 50; // Max 0.5 %
    uint256 public pendingTimeOfWithdraw = 3 * 24 * 60 * 60;

    uint256 public totalHistory = 5;
    uint256 public lastHistory = 0;
    uint256 public totalRandom = 0;

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

    mapping(uint256 => History) public historyList;

    struct History {
        uint256 time;
        uint256 tiketsWin;
        uint256 totalTickets;
        address winner;
        uint256 wonAmt;
        uint256 performanceFee;
        uint256 controllerFee;
    }


    event onDraw(uint256 _index, address _user, uint256 _amount, uint256 _performanceFee, uint256 _controllerFee);
    event onDeposit(address _user, uint256 _amount);
    event onWithdraw(address _user, uint256 _amount, uint256 _fee);

    event onQueuedTransactionsChangeAddress(string _functionName, string _fieldName, address _value);
    event onQueuedTransactionsChangeUint(string _functionName, string _fieldName, uint256 _value);
    event onCancelTransactions(string _functionName);

    constructor(
        IPancakeSwapRouter _pancakeSwap,
        IMiningMachine _miningMachine,
        IPancakeMasterChef _pancakeMasterChef,
        IBEP20 _cake,
        IBEP20 _turing,
        address _wbnb,
        address _busd,
        uint256 _pidOfMining
        ) public {
        pidOfMining   = _pidOfMining;
        miningMachine = _miningMachine;
        pancakeSwap = _pancakeSwap;
        want = _cake;
        TURING = _turing;

        wbnb = _wbnb;
        busd = _busd;

        pankaceMasterChef = _pancakeMasterChef;

        endLoteryTime = halftime.add(block.timestamp);

        TREE_KEY = keccak256(abi.encodePacked("TuringNoLossCake", block.timestamp, address(this), msg.sender));
        sumTreeFactory.createTree(TREE_KEY, MAX_TREE_LEAVES);

        approveConnectToPancake();
    }

    receive() external payable {
        
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

    function queuedTransactionsChangeUint(string memory _functionName, string memory _fieldName, uint256 _value) public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode(_functionName))];

        _timelock.uintOf[keccak256(abi.encode(_fieldName))] = _value;
        _timelock.queuedTransactions = true;
        _timelock.timeOfExecute = block.timestamp.add(delay);

        emit onQueuedTransactionsChangeUint(_functionName, _fieldName, _value);
    }

    function transferOwnership() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('transferOwnership'))];

        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('owner'))] != address(0), "INVALID_ADDRESS");

        owner = _timelock.addressOf[keccak256(abi.encode('owner'))];
        delete _timelock.addressOf[keccak256(abi.encode('owner'))];
        _timelock.queuedTransactions = false;
    }

    function setPerformanceMachine() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPerformanceMachine'))];

        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('performanceMachine'))] != address(0), "INVALID_ADDRESS");

        performanceMachine = _timelock.addressOf[keccak256(abi.encode('performanceMachine'))];
        delete _timelock.addressOf[keccak256(abi.encode('performanceMachine'))];
        _timelock.queuedTransactions = false;
    }

    function setPancakeSwapContract() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPancakeSwapContract'))];

        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('pancakeSwap'))] != address(0), "INVALID_ADDRESS");

        pancakeSwap = IPancakeSwapRouter(_timelock.addressOf[keccak256(abi.encode('pancakeSwap'))]);
        delete _timelock.addressOf[keccak256(abi.encode('pancakeSwap'))];
        _timelock.queuedTransactions = false;
    }

    function setPancakeMasterChefContract() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPancakeMasterChefContract'))];

        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('pankaceMasterChef'))] != address(0), "INVALID_ADDRESS");

        pankaceMasterChef = IPancakeMasterChef(_timelock.addressOf[keccak256(abi.encode('pankaceMasterChef'))]);
        delete _timelock.addressOf[keccak256(abi.encode('pankaceMasterChef'))];
        _timelock.queuedTransactions = false;
    }

    function approveConnectToPancake() public {
        want.approve(address(pankaceMasterChef), uint256(-1));
    }

    function changeHalftime() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('changeHalftime'))];

        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('halftime'))] > 0, "INVALID_AMOUNT");

        halftime = _timelock.uintOf[keccak256(abi.encode('halftime'))];
        delete _timelock.uintOf[keccak256(abi.encode('halftime'))];
        _timelock.queuedTransactions = false;
    } 

    function changeEndLoteryTime() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('changeEndLoteryTime'))];

        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('endLoteryTime'))] > 0, "INVALID_AMOUNT");

        endLoteryTime = _timelock.uintOf[keccak256(abi.encode('endLoteryTime'))];
        delete _timelock.uintOf[keccak256(abi.encode('endLoteryTime'))];
        _timelock.queuedTransactions = false;
    }

    function setRateOfPerformanceFee() public onlyOwner {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setRateOfPerformanceFee'))];

        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('rateOfPerformanceFee'))] > 0, "INVALID_AMOUNT");

        rateOfPerformanceFee = _timelock.uintOf[keccak256(abi.encode('rateOfPerformanceFee'))];
        delete _timelock.uintOf[keccak256(abi.encode('rateOfPerformanceFee'))];
        _timelock.queuedTransactions = false;
    }

    function setPendingTimeOfWithdraw() public onlyOwner {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPendingTimeOfWithdraw'))];

        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('pendingTimeOfWithdraw'))] > 0, "INVALID_AMOUNT");

        pendingTimeOfWithdraw = _timelock.uintOf[keccak256(abi.encode('pendingTimeOfWithdraw'))];
        delete _timelock.uintOf[keccak256(abi.encode('pendingTimeOfWithdraw'))];
        _timelock.queuedTransactions = false;
    }

    function setRatefeeOfWithdrawEarly() public onlyOwner {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setRatefeeOfWithdrawEarly'))];

        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('rateFeeOfWithdrawEarly'))] > 0, "INVALID_AMOUNT");

        rateFeeOfWithdrawEarly = _timelock.uintOf[keccak256(abi.encode('rateFeeOfWithdrawEarly'))];
        delete _timelock.uintOf[keccak256(abi.encode('rateFeeOfWithdrawEarly'))];
        _timelock.queuedTransactions = false;
    }

    function setControllerMachine() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setControllerMachine'))];

        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('controllerMachine'))] != address(0), "INVALID_ADDRESS");

        controllerMachine = _timelock.addressOf[keccak256(abi.encode('controllerMachine'))];
        delete _timelock.addressOf[keccak256(abi.encode('controllerMachine'))];
        _timelock.queuedTransactions = false;
    }

    function setRateOfControllerFee() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setRateOfControllerFee'))];

        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('rateOfControllerFee'))] > 0, "INVALID_AMOUNT");

        rateOfControllerFee = _timelock.uintOf[keccak256(abi.encode('rateOfControllerFee'))];
        delete _timelock.uintOf[keccak256(abi.encode('rateOfControllerFee'))];
        _timelock.queuedTransactions = false;
    }

    function setPidOfMining() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPidOfMining'))];

        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('pidOfMining'))] > 0, "INVALID_AMOUNT");

        pidOfMining = _timelock.uintOf[keccak256(abi.encode('pidOfMining'))];
        delete _timelock.uintOf[keccak256(abi.encode('pidOfMining'))];
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


    function _validateTimelock(TimeLock memory _timelock) private view {
        require(_timelock.queuedTransactions == true, "Transaction hasn't been queued.");
        require(_timelock.timeOfExecute <= block.timestamp, "Transaction hasn't surpassed time lock.");
        require(_timelock.timeOfExecute.add(GRACE_PERIOD) >= block.timestamp, "Transaction is stale.");
    }

    function deposit(uint256 _wantAmt) external nonReentrant {

        require(_wantAmt > 0, 'INVALID_INPUT');
        require(want.balanceOf(msg.sender) >= _wantAmt, 'INVALID_INPUT');

        if (shareOf[msg.sender] <= 0) {
            totalPlayer = totalPlayer.add(1);
        }

        harvest(msg.sender);
        want.transferFrom(msg.sender, address(this), _wantAmt);
        // update total principal
        shareOf[msg.sender] = shareOf[msg.sender].add(_wantAmt);
        totalShare = totalShare.add(_wantAmt);
        // mint tickit
        sumTreeFactory.set(TREE_KEY, shareOf[msg.sender], bytes32(uint256(address(msg.sender))));

        lastDepositTimeOf[msg.sender] = block.timestamp;

        harvest(msg.sender);

        emit onDeposit(msg.sender, _wantAmt);
    }
    function withdraw(uint256 _wantAmt) external nonReentrant {

        require(_wantAmt > 0, 'INVALID_INPUT');
        harvest(msg.sender);

        if (_wantAmt > shareOf[msg.sender]) {
            _wantAmt = shareOf[msg.sender];
        }

        pankaceMasterChef.leaveStaking(_wantAmt);
        uint256 _cakeBalance = want.balanceOf(address(this));
        if (_wantAmt > _cakeBalance) {
            _wantAmt = _cakeBalance;
        }
        uint256 _fee = getFeeOfWithdrawEarly(msg.sender, _wantAmt);
        require(shareOf[msg.sender].sub(_fee) >= _wantAmt, 'INVALID_AMOUNT_WITHDRAW');
        // update total principal
        shareOf[msg.sender] = shareOf[msg.sender].sub(_fee).sub(_wantAmt);
        totalShare = totalShare.sub(_fee).sub(_wantAmt);
        // burn ticket
        sumTreeFactory.set(TREE_KEY, shareOf[msg.sender], bytes32(uint256(address(msg.sender))));

        want.transfer(msg.sender, _wantAmt);

        if (shareOf[msg.sender] <= 0) {
            totalPlayer = totalPlayer.sub(1);
        }

        harvest(msg.sender);

        emit onWithdraw(msg.sender, _wantAmt, _fee);
    }

    function harvest(address _user) public {
        pankaceMasterChef.leaveStaking(0);
        uint256 _cakeBalance = want.balanceOf(address(this));
        if (_cakeBalance > 0) {
            pankaceMasterChef.enterStaking(_cakeBalance);
        }
        miningMachine.harvest(pidOfMining, _user);
    }

    function draw() public {

        require(endLoteryTime <= block.timestamp, 'INVALID_TIME');
        require(msg.sender == tx.origin, 'INVALID_PERMISSION');

        uint256 _tiketsWin = _random(); 

        address _userLucky = getOwnerOfToken(_tiketsWin);
       
        require(_userLucky != address(0), 'INVALID_USER_LUCKY');

        (uint256 _cakeStaked, ) = pankaceMasterChef.userInfo(0, address(this));

        pankaceMasterChef.leaveStaking(_cakeStaked);

        uint256 _cakeBalance = want.balanceOf(address(this));

        require(_cakeBalance > totalShare, 'INVALID_CAKE_BALANCE');

        uint256 _wonAmt = _cakeBalance.sub(totalShare);

        uint256 _performanceFee = _wonAmt.mul(rateOfPerformanceFee).div(10000);
        uint256 _controllerFee  = _wonAmt.mul(rateOfControllerFee).div(10000);

        want.transfer(performanceMachine, _performanceFee);
        want.transfer(controllerMachine, _controllerFee);

        _wonAmt = _wonAmt.sub(_performanceFee).sub(_controllerFee);

        shareOf[_userLucky] = shareOf[_userLucky].add(_wonAmt);
        totalShare = totalShare.add(_wonAmt);

        pankaceMasterChef.enterStaking(_cakeBalance.sub(_performanceFee).sub(_controllerFee));

        endLoteryTime = halftime.add(block.timestamp);

        // UPdate history
        if (lastHistory >= 5) {
            lastHistory = 0;
        }
        History storage _h = historyList[lastHistory];

        _h.time = block.timestamp;
        _h.tiketsWin = _tiketsWin;
        _h.totalTickets = totalShare;
        _h.winner = _userLucky;
        _h.wonAmt = _wonAmt;
        _h.performanceFee = _performanceFee;
        _h.controllerFee = _controllerFee;

        lastHistory = lastHistory.add(1);

        emit onDraw(_tiketsWin, _userLucky, _wonAmt, _performanceFee, _controllerFee);
    }
    function _random() private returns (uint256) {

        if (totalShare <= 0) {
            return 0;
        }
        totalRandom += 1;
        uint256 randomHash = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, totalRandom, totalShare)));

        return randomHash % totalShare;
    }

    function getOwnerOfToken(uint256 _token) public view returns (address) {
      return address(uint256(sumTreeFactory.draw(TREE_KEY, _token)));
    } 
    /**
        data_[0] uint256 miningSpeed_, 
        data_[1] uint256 userWant_, 
        data_[2] uint256 userTickets_, 
        data_[3] uint256 userWantCanWithdraw_, // cake 
        data_[4] uint256 userTuringPending_, 
        data_[5] uint256 userTuringBal_, 
        data_[6] uint256 userBNBBal_, 
        data_[7] uint256 prize_, 
        data_[8] uint256 turingRewardAPY_, 
        data_[9] uint256 totalTickets_, 
        data_[10] uint256 wantPrice_, 
        data_[11] uint256 turingPrice_, 
        data_[12] uint256 endLoteryTime_, 
        data_[13] uint256 tvl_,
        data_[14] uint256 userWantBal
        data_[15] uint256 totalPlayer
    */
    function getData(
        address _user
    ) 
    public 
    view 
    returns(
        uint256[16] memory data_
    ) {
        
        data_[0] = miningMachine.getMiningSpeedOf(pidOfMining);
        data_[1] = shareOf[_user];
        data_[2] = shareOf[_user];
        data_[3] = shareOf[_user].sub(getFeeOfWithdrawEarly(_user, shareOf[_user]));
        data_[5] = TURING.balanceOf(_user);
        data_[6] = address(_user).balance;
        data_[9] = totalShare;
        (data_[4], , ) = miningMachine.getUserInfo(pidOfMining, _user);
        uint256 _totalMintPerDay = miningMachine.getTotalMintPerDayOf(pidOfMining);
        // get token price by busd
        data_[10] = getWantPrice();
        data_[11] = getTuringPrice();
        data_[12] = endLoteryTime;
        data_[13] = totalShare;
        data_[7] = getTotalReward();

        if (data_[13] > 0) {
            data_[8] = _totalMintPerDay.mul(365).mul(data_[11]).mul(10000).div(data_[13].mul(data_[10]));
        }

        data_[14] = want.balanceOf(_user);
        data_[15] = totalPlayer;
    }   

    function getFeeOfWithdrawEarly(address _user, uint256 _amount) public view returns(uint256) {
        uint256 _distance = block.timestamp.sub(lastDepositTimeOf[_user]);
        if (pendingTimeOfWithdraw <= _distance) {
            return 0;
        } 
        uint256 _fee = _amount.mul(rateFeeOfWithdrawEarly).div(10000);
        _fee = _fee.sub(_fee.mul(_distance).div(pendingTimeOfWithdraw));
        return _fee;
    }

    function getTotalReward() public view returns(uint256) {
        uint256 _pendingCake = pankaceMasterChef.pendingCake(0, address(this));
        (uint256 _cakeStaked, ) = pankaceMasterChef.userInfo(0, address(this));
        uint256 _totalCake = _cakeStaked.add(_pendingCake);
        uint256 _totalReward = 0;

        if (_totalCake > totalShare) {
            _totalReward = _totalCake.sub(totalShare);
        }
        return _totalReward;
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

    function getAddressChangeOnTimeLock(string memory _functionName, string memory _fieldName) public view returns(address) {
        return timeLockOf[keccak256(abi.encode(_functionName))].addressOf[keccak256(abi.encode(_fieldName))];
    }

    function getUintChangeOnTimeLock(string memory _functionName, string memory _fieldName) public view returns(uint256) {
        return timeLockOf[keccak256(abi.encode(_functionName))].uintOf[keccak256(abi.encode(_fieldName))];
    }
}