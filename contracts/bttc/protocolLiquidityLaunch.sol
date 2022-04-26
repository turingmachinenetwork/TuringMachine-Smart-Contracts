// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './library/SafeMath.sol';
import './interfaces/ITuringWhiteList.sol';
import './interfaces/ITuringTimeLock.sol';
import './interfaces/IBRC20.sol';

contract protocolLiquidityLaunch {
    uint8 public VERSION = 100;
    using SafeMath for uint256;
    
    address public owner;

    ITuringTimeLock public TuringTimeLockContract;
    ITuringWhitelist public TuringWhitelistContract;

    IBRC20 public TURING;

    uint256 public salePrice = 1e17; // 1 tur = 0,1 BTT
    uint256 public totalSaleTuring = 2 * 1e24; // 2m turing
    uint256 public totalPurchased = 0;

    bool public ENABLE = true;
    uint256 public HARD_CAP_PER_USER = 100000 * 1e18; // 100k

    mapping(address => uint256) public turingBuyedOf;

    modifier onlyOwner() {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }

    modifier isQueued(string memory _functionName) {
        require(TuringTimeLockContract.isQueuedTransaction(address(this), _functionName) == true, "INVALID_PERMISTION");
        _;
        TuringTimeLockContract.doneTransaction(_functionName);
    }

    modifier onlyWhitelisted() {
        if(msg.sender != tx.origin) {
            require(TuringWhitelistContract.whitelisted(msg.sender) == true, "INVALID_WHITElIST");
        }
        _;
    }

    event onBuy(address _user, uint256 _bttSend, uint256 _bttRefund, uint256 _turingReceive);

    constructor(
        ITuringTimeLock _TuringTimeLockContract,
        ITuringWhitelist _TuringWhiteListContract,
        IBRC20 _TURING
    ) {
        TuringTimeLockContract = _TuringTimeLockContract;
        TuringWhitelistContract = _TuringWhiteListContract;
        TURING = _TURING;

        owner = msg.sender;
    }

    receive() external payable {}

    function enable() public onlyOwner {
        ENABLE = true;
    }
    function disable() public onlyOwner {
        ENABLE = false;
    }

    function transferOwnership(address _newOwner) public onlyOwner isQueued("transferOwnership") {
        owner = _newOwner;
    }

    function setTuringWhiteListContract(ITuringWhitelist _TuringWhiteListContract) public onlyOwner isQueued("setTuringWhiteListContract") {
        TuringWhitelistContract = _TuringWhiteListContract;
    }

    function setTuringTokenContract(IBRC20 _TURING) public onlyOwner isQueued("setTuringTokenContract") {
        require(address(TURING) != address(0), "INVALID_ADDRESS");
        TURING = _TURING;
    }

    function setSalePrice(uint256 _value) public onlyOwner isQueued("setSalePrice") {
        salePrice = _value; 
    }

    function setTotalSaleTuring(uint256 _totalSaleTuring) public onlyOwner isQueued("setTotalSaleTuring") {
        totalSaleTuring = _totalSaleTuring;
    }

    function setHardCapPerUser(uint256 _value) public onlyOwner isQueued("setHardCapPerUser") {
        HARD_CAP_PER_USER = _value;
    }

    function buy() public payable onlyWhitelisted {
        require(ENABLE == true, "SYSTEM_STOP");
        require(msg.value > 0, "INVALID_AMOUNT_1");
        uint256 _refundAmt;
        uint256 _turingAmt;
        uint256 _payAmt;
        (_payAmt, _refundAmt, _turingAmt) = getProcessAmt(msg.sender, msg.value);

        require(_payAmt.add(_refundAmt) <= msg.value, "INVALID_AMOUNT_2");
        if(_turingAmt > 0) {
            require(_payAmt > 0, 'INVALID_AMOUNT_3');
            TURING.transfer(msg.sender, _turingAmt);

            totalPurchased = totalPurchased.add(_payAmt);
            totalSaleTuring = totalSaleTuring.sub(_turingAmt);
            turingBuyedOf[msg.sender] = turingBuyedOf[msg.sender].add(_turingAmt);
        }

        if(_refundAmt >  0) {
            bool sent = payable(msg.sender).send(_refundAmt);
            require(sent, "Failed to send Ether");
        }

        emit onBuy(msg.sender, _payAmt, _refundAmt, _turingAmt);

    }

    function moveFund() public onlyOwner isQueued("moveFund") {
        uint256 _cBTTBal = getBalance();
        bool sent = payable(owner).send(_cBTTBal);
        require(sent, "Failed to send Ether");
    }

    function emergencyWithdraw() public onlyOwner isQueued("emergencyWithdraw") {
        uint256 _cTURBal = getTurBalance();
        require(_cTURBal > 0, "NO ASSET");
        TURING.transfer(owner, _cTURBal);
    }

    function getProcessAmt(address _user, uint256 _sendAmt) public view returns(uint256 _payAmt, uint256 _refundAmt, uint256 _uTurBuyAmt) {
        _payAmt = _sendAmt;

        uint256 _maxBuy = getTurBuyMaxOf(_user);

        if(_maxBuy <= 0) {
            return(0, _payAmt, 0);
        }

        _uTurBuyAmt = _payAmt.mul(1e18).div(salePrice);

        if(_uTurBuyAmt >= _maxBuy) {
            _uTurBuyAmt = _maxBuy;
            _payAmt = _uTurBuyAmt.mul(salePrice).div(1e18);
            _refundAmt = _sendAmt.sub(_payAmt);
        }
        return (_payAmt, _refundAmt, _uTurBuyAmt);
    }

    function getTurBuyMaxOf(address _user) public view returns(uint256) {
        if (
            turingBuyedOf[_user] >= HARD_CAP_PER_USER ||
            totalSaleTuring <= 0 ||
            ENABLE == false
            ) {
            return 0;
        }
        // user
        uint256 _maxBuy = HARD_CAP_PER_USER.sub(turingBuyedOf[_user]);

        if (totalSaleTuring >= _maxBuy) {
            return _maxBuy;
        }
        return totalSaleTuring;
    }
    
    function getBalance() public view returns(uint256) {
        return address(this).balance;
    }
    function getTurBalance() public view returns(uint256) {
        return TURING.balanceOf(address(this));
    }
    /**
    data_[0] = uint256 userBTTBalance;
    data_[1] = uint256 userMaxTuringBuy;
    data_[2] = uint256 userMaxBTTPay;
    data_[3] = uint256 contractBTTBalance;
    data_[4] = uint256 HARD_CAP_PER_USER;
    data_[5] = uint256 totalSaleTuring;
    data_[6] = uint256 salePrice;
    data_[7] = uint256 totalPurchased;
     */
    function getData(address _user) public view returns(uint256[8] memory data_) {
        data_[0] = _user.balance;
        data_[1] = getTurBuyMaxOf(_user);
        data_[2] = data_[1].mul(salePrice).div(1e18);
        data_[3] = getBalance();
        data_[4] = HARD_CAP_PER_USER;
        data_[5] = totalSaleTuring;
        data_[6] = salePrice;
        data_[7] = totalPurchased;
    }



}