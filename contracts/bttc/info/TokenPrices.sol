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

interface IVVSRouter {
        function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}
interface ILPToken {
        function decimals() external pure returns (uint8);
        function totalSupply() external view returns (uint);
        function token0() external view returns (address);
        function token1() external view returns (address);
        function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}
contract TokenPrices {
        using SafeMath for uint256;
        address public owner;
        IVVSRouter public VVSRouter;

        mapping(address => uint256) public decimalOf;  // token => decimal
        mapping(address => bool) public isLP;  // token => decimal        

        address public WCRO;
        address public USDC;

        struct Price {
                uint256 pTokenToUSDC;
                uint256 pTokenToWCRO;
        }

        modifier onlyOwner()
        {
                require(msg.sender == owner, 'INVALID_PERMISSION');
                _;
        }

        constructor(
                IVVSRouter _vvsRouter, 
                address _wcro,
                address _usdc
                ) public {
                owner = msg.sender;
                VVSRouter = _vvsRouter;
                WCRO = _wcro;
                USDC = _usdc;
        }
        function changeOwner(address _owner) public onlyOwner 
        {
                owner = _owner;
        }
        function setTokenDecimal(address _token, uint256 _value) public onlyOwner 
        {
                decimalOf[_token] = _value;
        } 
        function changeVVSRouter(IVVSRouter _vvsRouter) public onlyOwner 
        {
                VVSRouter = _vvsRouter;
        }
        function changeWCRO(address _wcro) public onlyOwner 
        {
                WCRO = _wcro;
        }
        function changeUSDC(address _usdc) public onlyOwner 
        {
                USDC = _usdc;
        }
        function setIsLP(address _token, uint8 _isLP) public onlyOwner 
        {
                if (_isLP == 1) {
                        isLP[_token] = true;
                } else {
                        isLP[_token] = false;
                }       
        }
        // LP
        function getPriceOfLPToWCRO(ILPToken _lp) public view returns(uint256) {
                address _token0      = _lp.token0();
                address _token1      = _lp.token1();
                uint256 _totalSupply = _lp.totalSupply();
                uint112 _reserve0;
                uint112 _reserve1;
                (_reserve0, _reserve1, ) = _lp.getReserves();
                uint256 _pToken0 = getPriceOfTokenToWCRO(_token0);
                uint256 _pToken1 = getPriceOfTokenToWCRO(_token1);
                uint256 _totalAssetByWCRO = (
                        (
                                convertDecimals(_token0, uint256(_reserve0))
                                .mul(_pToken0)
                        ).add(
                                convertDecimals(_token1, uint256(_reserve1))
                                .mul(_pToken1)
                        )
                ).div(1e18);
                if (_totalSupply <= 0) return 0;
                return _totalAssetByWCRO.mul(1e18).div(convertDecimals(address(_lp), _totalSupply));
        }
        function getPriceOfLPToUSDC(ILPToken _lp) public view returns(uint256) {
                address _token0      = _lp.token0();
                address _token1      = _lp.token1();
                uint256 _totalSupply = _lp.totalSupply();
                uint112 _reserve0;
                uint112 _reserve1;
                (_reserve0, _reserve1, ) = _lp.getReserves();
                uint256 _pToken0 = getPriceOfTokenToUSDC(_token0);
                uint256 _pToken1 = getPriceOfTokenToUSDC(_token1);
                uint256 _totalAssetByWCRO = (
                        (
                                convertDecimals(_token0, uint256(_reserve0))
                                .mul(_pToken0)
                        ).add(
                                convertDecimals(_token1, uint256(_reserve1))
                                .mul(_pToken1)
                        )
                ).div(1e18);
                if (_totalSupply <= 0) return 0;
                return _totalAssetByWCRO.mul(1e18).div(convertDecimals(address(_lp), _totalSupply));
        }
        // Token
        function getPriceOfTokenToWCRO(address _token) public view returns(uint256) 
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
        function getPriceOfTokenToUSDC(address _token) public view returns(uint256) 
        {
                if (_token == USDC) return 1e18; 
                uint256 _pWCROToUSDC;
                address[] memory path = new address[](2);
                path[0] = WCRO;
                path[1] = USDC;
                try VVSRouter.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
                        _pWCROToUSDC = amounts[1];
                } catch {
                        _pWCROToUSDC = 0;   
                }
                if (_token == WCRO) return _pWCROToUSDC.mul(1e18).div(1e6);

                path[0] = _token;
                path[1] = WCRO;
                uint256 _pTokenToWCRO;

                try VVSRouter.getAmountsOut(10 ** decimalOf[_token], path) returns(uint[] memory amounts) {
                        _pTokenToWCRO = amounts[1];
                } catch {
                        _pTokenToWCRO = 0;   
                }
                uint256 _price = _pTokenToWCRO.mul(_pWCROToUSDC).div(1e6);
                return _price;
        }
        function convertDecimals(address _token, uint256 _amount) public view returns(uint256) {
                return _amount.mul(1e18).div(10 ** decimalOf[_token]);
        }

        function getData(address[] calldata _tokens) public view returns(Price[] memory data_)
        {
                data_ = new Price[](_tokens.length);
                for (uint256 idx = 0; idx < _tokens.length; idx++) {
                        if (isLP[_tokens[idx]] == true) {
                                data_[idx].pTokenToUSDC = getPriceOfLPToUSDC(ILPToken(_tokens[idx]));
                                data_[idx].pTokenToWCRO = getPriceOfLPToWCRO(ILPToken(_tokens[idx]));
                        } else {
                                data_[idx].pTokenToUSDC = getPriceOfTokenToUSDC(_tokens[idx]);
                                data_[idx].pTokenToWCRO = getPriceOfTokenToWCRO(_tokens[idx]);
                        }
                }
        }
}
