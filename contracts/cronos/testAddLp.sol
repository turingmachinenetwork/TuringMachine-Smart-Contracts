// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './library/SafeMath.sol';
import './interfaces/ITuringWhiteList.sol';
import './interfaces/ITuringTimeLock.sol';
import './interfaces/IBEP20.sol';
import './interfaces/IVVSRouter.sol';
import './interfaces/IDistributeTuring.sol';
import './interfaces/ITuringCroLpContract.sol';
import './interfaces/IPriceOracle.sol';

contract testAddLp {
    using SafeMath for uint256;
    using SafeMath for uint112;

    address public owner;

    IBEP20 public TURING;
    IBEP20 public TURING_CRO_LP;

    IVVSRouter public VVSRouterContract;
    ITuringCrpLpContract public TuirngCroLpContract;

    address public WCRO;

    uint256 private MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    uint256 public baseRatio = 1e18;
    uint256 public ratioCroAddLp = 8e17; // 80%
   
    modifier onlyOwner() {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }

    receive() external payable {}

    constructor(
        IVVSRouter _VVSRouterContract,
        ITuringCrpLpContract _TuirngCroLpContract,
        IBEP20 _TURING,
        IBEP20 _TURING_CRO_LP,
        address _WCRO
    ) {
        VVSRouterContract = _VVSRouterContract;
        TuirngCroLpContract = _TuirngCroLpContract;
        TURING_CRO_LP = _TURING_CRO_LP;
        TURING = _TURING;
        WCRO = _WCRO;

        owner = msg.sender;
    }

   

    function close() public onlyOwner {
        uint256 _croBalance;
        _croBalance = getCroBalance();
        _addLiquidity(_croBalance);

    }

    function _addLiquidity(uint256 _amtCroOnAddLp) private {
        uint112 _amtCroLpContract;
        uint112 _amtTuringLpContract;
        uint256 _amtTuringOnAddLp;

        (_amtCroLpContract, _amtTuringLpContract) = getReserves();
        _amtTuringOnAddLp = getEstimateTuringOnAddLp(_amtCroOnAddLp, _amtCroLpContract, _amtTuringLpContract);

        VVSRouterContract.addLiquidityETH{value: _amtCroOnAddLp}(address(TURING), _amtTuringOnAddLp, 1, 1, address(this), block.timestamp);
    }

       
    function getEstimateTuringOnAddLp(uint256 _amtCroOnAddLp, uint256 _amtCroLpContract, uint256 _amtTuringLpContract) public pure returns(uint256 _amtTuringOnAddLp) {
        _amtTuringOnAddLp = _amtTuringLpContract.mul(_amtCroOnAddLp).div(_amtCroLpContract);
    }

    function getReserves() public view returns(uint112 _amtCroLpContract, uint112 _amtTuringLpContract) {
        if(TuirngCroLpContract.token0() == WCRO) {
            (_amtCroLpContract, _amtTuringLpContract,) = TuirngCroLpContract.getReserves();
        }
        if(TuirngCroLpContract.token0() == address(TURING)) {
            (_amtTuringLpContract, _amtCroLpContract,) = TuirngCroLpContract.getReserves();
        }
    }

    function getCroBalance() public view returns(uint256) {
        return address(this).balance;
    }
}