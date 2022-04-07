// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

library SafeMath {
  /**
   * @dev Returns the addition of two unsigned integers, reverting on
   * overflow.
   *
   * Counterpart to Solidity's `+` operator.
   *
   * Requirements:
   * - Addition cannot overflow.
   */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "SafeMath: addition overflow");

    return c;
  }

  /**
   * @dev Returns the subtraction of two unsigned integers, reverting on
   * overflow (when the result is negative).
   *
   * Counterpart to Solidity's `-` operator.
   *
   * Requirements:
   * - Subtraction cannot overflow.
   */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    return sub(a, b, "SafeMath: subtraction overflow");
  }

  /**
   * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
   * overflow (when the result is negative).
   *
   * Counterpart to Solidity's `-` operator.
   *
   * Requirements:
   * - Subtraction cannot overflow.
   */
  function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b <= a, errorMessage);
    uint256 c = a - b;

    return c;
  }

  /**
   * @dev Returns the multiplication of two unsigned integers, reverting on
   * overflow.
   *
   * Counterpart to Solidity's `*` operator.
   *
   * Requirements:
   * - Multiplication cannot overflow.
   */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "SafeMath: multiplication overflow");

    return c;
  }

  /**
   * @dev Returns the integer division of two unsigned integers. Reverts on
   * division by zero. The result is rounded towards zero.
   *
   * Counterpart to Solidity's `/` operator. Note: this function uses a
   * `revert` opcode (which leaves remaining gas untouched) while Solidity
   * uses an invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return div(a, b, "SafeMath: division by zero");
  }

  /**
   * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
   * division by zero. The result is rounded towards zero.
   *
   * Counterpart to Solidity's `/` operator. Note: this function uses a
   * `revert` opcode (which leaves remaining gas untouched) while Solidity
   * uses an invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    // Solidity only automatically asserts when dividing by 0
    require(b > 0, errorMessage);
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
   * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
   * Reverts when dividing by zero.
   *
   * Counterpart to Solidity's `%` operator. This function uses a `revert`
   * opcode (which leaves remaining gas untouched) while Solidity uses an
   * invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    return mod(a, b, "SafeMath: modulo by zero");
  }

  /**
   * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
   * Reverts with custom message when dividing by zero.
   *
   * Counterpart to Solidity's `%` operator. This function uses a `revert`
   * opcode (which leaves remaining gas untouched) while Solidity uses an
   * invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b != 0, errorMessage);
    return a % b;
  }
}

interface IVVSRouter {
        function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}
interface ITuringTimelock {
        function isQueuedTransaction(address _contractRequest, string memory _fn) external view returns(bool);
        function doneTransaction(string memory _fn) external;
}
interface ITuringWhitelist {
        function isWhitelisted(address _address) external view returns (bool);
}
contract OraclePrice {
        using SafeMath for uint256;
        address public owner;
        ITuringTimelock public TuringTimelockContract;
        ITuringWhitelist public TuringWhitelistContract;
        IVVSRouter public VVSRouter;
        
        
        mapping(address => uint256) public priceOf; // price token to cro;
        mapping(address => uint256) public updatedAtOf; 
        mapping(address => uint256) public decimalOf;  // token => decimal
        address public WCRO;

        uint256 public MAX_UPDATE_RATE = 2000; // 20 % 
        uint256 public MAX_RATE = 10000; // 100 % 
        uint256 public PERIOD_UPDATE = 60 * 60;

        modifier onlyOwner()
        {
                require(msg.sender == owner, 'INVALID_PERMISSION');
                _;
        }
        modifier isQueued(string memory _fn) 
        {
                require(TuringTimelockContract.isQueuedTransaction(address(this), _fn) == true, 'INVALID_PERMISTION');
                _;
                TuringTimelockContract.doneTransaction(_fn);
        }
        modifier onlyWhitelisted()
        {
                if (msg.sender != tx.origin) {
                        require(TuringWhitelistContract.isWhitelisted(msg.sender) == true, 'INVALID_WHITELIST');
                }
                _;
        }
        constructor(
                ITuringTimelock _turingTimeLockContract,
                ITuringWhitelist _turingWhitelistContract,
                IVVSRouter _vvsRouter, 
                address _wcro
                ) {
                owner = msg.sender;
                TuringTimelockContract = _turingTimeLockContract;
                TuringWhitelistContract = _turingWhitelistContract;
                VVSRouter = _vvsRouter;
                WCRO = _wcro;
        }
        function changeOwner(address _owner) public onlyOwner isQueued("changeOwner")
        {
                owner = _owner;
        }
        function setTokenDecimal(address _token, uint256 _value) public onlyOwner isQueued("setTokenDecimal")
        {
                decimalOf[_token] = _value;
        } 
        function changeVVSRouter(IVVSRouter _vvsRouter) public onlyOwner isQueued("changeVVSRouter")
        {
                VVSRouter = _vvsRouter;
        }
        function changeWCRO(address _wcro) public onlyOwner isQueued("changeWCRO")
        {
                WCRO = _wcro;
        }
        function changeMaxUpdateRate(uint256 _rate) public onlyOwner isQueued("changeMaxUpdateRate")
        {
                require(MAX_UPDATE_RATE <= MAX_RATE, 'INVALID_RATE');
                MAX_UPDATE_RATE = _rate;
        }
        function changePeriodUpate(uint256 _value) public onlyOwner isQueued("changePeriodUpate")
        {
                PERIOD_UPDATE = _value;
        }
        function getPrice(address _token) public view returns(uint256) 
        {
                if (_token == WCRO) return 1e18;
                address[] memory path = new address[](2);

                path[0] = _token;
                path[1] = WCRO;
                uint256 _pTokenToWCRO;

                try VVSRouter.getAmountsOut(10 ** decimalOf[_token], path) returns(uint[] memory amounts) {
                        _pTokenToWCRO = amounts[1];
                } catch {
                        _pTokenToWCRO = 0;   
                }
                return _pTokenToWCRO;
        }
        function syncPrice(address _token) public onlyWhitelisted {
                // block.timestamp;
                require(block.timestamp >= updatedAtOf[_token].add(PERIOD_UPDATE), 'INVALID_TIME');
                uint256 _price = getPrice(_token);
                uint256 _nextPriceMax = priceOf[_token].mul(MAX_UPDATE_RATE.add(MAX_RATE)).div(MAX_RATE);
                uint256 _nextPriceMin = priceOf[_token].mul(MAX_RATE.sub(MAX_UPDATE_RATE)).div(MAX_RATE);
                if (priceOf[_token] > 0) {
                        _price = _price > _nextPriceMax ? _nextPriceMax : _price;
                        _price = _price < _nextPriceMin ? _nextPriceMin : _price;
                } 
                priceOf[_token] = _price;
                updatedAtOf[_token] = block.timestamp;
        }
}
