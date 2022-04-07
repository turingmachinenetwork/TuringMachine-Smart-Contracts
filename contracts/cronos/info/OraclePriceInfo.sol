// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;


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

interface IOraclePrice {
	function priceOf(address _token) external view returns (uint256);
  function getPrice(address _token) external view returns (uint256);
	function updatedAtOf(address _token) external view returns (uint256);
	function MAX_UPDATE_RATE() external view returns (uint256);
	function MAX_RATE() external view returns (uint256);
	function PERIOD_UPDATE() external view returns (uint256);
}

contract OraclePriceInfo {
	using SafeMath for uint256;
  IOraclePrice public OraclePriceContract;
	struct OraclePrice {
		uint256 currentPrice;
		uint256 priceOnVVS;
		uint256 nextPrice;
		uint256 nextUpdateTime;
	}
  constructor(
                IOraclePrice _oraclePriceContract
                ) public {
                OraclePriceContract = _oraclePriceContract;
                
        }
	function getData(address[] calldata _tokens) public view returns(OraclePrice[] memory data_)
	{
		data_ = new OraclePrice[](_tokens.length);
		for (uint256 idx = 0; idx < _tokens.length; idx++) {
			data_[idx].currentPrice = OraclePriceContract.priceOf(_tokens[idx]);
			uint256 _price = OraclePriceContract.getPrice(_tokens[idx]);
			uint256 _updatedAt = OraclePriceContract.updatedAtOf(_tokens[idx]);
			uint256 _period = OraclePriceContract.PERIOD_UPDATE();
			uint256 _maxUpdateRate = OraclePriceContract.MAX_UPDATE_RATE();
			uint256 _maxRate = OraclePriceContract.MAX_RATE();
			data_[idx].nextUpdateTime  = _updatedAt.add(_period); 
			data_[idx].priceOnVVS = _price;
			
			uint256 _nextPriceMax = data_[idx].currentPrice.mul(_maxUpdateRate.add(_maxRate)).div(_maxRate);
      uint256 _nextPriceMin = data_[idx].currentPrice.mul(_maxRate.sub(_maxUpdateRate)).div(_maxRate);
      if (data_[idx].currentPrice > 0) {
	        _price = _price > _nextPriceMax ? _nextPriceMax : _price;
	        _price = _price < _nextPriceMin ? _nextPriceMin : _price;
	    } 
	    data_[idx].nextPrice = _price;
		}
	}
}
