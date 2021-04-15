// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IPancakeSwapRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
   
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
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

contract Pancake {
	using SafeMath for uint256;
	IPancakeSwapRouter public pancakeSwapContract;
	address public wbnb;

	constructor(
        IPancakeSwapRouter _pancakeSwapContract,
        address _wbnb
        ) public {
      	pancakeSwapContract = _pancakeSwapContract;
      	wbnb = _wbnb;
    }
    // BUSD -> CAKE -> WBNB -> BUSD
    function estimateSwapWithCase1(uint256 amountIn, address[] calldata path) public view returns(uint256[3] memory data_) {
    	uint256[] memory _amounts; 
    	_amounts = pancakeSwapContract.getAmountsOut(amountIn, path);
    	address[] memory _path2 = new address[](3);
    	_path2[0] = path[1];
    	_path2[1] = wbnb;
    	_path2[2] = path[0];

    	_amounts = pancakeSwapContract.getAmountsOut(_amounts[1], _path2);

    	uint256 _amountOut = _amounts[2];

    	data_[0] = amountIn;
    	data_[1] = _amountOut;

    	if (_amountOut > amountIn) {
    		data_[2] = (_amountOut.sub(amountIn)).mul(10000).div(amountIn);
    	}
    }
    // BUSD -> WBNB -> CAKE -> BUSD
    function estimateSwapWithCase2(uint256 amountIn, address[] calldata path) public view returns(uint256[3] memory data_) {
    	uint256[] memory _amounts; 
    	address[] memory _path1 = new address[](3);
    	_path1[0] = path[0];
    	_path1[1] = wbnb;
    	_path1[2] = path[1];

    	_amounts = pancakeSwapContract.getAmountsOut(amountIn, _path1);

    	address[] memory _path2 = new address[](2);
    	_path2[0] = path[1];
    	_path2[1] = path[0];

    	_amounts = pancakeSwapContract.getAmountsOut(_amounts[2], _path2);

    	uint256 _amountOut = _amounts[1];
    	data_[0] = amountIn;
    	data_[1] = _amountOut;

    	if (_amountOut > amountIn) {
    		data_[2] = (_amountOut.sub(amountIn)).mul(10000).div(amountIn);
    	}
    }
}