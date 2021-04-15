pragma solidity 0.6.12;

interface IERC20 {
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

contract IAutoFarm {

	struct PoolInfo {
        IERC20 want; // Address of the want token.
        uint256 allocPoint; // How many allocation points assigned to this pool. AUTO to distribute per block.
        uint256 lastRewardBlock; // Last block number that AUTO distribution occurs.
        uint256 accAUTOPerShare; // Accumulated AUTO per share, times 1e12. See below.
        address strat; // Strategy address that will auto compound want tokens
    }

    PoolInfo[] public poolInfo; // Info of each pool.

	function deposit(uint256 _pid, uint256 _wantAmt) external {}
	function withdrawAll(uint256 _pid) external {}
	function withdraw(uint256 _pid, uint256 _wantAmt) external {}
	function pendingAUTO(uint256 _pid, address _user)
        external
        view
        returns (uint256) {}

     function stakedWantTokens(uint256 _pid, address _user)
        external
        view
        returns (uint256) {}
}

contract TestAutoF {

	IAutoFarm public cAutoFarm;

	constructor(
        IAutoFarm _cAutoFarm
        ) public {
        cAutoFarm = _cAutoFarm;
    }

    receive() external payable {
        
    }

    function connectToAutoFairm(uint256 _pid) public {
    	(IERC20 _want, , , ,) = cAutoFarm.poolInfo(_pid);
    	_want.approve(address(cAutoFarm), uint256(-1));
    } 

    function deposit(uint256 _pid, uint256 _wantAmt) external {

    	(IERC20 _want, , , ,) = cAutoFarm.poolInfo(_pid);

    	_want.transferFrom(msg.sender, address(this), _wantAmt);

    	cAutoFarm.deposit(_pid, _wantAmt);
    }

    function withdrawAll(uint256 _pid) external {
    	cAutoFarm.withdraw(_pid, uint256(-1));
    }
    function withdraw(uint256 _pid, uint256 _wantAmt) external {
    	cAutoFarm.withdraw(_pid, _wantAmt);
    }
     function getFund(uint256 _pid) external {

    	(IERC20 _want, , , ,) = cAutoFarm.poolInfo(_pid);

    	_want.transfer(msg.sender, _want.balanceOf(address(this)));
    }

    function pendingAUTO(uint256 _pid, address _user)
        public
        view
        returns (uint256) {
        return cAutoFarm.pendingAUTO(_pid, _user);
    }
    function stakedWantTokens(uint256 _pid, address _user)
        public
        view
        returns (uint256) {
        return cAutoFarm.stakedWantTokens(_pid, _user);
    }
    function getAmountWithdrawOf(uint256 _pid, address _user)
        public
        view
        returns (uint256) {
        uint256 _sAmount = cAutoFarm.stakedWantTokens(_pid, _user);
        uint256 _pAmount = cAutoFarm.pendingAUTO(_pid, _user);
        return _sAmount + _pAmount;
    }
}