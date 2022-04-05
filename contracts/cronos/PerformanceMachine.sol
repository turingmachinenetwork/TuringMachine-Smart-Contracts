// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IBEP20.sol';
import './interfaces/ITuring.sol';
import './interfaces/IVVSRouter.sol';

contract PerformanceMachine {
    
    IVVSRouter public vvsSwap;

    uint256 public version = 100;

    ITuring public TUR;
    IBEP20 public WCRO;

    constructor(
        IVVSRouter _vvsSwap,
        ITuring _turing,
        IBEP20 _wcro
    ) public {
        WCRO = _wcro;
        vvsSwap = _vvsSwap;
        TUR = _turing;
    }

    function connectToVVS(IBEP20 _token) public {
        require(msg.sender == tx.origin, 'INVALID_PERMISSION');
        _token.approve(address(vvsSwap), uint256(-1));
    }
    function burnToken(IBEP20 _token) public {

        uint256 _tokenBal = getTokenBal(_token);

        require(msg.sender == tx.origin, 'INVALID_PERMISSION');
        require(address(TUR) != address(_token), 'INVALID_PERMISSION');
        
        if (
            address(_token) != address(WCRO) &&
            _tokenBal > 0   
        ) {
            address[] memory path = new address[](3);
            path[0] = address(_token);
            path[1] = address(WCRO);
            path[2] = address(TUR);
            vvsSwap.swapExactTokensForTokens(_tokenBal, 0, path, address(this), block.timestamp);
        } 
        // burn turing token
        uint256 _turingBal = TUR.balanceOf(address(this));
        if (_turingBal > 0) {
            TUR.burn(address(this), _turingBal);
        }
    }

    function getTokenBal(IBEP20 _token) public view returns(uint256) {
        return _token.balanceOf(address(this));
    }
}