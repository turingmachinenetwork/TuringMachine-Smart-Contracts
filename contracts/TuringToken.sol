// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IBEP20.sol';
import './library/SafeMath.sol';

contract TuringToken is IBEP20 {

    using SafeMath for uint256;

    address public owner;

    mapping(bytes32 => TimeLock) public timeLockOf;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint256 private _maxTotalSupply = 628318 * 1e18;

    string public name = 'TuringMachine Token';
    string public symbol = 'Turing';
    uint8 public decimals = 18;

    address public miningMachine;
    address public performanceMachine;

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

    modifier onlyMiningMachine()
    {
        require(msg.sender == miningMachine, 'INVALID_PERMISSION');
        _;
    }

     modifier onlyPerformanceMachine()
    {
        require(msg.sender == performanceMachine, 'INVALID_PERMISSION');
        _;
    }

    event onQueuedTransactionsChangeAddress(string _functionName, string _fieldName, address _value);
    event onQueuedTransactionsChangeUint(string _functionName, string _fieldName, uint256 _value);
    event onCancelTransactions(string _functionName);

    constructor() public {
        owner = msg.sender;
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

    function setMiningMachine() public onlyOwner {
        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setMiningMachine'))];

        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('miningMachine'))] != address(0), "INVALID_ADDRESS");

        miningMachine = _timelock.addressOf[keccak256(abi.encode('miningMachine'))];
        delete _timelock.addressOf[keccak256(abi.encode('miningMachine'))];
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

    function setMaxTotalSupply() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setMaxTotalSupply'))];

        _validateTimelock(_timelock);
        require(_timelock.uintOf[keccak256(abi.encode('_maxTotalSupply'))] > 0, "INVALID_AMOUNT");

        _maxTotalSupply = _timelock.uintOf[keccak256(abi.encode('_maxTotalSupply'))];
        delete _timelock.uintOf[keccak256(abi.encode('_maxTotalSupply'))];
        _timelock.queuedTransactions = false;
    }

    function _validateTimelock(TimeLock memory _timelock) private view {
        require(_timelock.queuedTransactions == true, "Transaction hasn't been queued.");
        require(_timelock.timeOfExecute <= block.timestamp, "Transaction hasn't surpassed time lock.");
        require(_timelock.timeOfExecute.add(GRACE_PERIOD) >= block.timestamp, "Transaction is stale.");
    }

    function getAddressChangeOnTimeLock(string memory _functionName, string memory _fieldName) public view returns(address) {
        return timeLockOf[keccak256(abi.encode(_functionName))].addressOf[keccak256(abi.encode(_fieldName))];
    }

    function getUintChangeOnTimeLock(string memory _functionName, string memory _fieldName) public view returns(uint256) {
        return timeLockOf[keccak256(abi.encode(_functionName))].uintOf[keccak256(abi.encode(_fieldName))];
    }

    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }

    function maxTotalSupply() public view returns (uint256) {
        return _maxTotalSupply;
    }

    function balanceOf(address _addr) public override view returns (uint256) {
        return _balances[_addr];
    }

    function allowance(address _owner, address _spender)
        public
        virtual
        override
        view
        returns (uint256)
    {
        return _allowances[_owner][_spender];
    }

    function mint(address account, uint256 amount) public virtual override onlyMiningMachine {

        require(account != address(0), 'BEP20: mint to the zero address');

        if (_totalSupply > _maxTotalSupply) {
            amount = 0;
        } else if (_totalSupply.add(amount) > _maxTotalSupply) {
            amount = _maxTotalSupply.sub(_totalSupply);
        }

        require(_totalSupply.add(amount) <= _maxTotalSupply, 'over maxTotalSupply');

        _totalSupply = _totalSupply.add(amount);

        _balances[account] = _balances[account].add(amount);

        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint256 amount) public virtual override onlyPerformanceMachine {

        _balances[account] = _balances[account].sub(amount);

        _totalSupply = _totalSupply.sub(amount);

        emit Transfer(account, address(0), amount);
    }

    function approve(address _spender, uint256 _amount)
        public
        virtual
        override
        returns (bool)
    {
        require(_spender != address(0), "INVALID_SPENDER");

        _allowances[msg.sender][_spender] = _amount;

        emit Approval(msg.sender, _spender, _amount);

        return true;
    }

    function transfer(address _to, uint256 _amount)
        public
        virtual
        override
        returns (bool)
    {
        require(_amount > 0, 'INVALID_AMOUNT');
        require(_balances[msg.sender] >= _amount, 'INVALID_BALANCE');

        _balances[msg.sender] = _balances[msg.sender].sub(_amount);
        _balances[_to]        = _balances[_to].add(_amount);
        /*------------------------ emit event ------------------------*/
        emit Transfer(msg.sender, _to, _amount);
        /*----------------------- response ---------------------------*/
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public virtual override returns (bool) {
        require(_amount > 0, 'INVALID_AMOUNT');
        require(_balances[_from] >= _amount, 'INVALID_BALANCE');
        require(_allowances[_from][_to] >= _amount, 'INVALID_PERMISSION');
        require(_to == msg.sender, 'INVALID_PERMISSION');
        
        _allowances[_from][_to] = _allowances[_from][_to].sub(_amount);
        _balances[_from]    = _balances[_from].sub(_amount);
        _balances[_to]      = _balances[_to].add( _amount);
        /*------------------------ emit event ------------------------*/
        emit Transfer(_from, _to, _amount);
        /*----------------------- response ---------------------------*/
        return true;
    }
}