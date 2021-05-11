/**
 *Submitted for verification at BscScan.com on 2021-04-13
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IBEP20 {
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract ITuringFarm {

   uint256 public totalShare;

   IBEP20 public want;

   mapping(address => uint256) public shareOf; 
}
interface IPancakeSwapRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) 
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

library SafeMath {
  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    require(c / a == b, 'INVALID_MUL');
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0, 'INVALID_DIV'); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, 'INVALID_SUB');
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, 'INVALID_ADD');
    return c;
  }
}
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

    function setPancakeSwapContract() public onlyOwner {

        TimeLock storage _timelock = timeLockOf[keccak256(abi.encode('setPancakeSwapContract'))];

        _validateTimelock(_timelock);
        require(_timelock.addressOf[keccak256(abi.encode('pancakeSwap'))] != address(0), "INVALID_ADDRESS");

        pancakeSwap = IPancakeSwapRouter(_timelock.addressOf[keccak256(abi.encode('pancakeSwap'))]);
        delete _timelock.addressOf[keccak256(abi.encode('pancakeSwap'))];
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