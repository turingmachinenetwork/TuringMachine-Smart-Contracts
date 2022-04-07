// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IDistributeTuring.sol';
import './interfaces/IVVSRouter.sol';
import './interfaces/ICraftsman.sol';
import './interfaces/ITuringTimeLock.sol';
import './interfaces/ITuringWhiteList.sol';
import './interfaces/IBEP20.sol';
import './library/SafeMath.sol';
import './library/ReentrancyGuard.sol';

// Deposit LpToken earn VVS and TUR

contract turingFarmTurCroLp is ReentrancyGuard {

    using SafeMath for uint256;
    uint256 public version = 100;
    address public owner;
    
    IBEP20 public TURING; // TURING
    IBEP20 public TURINGCROLP;

    uint256 MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    IDistributeTuring public DistributeTuringContract;
    ITuringTimeLock public TuringTimeLockContract;
    ITuringWhitelist public TuringWhitelistContract;
    // IVVSRouter public vvsRouter;


    uint256 public totalShare = 0;
    uint256 public accTurPerShare = 0;
    uint256 public totalReward = 0;

    uint256 periodOfDay = 1 days;

    uint256 public HALF_TIME = 7 days;
    uint256 public LASTED_TIME;


    mapping(address => uint256) public shareOf;
    mapping(address => uint256) public rewardTuringDebtOf;

    modifier onlyOwner()
    {
        require(msg.sender == owner, "INVALID_PERMISSION");
        _;
    }

    modifier isQueued(string memory _functionName) {
        require(TuringTimeLockContract.isQueuedTransaction(address(this), _functionName) == true, "INVALID_PERMISTION");
        _;
        TuringTimeLockContract.doneTransaction(_functionName);
    }

    modifier onlyWhitelisted() {
        if(msg.sender != tx.origin) {
            require(TuringWhitelistContract.isWhitelisted(msg.sender) == true, "INVALID_WHITElIST");
        }
        _;
    }
    event onDeposit(address _user, uint256 _amount);
    event onWithdraw(address _user, uint256 _amount);

    constructor(
        ITuringTimeLock _TuringTimeLockContract,
        ITuringWhitelist _TuringWhiteListContract,
        IDistributeTuring _DistributeTuringContract,
        IBEP20 _TURINGCROLP,
        IBEP20 _TURING
        ) {
        owner = msg.sender;
        TuringTimeLockContract = _TuringTimeLockContract;
        TuringWhitelistContract = _TuringWhiteListContract;
        DistributeTuringContract = _DistributeTuringContract;
        TURINGCROLP = _TURINGCROLP;
        TURING = _TURING;

        LASTED_TIME = block.timestamp;
    }

    receive() external payable {
        
    }

    function setWhiteListContract(ITuringWhitelist _TuringWhiteListContract) public onlyOwner isQueued("setWhiteListContract") {
        TuringWhitelistContract = _TuringWhiteListContract;
    }

    function transferOwnership(address _newOwner) public onlyOwner isQueued("transferOwnership") {
        owner = _newOwner;
    }

    function setDistributeTuring(IDistributeTuring _DistributeTuringContract) public onlyOwner isQueued("setDistributeTuring"){
        DistributeTuringContract = _DistributeTuringContract;
    }

    // function setVvsRouterContract(IVVSRouter _vvsRouter) public onlyOwner isQueued("setVvsRouterContract") {
    //     vvsRouter = _vvsRouter;
    // }
    
    function changeHalfTime(uint256 _value) public onlyOwner isQueued("changeHalfTime") {
        HALF_TIME = _value;
    }  

    function changeTuringToken(address _turing) public onlyOwner isQueued("changeTuringToken") {
        TURING = IBEP20(_turing);
    }

    function changeTuringCroLpToken(address _turingCroLp) public onlyOwner isQueued("changeTuringCroLpToken") {
        TURINGCROLP = IBEP20(_turingCroLp);
    }

    function distribution(uint256 _amount) public onlyWhitelisted {
        if(_amount == 0) {
            return;
        }
        require(msg.sender == address(DistributeTuringContract), "ONLY_DISTRIBUTE_CONTRACT");

        uint256 _beforeTuringOfBal = TURING.balanceOf(address(this));
        TURING.transferFrom(msg.sender, address(this), _amount);
        require(_amount >= TURING.balanceOf(address(this)).sub(_beforeTuringOfBal), "INVALID_AMOUNT_TURING");

        if(block.timestamp < LASTED_TIME.add(HALF_TIME)) {
            totalReward = totalReward.add(_amount);
        } else {
            totalReward = _amount;
            LASTED_TIME = block.timestamp;
        }
        accTurPerShare = accTurPerShare.add(_amount.mul(1e24).div(totalShare));
    }

    function deposit(uint256 _amount) external nonReentrant onlyWhitelisted {

        uint256 _turingCroLpBal = TURINGCROLP.balanceOf(msg.sender);
        if(_amount > _turingCroLpBal) {
            _amount = _turingCroLpBal;
        }   
        require(_amount > 0, "INVALID_INPUT");
        harvest(msg.sender);

        uint256 _cTuringCroLpBalBefore = TURINGCROLP.balanceOf(address(this)); 
        TURINGCROLP.transferFrom(msg.sender, address(this), _amount);

        uint256 _cTuringCroLpBalAfter = TURINGCROLP.balanceOf(address(this));
        require(_amount >= _cTuringCroLpBalAfter.sub(_cTuringCroLpBalBefore), "INVALID_GET_TOKEN_FROM_USER");

        // update total principal
        shareOf[msg.sender] = shareOf[msg.sender].add(_amount);
        totalShare = totalShare.add(_amount);
        _updateUser(msg.sender);
        emit onDeposit(msg.sender, _amount);

    }
    function withdraw(uint256 _amount) external nonReentrant onlyWhitelisted {
        harvest(msg.sender);
        if (_amount > shareOf[msg.sender]) {
            _amount = shareOf[msg.sender];
        }
        require(_amount > 0, "INVALID_INPUT");
        uint256 _cTuringCroLpBal = TURINGCROLP.balanceOf(address(this)); 
        if (_amount > _cTuringCroLpBal) {
            _amount = _cTuringCroLpBal;
        }
        shareOf[msg.sender] = shareOf[msg.sender].sub(_amount);
        totalShare = totalShare.sub(_amount);
        TURINGCROLP.transfer(msg.sender, _amount); 
        _updateUser(msg.sender);
        // 
        emit onWithdraw(msg.sender, _amount);
    }

    function harvest(address _user) public onlyWhitelisted {
        _harvest(_user);
    }

    function _harvest(address _user) private {
        uint256 _turingBalance = TURING.balanceOf(address(this));
        
        uint256 _allRerawdTurOfUser = shareOf[_user].mul(accTurPerShare).div(1e24);
        uint256 _uPendingTur;
        if(_allRerawdTurOfUser > rewardTuringDebtOf[_user]) {
            _uPendingTur = _allRerawdTurOfUser.sub(rewardTuringDebtOf[_user]);
        }
        if(_uPendingTur > _turingBalance) {
            _uPendingTur = _turingBalance;
        }
        if(_uPendingTur > 0) {
            TURING.transfer(_user, _uPendingTur);
        }

        rewardTuringDebtOf[_user] = shareOf[_user].mul(accTurPerShare).div(1e24);
    }

    function _updateUser(address _user) private  
    {
        rewardTuringDebtOf[_user] = shareOf[_user].mul(accTurPerShare).div(1e24);
    }
    /**
    *
        data_[0] uint256 userTuringCroLpBal_, 
        data_[1] uint256 totalMintPerDay_, 
        data_[2] uint256 userCROBal_, 
        data_[3] uint256 userTuringPending_, 
        data_[4] uint256 userTuringBal, 
        data_[5] uint256 userTuringCroLpShare_
        data_[6] uint256 tvl_
        data_[7] uint256 turingRewardAPY_
    */
    function getData(
        address _user
    ) 
    public 
    view
    returns(
         uint256[8] memory data_
    ) {
        data_[0] = TURINGCROLP.balanceOf(_user);
        data_[1] = getTotalMintPerDayOf();

        data_[2] = address(_user).balance;
        data_[3] = getTuringPending(_user);
        data_[4] = TURING.balanceOf(_user);
        data_[5] = shareOf[_user];
        data_[6] = totalShare;

        if (data_[6] > 0) {
            data_[7] = data_[1].mul(365).mul(10000).div(data_[6]);
        }
    } 

    function getTuringPending(address _user) public view returns(uint256) {
        return (shareOf[_user].mul(accTurPerShare).div(1e24)).sub(rewardTuringDebtOf[_user]);
    }

    function getTotalMintPerDayOf() public view returns (uint256) {
        uint256 turingRewardPerSec = 0;
        if(block.timestamp < LASTED_TIME.add(HALF_TIME)) {
           turingRewardPerSec = totalReward.div(block.timestamp.sub(LASTED_TIME));
        }else{
            turingRewardPerSec = totalReward.div(HALF_TIME);
        }
        return turingRewardPerSec.mul(periodOfDay);
    }
}