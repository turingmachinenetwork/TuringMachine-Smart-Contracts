// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IBEP20.sol';
import './interfaces/IPancakeSwapRouter.sol';

contract PerformanceMachine {
    
    IPancakeSwapRouter public pancakeSwap;

    uint256 public version = 100;

    IBEP20 public turingTokenContract;
    IBEP20 public WBNB;


    constructor(
        IPancakeSwapRouter _pancakeSwap,
        IBEP20 _turingContract,
        IBEP20 _wbnb
    ) public {
        WBNB = _wbnb;
        pancakeSwap = _pancakeSwap;
        turingTokenContract = _turingContract;
    }

    function connectToPancake(IBEP20 _token) public {
        require(msg.sender == tx.origin, 'INVALID_PERMISSION');
        _token.approve(address(pancakeSwap), uint256(-1));
    }
    function burnToken(IBEP20 _token) public {

        uint256 _tokenBal = getTokenBal(_token);

        require(msg.sender == tx.origin, 'INVALID_PERMISSION');
        require(address(turingTokenContract) != address(_token), 'INVALID_PERMISSION');
        
        if (
            address(_token) != address(WBNB) &&
            _tokenBal > 0   
        ) {
            address[] memory path = new address[](3);
            path[0] = address(_token);
            path[1] = address(WBNB);
            path[2] = address(turingTokenContract);
            pancakeSwap.swapExactTokensForTokens(_tokenBal, 0, path, address(this), block.timestamp);
        } 
        // burn turing token
        uint256 _turingBal = turingTokenContract.balanceOf(address(this));
        if (_turingBal > 0) {
            turingTokenContract.burn(address(this), _turingBal);
        }
    }

    function getTokenBal(IBEP20 _token) public view returns(uint256) {
        return _token.balanceOf(address(this));
    }
}