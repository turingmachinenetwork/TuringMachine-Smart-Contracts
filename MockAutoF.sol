pragma solidity 0.6.12;

interface IERC20 {
    function mint(address account, uint256 amount) external;
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
contract MockAutoF {

    using SafeMath for uint256;
    IERC20 public AUTO;

    struct PoolInfo {
        IERC20 want; // Address of the want token.
        uint256 allocPoint; // How many allocation points assigned to this pool. AUTO to distribute per block.
        uint256 lastRewardBlock; // Last block number that AUTO distribution occurs.
        uint256 accAUTOPerShare; // Accumulated AUTO per share, times 1e12. See below.
        address strat; // Strategy address that will auto compound want tokens
    }

    PoolInfo[] public poolInfo; // Info of each pool.

    mapping(uint256 => mapping(address => uint256)) public balanceOf;
    mapping(uint256 => mapping(address => uint256)) public latestBlockOf;

    uint256 speedMintAuto = 1e12;
    uint256 speedMintWant = 1e13;

    constructor(
        IERC20 _AUTO
        ) public {
        AUTO = _AUTO;
    }
    function updateSpeed(uint256 _sAuto, uint256 _sWant) public {
        speedMintAuto = _sAuto;
        speedMintWant = _sWant;
    }
    function deposit(uint256 _pid, uint256 _wantAmt) external {

        PoolInfo storage pool = poolInfo[_pid];

        _updateState(_pid, msg.sender);
        
        if (_wantAmt > 0) {
            pool.want.transferFrom(msg.sender, address(this), _wantAmt);
        }
        balanceOf[_pid][msg.sender] += _wantAmt;
    }
    function withdraw(uint256 _pid, uint256 _wantAmt) external {

        PoolInfo storage pool = poolInfo[_pid];

        _updateState(_pid, msg.sender);

        require(balanceOf[_pid][msg.sender] >= _wantAmt, 'INVALID_BALANCE');

        pool.want.transfer(msg.sender, _wantAmt);

        balanceOf[_pid][msg.sender] = balanceOf[_pid][msg.sender].sub(_wantAmt);  
    }

    function pendingAUTO(uint256 _pid, address _user)
        public
        view
        returns (uint256) {
            if (balanceOf[_pid][_user] == 0) return 0;
            return getMultiplier(latestBlockOf[_pid][_user], block.number).mul(speedMintAuto);
        }
    function pendingWant(uint256 _pid, address _user)
        public
        view
        returns (uint256) {
            if (balanceOf[_pid][_user] == 0) return 0;
            return getMultiplier(latestBlockOf[_pid][_user], block.number).mul(speedMintWant);
        }
    function _updateState(uint256 _pid, address _user) private {

        uint256 _pendingAUTO = pendingAUTO(_pid, _user);
        uint256 _pendingWant = pendingWant(_pid, _user);

        AUTO.mint(_user, _pendingAUTO);

        poolInfo[_pid].want.mint(address(this), _pendingWant);

        balanceOf[_pid][_user] = balanceOf[_pid][_user].add(_pendingWant);

        latestBlockOf[_pid][msg.sender] = block.number;  
    }

    function stakedWantTokens(uint256 _pid, address _user)
        public
        view
        returns (uint256) {
            return balanceOf[_pid][_user].add(pendingWant(_pid, _user));
        }

    function add(
        IERC20 _want
    ) public {
       
        poolInfo.push(
            PoolInfo({
                want: _want,
                allocPoint: 0,
                lastRewardBlock: 0,
                accAUTOPerShare: 0,
                strat: msg.sender
            })
        );
    }
      // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_from + 10 > _to) {
            return 0;
        }
        return _to.sub(_from + 10);
    }
}