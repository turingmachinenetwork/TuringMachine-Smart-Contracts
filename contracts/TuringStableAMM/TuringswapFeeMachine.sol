// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './library/SafeMath.sol';
import './interfaces/IBEP20.sol';
import './interfaces/ITuringTimeLock.sol';
contract ISwapTrade {
    uint256 public TRADE_FEE; //0.2% 2/1000
} 
contract TuringswapFeeMachine {
    
    IBEP20 public TUR; // TUR

    using SafeMath for uint256;
    
    address public owner;
    address public performanceMachineContract; // the contract will use fee to Buy TURING on pancakeswap , then burn
    address public safuFundContract;

    ITuringTimeLock public turingTimeLockContract;

    uint256 public PERFORMANCE_FEE = 16; //16% 16/100 from 0.3% trade fee 
    uint256 public SAFU_FUND = 4; //4% 4/100 from 0.3% trade fee

    uint256 public DISTRIBUTE_TURING_AMOUNT = 2 * 1e17;
    // $1000 => fee = 1000*0.2/100 => 2
    uint256 public MAX_FEE_ON_DISTRIBUTE = 2 * 1e18;
    uint256 public DAY_PERIOD = 1 days;

    mapping (address => bool) public pairs;
    mapping (address => mapping(uint256 => uint256)) public feeOf;
    mapping (address => uint256) public timeOfCreateNewFee;
    mapping (address => uint256) public totalDays;

    modifier onlyOwner()
    {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }

    event onDistributeTuring(address _trader, uint256 _amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor(
        IBEP20 _tur,
        address _performanceMachineContract, 
        address _safuFundContract,
        ITuringTimeLock _turingTimeLockContract
        ) public {
        owner = msg.sender;
        turingTimeLockContract = _turingTimeLockContract;
        performanceMachineContract = _performanceMachineContract;
        safuFundContract = _safuFundContract;

        TUR = _tur;
    }

    /**
    * @dev Transfers ownership of the contract to a new account (`newOwner`).
    * Can only be called by the current owner.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setDayPeriod(uint256 _value) public onlyOwner {
        DAY_PERIOD = _value;
    }
    function addPair(address _pair) public onlyOwner {
        require(pairs[_pair] != true, "IN_THE_LIST");
        pairs[_pair] = true;
    }

    function removePair(address _pair) public onlyOwner {
        require(pairs[_pair] == true, "NOT_IN_THE_LIST");
        pairs[_pair] = false;
    }

    function setDistributeTuringAmount(uint256 _amount) public onlyOwner {
        DISTRIBUTE_TURING_AMOUNT = _amount;
    }


    function setPerformanceMachine() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setPerformanceMachine'), "INVALID_PERMISSION");

        address _performanceMachine = turingTimeLockContract.getAddressChangeOnTimeLock(address(this), 'setPerformanceMachine', 'performanceMachine');

        require(_performanceMachine != address(0), "INVALID_ADDRESS");

        performanceMachineContract = _performanceMachine;

        turingTimeLockContract.clearFieldValue('setPerformanceMachine', 'performanceMachine', 1);
        turingTimeLockContract.doneTransactions('setPerformanceMachine');
    }

    function setSafuFundContract() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setSafuFundContract'), "INVALID_PERMISSION");

        address _safuFundContract = turingTimeLockContract.getAddressChangeOnTimeLock(address(this), 'setSafuFundContract', 'safuFundContract');

        require(_safuFundContract != address(0), "INVALID_ADDRESS");

        safuFundContract = _safuFundContract;

        turingTimeLockContract.clearFieldValue('setSafuFundContract', 'safuFundContract', 1);
        turingTimeLockContract.doneTransactions('setSafuFundContract');
    }

    function setPerformanceFee() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setPerformanceFee'), "INVALID_PERMISSION");

        PERFORMANCE_FEE = turingTimeLockContract.getUintChangeOnTimeLock(address(this), 'setPerformanceFee', 'PERFORMANCE_FEE');

        turingTimeLockContract.clearFieldValue('setPerformanceFee', 'PERFORMANCE_FEE', 2);
        turingTimeLockContract.doneTransactions('setPerformanceFee');
    }

    function setSafuFee() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setSafuFee'), "INVALID_PERMISSION");

        SAFU_FUND = turingTimeLockContract.getUintChangeOnTimeLock(address(this), 'setSafuFee', 'SAFU_FUND');

        turingTimeLockContract.clearFieldValue('setSafuFee', 'SAFU_FUND', 2);
        turingTimeLockContract.doneTransactions('setSafuFee');
    }


    function setMaxFeeOnDistribute() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setMaxFeeOnDistribute'), "INVALID_PERMISSION");

        MAX_FEE_ON_DISTRIBUTE = turingTimeLockContract.getUintChangeOnTimeLock(address(this), 'setMaxFeeOnDistribute', 'MAX_FEE_ON_DISTRIBUTE');

        turingTimeLockContract.clearFieldValue('setMaxFeeOnDistribute', 'MAX_FEE_ON_DISTRIBUTE', 2);
        turingTimeLockContract.doneTransactions('setMaxFeeOnDistribute');
    }

    function processTradeFee(IBEP20 token, address trader) public {

        require(pairs[msg.sender] == true, "PAIR_NOT_CORRECT");

        uint256 tokenBalance = token.balanceOf(address(this)); 
        require(tokenBalance > 0, "TOKEN_BALANCE_ZERO");
        uint256 performanceFee = tokenBalance.mul(PERFORMANCE_FEE).div(100);
        uint256 safuFundAmount = tokenBalance.mul(SAFU_FUND).div(100);
        token.transfer(performanceMachineContract, performanceFee);
        token.transfer(safuFundContract, safuFundAmount);
        token.transfer(msg.sender, token.balanceOf(address(this))); //send back the trade fee after cut 20% (trade fee for LP = 0.24%)

        _distributeTuring(trader, tokenBalance);
        _updateDailyFee(msg.sender, tokenBalance);
    }

    function _updateDailyFee(address _lp, uint256 _fee) private {
        if (timeOfCreateNewFee[_lp].add(DAY_PERIOD) >= block.timestamp) {
            totalDays[_lp] += 1;
            timeOfCreateNewFee[_lp] = block.timestamp;
        } 
        feeOf[_lp][totalDays[_lp]] = feeOf[_lp][totalDays[_lp]].add(_fee);
    }

    function _distributeTuring(address trader, uint256 fee) private {
        uint256 _turBal = TUR.balanceOf(address(this));
        uint256 _distributeAmt = DISTRIBUTE_TURING_AMOUNT;

        if (fee < MAX_FEE_ON_DISTRIBUTE) {
            _distributeAmt = _distributeAmt.mul(fee).div(MAX_FEE_ON_DISTRIBUTE);
        }

        if (_distributeAmt > _turBal) {
            _distributeAmt = _turBal;
        }
        if (_distributeAmt > 0) {
            TUR.transfer(trader, _distributeAmt);
            emit onDistributeTuring(trader, _distributeAmt);
        }
    }
    function getTradeFeeAPY(IBEP20 _lp) public view returns(uint256) {
        uint256 _totalSupply = _lp.totalSupply(); // Base and Token = 2 * total supply
        uint256 _totalDays = totalDays[address(_lp)];
        uint256 _count = 0;
        uint256 _totalFee = 0;
        for (uint256 idx = _totalDays; idx >= 0; idx--) {
            _count += 1;
            _totalFee = _totalFee.add(feeOf[address(_lp)][idx]);
            if (_count >= 7) {
                break;
            }
        }
        if (_count <= 0) {
            return 0;
        }
        if (_totalSupply <= 0) {
            return 0;
        }
        uint256 _dailyFee = _totalFee.div(_count);
        return _dailyFee.mul(1e12).mul(365).div(_totalSupply.mul(2));
    }
    function getVolume(address _lp) public view returns(uint256) {
        uint256 _tradeFee = ISwapTrade(_lp).TRADE_FEE();
        uint256 _feeOnLastDay = feeOf[_lp][totalDays[_lp]];
        // TRADE_FEE = 2; //0.2% 2/1000
        // $1000 => fee = 1000*0.2/100 => 2
        // => Volume = 1000 * fee / TRADE_FEE
        return _feeOnLastDay.mul(1000).div(_tradeFee);
    }
}