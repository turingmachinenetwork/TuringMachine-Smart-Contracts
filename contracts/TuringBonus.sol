// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

import './interfaces/ITuringFarm.sol';
import './interfaces/IPancakeSwapRouter.sol';
import './library/SafeMath.sol'; 

contract TuringBonus {

    uint256 public version = 100;

    using SafeMath for uint256;

    address public owner;
    // Dev Locked Contract.
    IPancakeSwapRouter public pancakeSwap;

    IBEP20 public TUR;
    IBEP20 public WBNB;

    uint256 public HOLD_BONUS_PERCENT = 20; // 20% mining
    uint256 public HOLD_BONUS_POINT = 20; // 20 %

    uint public constant GRACE_PERIOD = 30 days;
    uint public constant MINIMUM_DELAY = 2 days;
    uint public constant MAXIMUM_DELAY = 30 days;
    uint public delay;

    mapping(address => mapping(address => uint256)) public priceOfTurToAnotherToken;
    mapping(bytes32 => TimeLock) public timeLockOf;

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

    event onError(uint256 _pid, address _user, string _msg);

    event onQueuedTransactionsChangeAddress(string _functionName, string _fieldName, address _value);
    event onQueuedTransactionsChangeUint(string _functionName, string _fieldName, uint256 _value);
    event onCancelTransactions(string _functionName);

    constructor(
        IBEP20 _tur,
        IBEP20 _wbnb,
        IPancakeSwapRouter _pancakeSwap
    ) public {
        owner = msg.sender;
        TUR = _tur;
        WBNB = _wbnb;
        pancakeSwap = _pancakeSwap;
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

    function setBonusHolderConfig() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setBonusHolderConfig'))];

        _validateTimelock(_timelock);

    	HOLD_BONUS_PERCENT = _timelock.uintOf[keccak256(abi.encode('HOLD_BONUS_PERCENT'))];
    	HOLD_BONUS_POINT = _timelock.uintOf[keccak256(abi.encode('HOLD_BONUS_POINT'))];
        delete _timelock.uintOf[keccak256(abi.encode('HOLD_BONUS_PERCENT'))];
        delete _timelock.uintOf[keccak256(abi.encode('HOLD_BONUS_POINT'))];
        _timelock.queuedTransactions = false;
    }

    function setPriceOfTurToAnotherToken(address _tokenAddr) public onlyOwner
    {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPriceOfTurToAnotherToken'))];

        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('priceOfTurToAnotherToken'))] > 0, "INVALID_AMOUNT");

        priceOfTurToAnotherToken[address(TUR)][_tokenAddr] = _timelock.uintOf[keccak256(abi.encode('priceOfTurToAnotherToken'))];

        delete _timelock.uintOf[keccak256(abi.encode('priceOfTurToAnotherToken'))];
        _timelock.queuedTransactions = false;
    }

    function _validateTimelock(TimeLock memory _timelock) private view {
        require(_timelock.queuedTransactions == true, "Transaction hasn't been queued.");
        require(_timelock.timeOfExecute <= block.timestamp, "Transaction hasn't surpassed time lock.");
        require(_timelock.timeOfExecute.add(GRACE_PERIOD) >= block.timestamp, "Transaction is stale.");
    }


    function getBonusAmount(ITuringFarm _turingFarm, address _user, uint256 _turMint) external view returns(uint256) {
        uint256 _bonus = 0;
        uint256 _userShare  = _turingFarm.shareOf(_user);
        if (
            _turMint <= 0 || 
            _userShare <= 0
        ) {
            return _bonus;
        }
        uint256 _userTurBal = TUR.balanceOf(_user);
        uint256 _priceOfTurToWant = getPriceOfTurToAnotherToken(address(_turingFarm.want()));
        uint256 _userWantFromTur = _userTurBal.mul(_priceOfTurToWant).div(1e18);

        if (
            _userWantFromTur > 0 && 
            _userWantFromTur.mul(100).div(_userShare) > HOLD_BONUS_POINT 
        ) {
            _bonus = _turMint.mul(HOLD_BONUS_PERCENT).div(100);
        }
        return _bonus;
    }

    function getPriceOfTurToAnotherToken(address _tokenAddr) public view returns(uint256)
    {
        if (priceOfTurToAnotherToken[address(TUR)][_tokenAddr] > 0) {
            return priceOfTurToAnotherToken[address(TUR)][_tokenAddr];
        }
        // Get Price of Turing to want
        address[] memory path = new address[](3);

        path[0] = address(TUR);
        path[1] = address(WBNB);
        path[2] = _tokenAddr;

        uint256 _priceOfTurToWant = 0;
                
        try pancakeSwap.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
            _priceOfTurToWant = amounts[2];
        } catch {
            _priceOfTurToWant = 0;
        }
        return _priceOfTurToWant;
    }

    function getAddressChangeOnTimeLock(string memory _functionName, string memory _fieldName) public view returns(address) {
        return timeLockOf[keccak256(abi.encode(_functionName))].addressOf[keccak256(abi.encode(_fieldName))];
    }

    function getUintChangeOnTimeLock(string memory _functionName, string memory _fieldName) public view returns(uint256) {
        return timeLockOf[keccak256(abi.encode(_functionName))].uintOf[keccak256(abi.encode(_fieldName))];
    }
}