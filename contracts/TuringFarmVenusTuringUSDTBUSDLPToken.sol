// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IMiningMachine.sol';
import './interfaces/IPancakeSwapRouter.sol';
import './interfaces/IBEP20.sol';
import './library/SafeMath.sol';
import './library/ReentrancyGuard.sol';

interface ITuringswapFarmVenus {
    function getXVSApy() external view returns(uint256);
    function getSupplyApy() external view returns(uint256);
}
interface ITuringswapFeeMachine {
    function getTradeFeeAPY(IBEP20 _lp) external view returns(uint256);
    function getVolume(address _lp) external view returns(uint256);
}
interface ITuringswapWhitelist {
    function whitelisted(address _address) external view returns (bool);
}
contract SwapTrade {
    ITuringswapFarmVenus public farmContract;
    ITuringswapFeeMachine public feeMachineContract; 
} 

contract TuringFarmVenusTuringVAIBUSDLPToken is ReentrancyGuard {

    using SafeMath for uint256;
    uint256 public version = 100;
    address public owner;
    
    IBEP20 public want; // TUR
    IBEP20 public TURING;
    address public wbnb;
    address public busd;

    IMiningMachine public miningMachine;
    IPancakeSwapRouter public pancakeSwap;
    ITuringswapWhitelist public whitelistContract; 

    uint256 public pidOfMining;
    uint256 public totalShare = 0;
    mapping(address => uint256) public shareOf;

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
        require(msg.sender == owner, 'INVALID_PERMISTION');
        _;
    }
    modifier onlyWhitelist()
    {
        if (msg.sender != tx.origin) {
            require(whitelistContract.whitelisted(msg.sender) == true, 'INVALID_WHITELIST');
        }
        _;
    }
    event onDeposit(address _user, uint256 _amount);
    event onWithdraw(address _user, uint256 _amount);
    event onEmergencyWithdraw(address _user, uint256 _amount);

    event onQueuedTransactionsChangeAddress(string _functionName, string _fieldName, address _value);
    event onQueuedTransactionsChangeUint(string _functionName, string _fieldName, uint256 _value);
    event onCancelTransactions(string _functionName);

    constructor(
        IPancakeSwapRouter _pancakeSwap,
        ITuringswapWhitelist _whitelistContract,
        IBEP20 _want,
        IBEP20 _turing,
        address _wbnb,
        address _busd
        ) public {
        owner = msg.sender;
        pancakeSwap = _pancakeSwap;
        whitelistContract = _whitelistContract;
        TURING = _turing;
        want = _want;
        wbnb = _wbnb;
        busd = _busd;
    }

    receive() external payable {
        
    }

    function setWhitelistContract(ITuringswapWhitelist _whitelistContract) public onlyOwner {
        whitelistContract = _whitelistContract;
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

    function transferOwnership() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('transferOwnership'))];
        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('owner'))] != address(0), "INVALID_ADDRESS");

        owner = _timelock.addressOf[keccak256(abi.encode('owner'))];
        _timelock.queuedTransactions = false;
    }

     function setMiningMachine() public onlyOwner 
     {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setMiningMachine'))];
        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('miningMachine'))] != address(0), "INVALID_ADDRESS");

        miningMachine = IMiningMachine(_timelock.addressOf[keccak256(abi.encode('miningMachine'))]);
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

    function setPidOfMining() public onlyOwner 
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPidOfMining'))];
        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('pidOfMining'))] > 0, "INVALID_AMOUNT");

        pidOfMining = _timelock.uintOf[keccak256(abi.encode('pidOfMining'))];
        _timelock.queuedTransactions = false;
    }

    function _validateTimelock(TimeLock memory _timelock) private view
    {
        require(_timelock.queuedTransactions == true, "Transaction hasn't been queued.");
        require(_timelock.timeOfExecute <= block.timestamp, "Transaction hasn't surpassed time lock.");
        require(_timelock.timeOfExecute.add(GRACE_PERIOD) >= block.timestamp, "Transaction is stale.");
    }

    function deposit(uint256 _wantAmt) external nonReentrant onlyWhitelist
    {   
        uint256 _userBal = want.balanceOf(msg.sender);
        if (_userBal < _wantAmt) {
            _wantAmt = _userBal;
        }
        require(_wantAmt > 0, 'INVALID_INPUT');
        require(_userBal >= _wantAmt, 'INVALID_INPUT');

        harvest(msg.sender);
    	want.transferFrom(msg.sender, address(this), _wantAmt);
        shareOf[msg.sender] = shareOf[msg.sender].add(_wantAmt);
        totalShare = totalShare.add(_wantAmt);
        miningMachine.updateUser(pidOfMining, msg.sender);
        emit onDeposit(msg.sender, _wantAmt);

    }
    function withdraw(uint256 _wantAmt) external nonReentrant onlyWhitelist
    {
        require(_wantAmt > 0, 'INVALID_INPUT');   
        harvest(msg.sender);

        uint256 _share = shareOf[msg.sender];
        if (_share < _wantAmt) {
            _wantAmt = _share;
        }
        require(_share >= _wantAmt, 'INVALID_AMOUNT_WITHDRAW');

        shareOf[msg.sender] = shareOf[msg.sender].sub(_wantAmt);
        totalShare = totalShare.sub(_wantAmt);
        uint256 _wantBal = want.balanceOf(address(this)); 
        if (_wantBal < _wantAmt) {
            _wantAmt = _wantBal;
        }
        want.transfer(msg.sender, _wantAmt);
        
        miningMachine.updateUser(pidOfMining, msg.sender);
    	// 
        emit onWithdraw(msg.sender, _wantAmt);
    }
    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public onlyWhitelist
    {
        uint256 _share = shareOf[msg.sender];
        require(_share > 0, 'INVALID_AMOUNT');

        shareOf[msg.sender] = 0;
        totalShare = totalShare.sub(_share);
        uint256 _wantBal = want.balanceOf(address(this));
        if (_wantBal < _share) {
            _share = _wantBal;
        }

        want.transfer(msg.sender, _share);

        emit onEmergencyWithdraw(msg.sender, _share);
    }

    function harvest(address _user) public onlyWhitelist returns(uint256 _pendingTur, uint256 _bonus) { 
        return miningMachine.harvest(pidOfMining, _user);
    }

    function getData(
        address _user
    ) 
    public 
    view
    returns(
        uint256 miningSpeed_,
        uint256 userWantBal_, 
        uint256 turingPrice_, 
        uint256 totalMintPerDay_, 
        uint256 userTuringPending_, 
        uint256 userWantShare_, 
        uint256 tradeAPY_,
        uint256 supplyAPY_,
        uint256 xvsAPY_,
        uint256 vol_,
        uint256 tvl_
    ) {
        userWantBal_ = want.balanceOf(_user);
        turingPrice_ = getTuringPrice();
        totalMintPerDay_ = miningMachine.getTotalMintPerDayOf(pidOfMining);
        miningSpeed_ = miningMachine.getMiningSpeedOf(pidOfMining);
        
        (userTuringPending_, , ) = miningMachine.getUserInfo(pidOfMining, _user);
        
        userWantShare_ = shareOf[_user];
        tvl_ = totalShare;

        ITuringswapFarmVenus _farmContract = SwapTrade(address(want)).farmContract();
        ITuringswapFeeMachine _feeMachineContract = SwapTrade(address(want)).feeMachineContract();
        tradeAPY_ = _feeMachineContract.getTradeFeeAPY(want);
        supplyAPY_ = _farmContract.getSupplyApy();
        xvsAPY_ = _farmContract.getXVSApy();
        vol_ = _feeMachineContract.getVolume(address(want));
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
}