// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import '../../interfaces/IBEP20.sol';
import '../library/SafeMath.sol';

contract MockVToken is IBEP20 {

    using SafeMath for uint256;

    address public owner;
    IBEP20 public BASE;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string public name;
    string public symbol;
    uint8 public decimals = 18;

    uint256 public baseRewardPerBlock = 1000000000; // 0.000000001
    // uint256 public lastBlock = block.number;
    mapping(address => uint256) public lastBlockOf;

    constructor(string memory name_, string memory symbol_, IBEP20 _base) public {
        owner = msg.sender;
        name = name_;
        symbol = symbol_;
        BASE = _base;
    }
    function countBlock(address _user) public view returns(uint256) {
        return block.number.sub(lastBlockOf[_user]);
    }
    function changeBaseRewardPerBlock(uint256 _value) public {
        baseRewardPerBlock = _value;
    }
    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
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
    function mint(address account, uint256 amount) public virtual override {
        
        require(account != address(0), 'BEP20: mint to the zero address');

        _totalSupply = _totalSupply.add(amount);

        _balances[account] = _balances[account].add(amount);

        emit Transfer(address(0), account, amount);
    }
    function mint(uint mintAmount) external returns (uint) {
        
        BASE.transferFrom(msg.sender, address(this), mintAmount);

        _totalSupply = _totalSupply.add(mintAmount);

        _balances[msg.sender] = _balances[msg.sender].add(mintAmount);

        lastBlockOf[msg.sender] = block.number;

        emit Transfer(address(0), msg.sender, mintAmount);
    }

    function redeem(uint redeemTokens) external returns (uint) {
        if (redeemTokens > _balances[msg.sender]) {
            redeemTokens = _balances[msg.sender];
        }
        if (redeemTokens <= 0) {
            return 0;
        }
        uint256 _interest = getInterest(msg.sender);
        if (_interest > 0) {
            BASE.mint(address(this), _interest);
        }

        _totalSupply = _totalSupply.sub(redeemTokens);

        _balances[msg.sender] = _balances[msg.sender].sub(redeemTokens);

        uint256 _amtBase = redeemTokens.add(_interest);
        if (_amtBase > 0) {
            BASE.transfer(msg.sender, _amtBase);
        }

        lastBlockOf[msg.sender] = block.number;

        return _amtBase;
    }


    /**
     * @notice Get a snapshot of the account's balances, and the cached exchange rate
     * @dev This is used by comptroller to more efficiently perform liquidity checks.
     * @param account Address of the account to snapshot
     * @return (possible error, token balance, borrow balance, exchange rate mantissa)
     */
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint) {

        uint256 supplyBal = _balances[account];

        uint256 blockDif = countBlock(account);

        if (blockDif <= 0) {
            return (0, supplyBal, 0, 1e18);
        }

        uint256 exchangeRateMantissa = blockDif.mul(baseRewardPerBlock).add(1e18);
        
        return (0, supplyBal, 0, exchangeRateMantissa);
    }

    function getInterest(address account) public view returns(uint256) {

        uint256 supplyBal = _balances[account];

        uint256 blockDif = countBlock(account);

        if (blockDif <= 0) {
            return 0;
        }

        uint256 exchangeRateMantissa = blockDif.mul(baseRewardPerBlock).add(1e18);
        uint256 actSupplyBal = supplyBal.mul(exchangeRateMantissa).div(1e18);

        if (supplyBal >= actSupplyBal) {
            return 0;
        }

        return actSupplyBal.sub(supplyBal);
    }

    function burn(address account, uint256 amount) public virtual override  {

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
        
        _allowances[_from][_to] = _allowances[_from][_to].sub(_amount);
        _balances[_from]    = _balances[_from].sub(_amount);
        _balances[_to]      = _balances[_to].add( _amount);
        /*------------------------ emit event ------------------------*/
        emit Transfer(_from, _to, _amount);
        /*----------------------- response ---------------------------*/
        return true;
    }
}