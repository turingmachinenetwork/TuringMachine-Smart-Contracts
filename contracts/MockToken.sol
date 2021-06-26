pragma solidity >=0.6.12;

import './interfaces/IBEP20.sol';
import './library/SafeMath.sol';

contract MockToken is IBEP20 {

    using SafeMath for uint256;

    address public owner;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string public name;
    string public symbol;
    uint8 public decimals = 18;

    constructor(string memory name_, string memory symbol_) public {
        owner = msg.sender;
        name = name_;
        symbol = symbol_;
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