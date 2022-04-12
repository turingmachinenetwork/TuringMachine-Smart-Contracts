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

contract turingFarmVVSLp is ReentrancyGuard {

    using SafeMath for uint256;
    uint256 public version = 100;
    address public owner;
    
    IBEP20 public VVS; // 
    IBEP20 public WANT; // LP token
    IBEP20 public TURING; // TURING
    address public WCRO;
    address public USDC;

    uint256 MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    ICraftsman public CraftsmanContract;
    IVVSRouter public VVSRouterContract;
    IDistributeTuring public distributeTuring;
    ITuringTimeLock public TuringTimeLockContract;
    ITuringWhitelist public TuringWhitelistContract;


    uint256 public pidOfMining;
    uint256 public pidOfFarm;
    uint256 public totalShare = 0;
    uint256 public accWantPerShare = 0;
    uint256 public timeOfHarvest = 0;
    uint256 public periodOfDay = 1 days;

    mapping(address => uint256) public shareOf;
    mapping(address => uint256) public rewardWantDebtOf;

    bool public ENABLE = false; 

    uint256 public rateOfPerformanceFee = 3000; // 0.5 % on profit.
    uint256 public rateOfControllerFee = 10; // 0.1 % on profit.
    address public controllerMachine;



    modifier onlyOwner()
    {
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
            require(TuringWhitelistContract.isWhitelisted(msg.sender) == true, "INVALID_WHITElIST");
        }
        _;
    }
    event onDeposit(address _user, uint256 _amount);
    event onWithdraw(address _user, uint256 _amount);

    constructor(
        ITuringTimeLock _TuringTimeLockContract,
        ITuringWhitelist _TuringWhiteListContract,
        IVVSRouter _VVSRouterContract,
        ICraftsman _CraftsmanContract,
        IBEP20 _WANT,
        IBEP20 _VVS,
        IBEP20 _TURING,
        address _WCRO,
        address _USDC
        ) public {
        controllerMachine = msg.sender;
        owner = msg.sender;
        TuringTimeLockContract = _TuringTimeLockContract;
        TuringWhitelistContract = _TuringWhiteListContract;
        VVSRouterContract = _VVSRouterContract;
        CraftsmanContract = _CraftsmanContract;
        WANT = _WANT;
        VVS = _VVS;
        TURING = _TURING;
        WCRO = _WCRO;
        USDC = _USDC;
    }

    function enable() public {
        require(msg.sender == owner || msg.sender == address(distributeTuring), "ONLY_OWNER_OR_DISTRIBUTE_TURING");
        ENABLE = true;
    }
    function disable() public onlyOwner {
        ENABLE = false;
    }

    receive() external payable {
        
    }

    function ConnectToVVS() public onlyOwner {
        WANT.approve(address(CraftsmanContract), MAX_INT);
    }

    function connectToDistributeContract() public onlyOwner {
        VVS.approve(address(distributeTuring), MAX_INT);
    } 

    function setWhiteListContract(ITuringWhitelist _TuringWhiteListContract) public onlyOwner isQueued("setWhiteListContract") {
        TuringWhitelistContract = _TuringWhiteListContract;
    }

    function transferOwnership(address _newOwner) public onlyOwner isQueued("transferOwnership") {
        owner = _newOwner;
    }

    function setDistributeTuring(IDistributeTuring _distributeTuring) public onlyOwner isQueued("setDistributeTuring"){
        distributeTuring = _distributeTuring;
    }

    function setControllerMachine(address _controllerMachine) public onlyOwner isQueued("setControllerMachine") {
        controllerMachine = _controllerMachine;
    } 

    function setCraftsmanContract(ICraftsman _CraftsmanContract) public onlyOwner isQueued("setCraftsmanContract"){
        CraftsmanContract = _CraftsmanContract;
    }
    
    function changeWantToken(address _WANT) public onlyOwner isQueued("changeWantToken") {
        WANT = IBEP20(_WANT);
    }

    function changeTuringToken(address _turing) public onlyOwner isQueued("changeTuringToken") {
        TURING = IBEP20(_turing);
    }

    function changeWcroToken(address _WCRO) public onlyOwner isQueued("changeWcroToken") {
        WCRO = _WCRO;
    }

    function changeUsdcToken(address _USDC) public onlyOwner isQueued("changeUsdcToken") {
        USDC = _USDC;
    }

    function changeVVSToken(address _VVS) public onlyOwner isQueued("changeVVSToken") {
        VVS = IBEP20(_VVS);
    }
    
    function setRateOfPerformanceFee(uint256 _rateOfPerformanceFee) public onlyOwner isQueued("setRateOfPerformanceFee") {
        rateOfPerformanceFee = _rateOfPerformanceFee;
    }

    function setRateOfControllerFee(uint256 _rateOfControllerFee) public onlyOwner isQueued("setRateOfControllerFee") {
        rateOfControllerFee = _rateOfControllerFee;
    }

    function setPidOfMining(uint256 _pidOfMining) public onlyOwner isQueued("setPidOfMining") {
        pidOfMining = _pidOfMining;
    }

    function setPidOfFarm(uint256 _pidOfFarm) public onlyOwner isQueued("setPidOfFarm") {
        pidOfFarm = _pidOfFarm;
    }

    function deposit(uint256 _wantAmt) external nonReentrant onlyWhitelisted {
        uint256 _uWantBal = WANT.balanceOf(msg.sender);
        if(_wantAmt > _uWantBal) {
            _wantAmt = _uWantBal;
        }   
        require(_wantAmt > 0, 'INVALID_INPUT');
        harvest(msg.sender);

        uint256 _cWantBalBefore = WANT.balanceOf(address(this)); 
        WANT.transferFrom(msg.sender, address(this), _wantAmt);
        uint256 _cWantBalAfter = WANT.balanceOf(address(this));
        require(_wantAmt >= _cWantBalAfter.sub(_cWantBalBefore), "INVALID_GET_TOKEN_FROM_USER");
        CraftsmanContract.deposit(pidOfFarm, _wantAmt); 
        // update total principal
        shareOf[msg.sender] = shareOf[msg.sender].add(_wantAmt);
        totalShare = totalShare.add(_wantAmt);
        _updateUser(msg.sender);
        emit onDeposit(msg.sender, _wantAmt);

    }
    function withdraw(uint256 _wantAmt) external nonReentrant onlyWhitelisted {
        harvest(msg.sender);
        if (_wantAmt > shareOf[msg.sender]) {
            _wantAmt = shareOf[msg.sender];
        }
        require(_wantAmt > 0, 'INVALID_INPUT');
        CraftsmanContract.withdraw(pidOfFarm, _wantAmt);
        uint256 _cWantBal = WANT.balanceOf(address(this)); 
        if (_wantAmt > _cWantBal) {
            _wantAmt = _cWantBal;
        }
        shareOf[msg.sender] = shareOf[msg.sender].sub(_wantAmt);
        totalShare = totalShare.sub(_wantAmt);
        WANT.transfer(msg.sender, _wantAmt);
        if (_cWantBal > _wantAmt) {
            CraftsmanContract.deposit(pidOfFarm, _cWantBal.sub(_wantAmt));
        }  
        _updateUser(msg.sender);
        // 
        emit onWithdraw(msg.sender, _wantAmt);
    }

    function harvest(address _user) public onlyWhitelisted {
        _harvest(_user);
    }

    function _harvest(address _user) private {
        timeOfHarvest = block.timestamp;

        uint256 beforeVVSBalance = VVS.balanceOf(address(this));
        if (totalShare > 0) {
            CraftsmanContract.withdraw(pidOfFarm, 0);
            uint256 _reward = VVS.balanceOf(address(this)).sub(beforeVVSBalance);
            if (_reward > 0) {
                uint256 _performanceFee = ENABLE ? _reward.mul(rateOfPerformanceFee).div(10000) : 0;
                uint256 _controllerFee = _reward.mul(rateOfControllerFee).div(10000);
                if(_performanceFee > 0) {
                    DistributeTuringContract.processFee(pidOfMining, _performanceFee);
                }
                VVS.transfer(controllerMachine, _controllerFee);

                _reward = _reward.sub(_performanceFee).sub(_controllerFee);
                accWantPerShare = accWantPerShare.add(_reward.mul(1e24).div(totalShare));
            }
        }
        distributeTuring.harvest(pidOfMining, _user);

        uint256 _userRewardDebt  = shareOf[_user].mul(accWantPerShare).div(1e24);

        if (_userRewardDebt > rewardWantDebtOf[_user]) {
            uint256 _userPendingVVS = _userRewardDebt.sub(rewardWantDebtOf[_user]);
            uint256 _VVSBalance = VVS.balanceOf(address(this));
            if (_userPendingVVS > _VVSBalance) {
                _userPendingVVS = _VVSBalance;
            }
            VVS.transfer(_user, _userPendingVVS);
        }

        rewardWantDebtOf[_user] = shareOf[_user].mul(accWantPerShare).div(1e24);
    }

    function _updateUser(address _user) private  
    {
        distributeTuring.updateUser(pidOfMining, _user);
        rewardWantDebtOf[_user] = shareOf[_user].mul(accWantPerShare).div(1e24);
    }
    /**
    *
        data_[0] int256 miningSpeed_,
        data_[1] uint256 userWANTBal_, 
        data_[2] uint256 turingPrice_, 
        data_[3] uint256 pendingVVS_, 
        data_[4] uint256 totalMintPerDay_, 
        data_[5] uint256 totalWANTRewardPerDay_, 
        data_[6] uint256 userBNBBal_, 
        data_[7] uint256 userTuringPending_, 
        data_[8] uint256 userWANTShare_, 
        data_[9] uint256 tvl_
        data_[10] uint256 VVSPrice_
    */
    function getData(
        address _user
    ) 
    public 
    view
    returns(
        uint256[11] memory data_
    ) {
        data_[2] = getTuringPrice();
        data_[10] = getVVSPrice();
        data_[4] = getTotalMintPerDayOf();
        data_[5] = getTotalRewardPerDay();

        data_[6] = address(_user).balance;
        (data_[7], ) = distributeTuring.getUserInfo(pidOfMining, _user);

        data_[1] = WANT.balanceOf(_user);

        data_[8] = shareOf[_user];
        data_[3] = pendingVVSOf(_user);

        (data_[9], ) = CraftsmanContract.userInfo(pidOfFarm, address(this));
    } 

    function getTuringPrice() public view returns(uint256) {

        address[] memory path = new address[](3);

        path[0] = address(TURING);
        path[1] = WCRO;
        path[2] = USDC;
        uint256 _price;
        try VVSRouterContract.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
            _price = amounts[2];
        } catch {
            _price = 0;   
        }
        return _price;
    }

    function getVVSPrice() public view returns(uint256) {

        address[] memory path = new address[](3);

        path[0] = address(VVS);
        path[1] = WCRO;
        path[2] = USDC;
        uint256 _price;
        try VVSRouterContract.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
            _price = amounts[2];
        } catch {
            _price = 0;   
        }
        return _price;
    }

    function getTotalRewardPerDay() public view returns(uint256) {
        uint256 _reward = CraftsmanContract.pendingVVS(pidOfFarm, address(this));
        uint256 _rewardPerSec = 0;
        if (block.timestamp > timeOfHarvest) {
           _rewardPerSec = _reward.div(block.timestamp.sub(timeOfHarvest));     
        }
        return _rewardPerSec.mul(periodOfDay);
    }

    function pendingVVSOf(address _user) public view returns (uint256 _pendingVVS) {

        uint256 _accWantPerShare  = accWantPerShare;
        uint256 _reward = CraftsmanContract.pendingVVS(pidOfFarm, address(this));
        if (_reward > 0 && totalShare > 0) {
            uint256 _performanceFee = ENABLE ? _reward.mul(rateOfPerformanceFee).div(10000) : 0;
            uint256 _controllerFee  = _reward.mul(rateOfControllerFee).div(10000);
            _reward = _reward.sub(_performanceFee).sub(_controllerFee);
            _accWantPerShare = _accWantPerShare.add(_reward.mul(1e24).div(totalShare));
        }

        uint256 _rewardDebt  = shareOf[_user].mul(_accWantPerShare).div(1e24);

        if (_rewardDebt > rewardWantDebtOf[_user]) {
            _pendingVVS = _rewardDebt.sub(rewardWantDebtOf[_user]);
        }
    }

    function getTotalMintPerDayOf() public view returns (uint256) {
        uint256 _performanceFee = getPerfomanceFee();
         if(_performanceFee == 0) {
            return 0;
        }
        uint256 turPendingOfContractPerSec = 0;
        if(block.timestamp > timeOfHarvest){
            turPendingOfContractPerSec = 
                distributeTuring.getDistribution(
                    pidOfMining, _performanceFee)
                    .div(block.timestamp
                    .sub(timeOfHarvest));       
        }
        return turPendingOfContractPerSec.mul(periodOfDay);
    }

    function getPerfomanceFee() public view returns (uint256) {
        uint256 _wantReward = CraftsmanContract.pendingVVS(0, address(this));
        uint256 _performanceFee = ENABLE ? _wantReward.mul(rateOfPerformanceFee).div(10000) : 0;
        return _performanceFee;
    }
}