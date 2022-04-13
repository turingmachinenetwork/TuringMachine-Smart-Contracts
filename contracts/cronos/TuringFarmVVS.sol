// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IDistributeTuring.sol';
import './interfaces/IVVSRouter.sol';
import './interfaces/ICraftsman.sol';
import './interfaces/IBEP20.sol';
import './interfaces/ITuringTimeLock.sol';
import './interfaces/ITuringWhiteList.sol';
import './library/SafeMath.sol';
import './library/ReentrancyGuard.sol';

contract TuringFarmVVS is ReentrancyGuard {

    using SafeMath for uint256;
    uint256 public version = 100;
    address public owner;

    IBEP20 public WANT; // VVS
    IBEP20 public TURING; // TURING
    address public WCRO;
    address public USDC;

    ICraftsman public CraftsmanContract;
    IDistributeTuring public DistributeTuringContract;
    IVVSRouter public VVSRouterContract;
    ITuringTimeLock public TuringTimeLockContract;
    ITuringWhitelist public TuringWhitelistContract;

    uint256 public pidOfMining;
    uint256 public totalShare = 0;
    uint256 public accWantPerShare = 0;
    uint256 public timeOfHarvest = 0;
    uint256 public periodOfDay = 1 days;

    mapping(address => uint256) public shareOf;
    mapping(address => uint256) public rewardWantDebtOf;

    bool public ENABLE = false; 

    uint256 public rateOfPerformanceFee = 3000; // 30 % on profit.
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
        IBEP20 _TURING,
        address _WCRO,
        address _USDC
        ) public {
        controllerMachine = msg.sender;
        owner = msg.sender;
        VVSRouterContract = _VVSRouterContract;
        CraftsmanContract = _CraftsmanContract;
        TuringTimeLockContract = _TuringTimeLockContract;
        TuringWhitelistContract = _TuringWhiteListContract;
        WANT = _WANT;
        TURING = _TURING;
        WCRO = _WCRO;
        USDC = _USDC;
    }

    receive() external payable {

    }

    function enable() public {
        require(msg.sender == owner || msg.sender == address(DistributeTuringContract), "ONLY_OWNER_OR_ONLY_OWNER_OR_DISTRIBUTE_TURING");
        ENABLE = true;
    }
    function disable() public onlyOwner {
        ENABLE = false;
    }

    function ConnectToVVS() public onlyOwner {
        WANT.approve(address(CraftsmanContract), uint256(-1));
    }

    function ConnectToDistributeContract() public onlyOwner {
        WANT.approve(address(DistributeTuringContract), uint256(-1));
    }

    function transferOwnership(address _newOwner) public onlyOwner isQueued("transferOwnership") {
        owner = _newOwner;
    }

    function setDistributeTuringContract(IDistributeTuring _DistributeTuringContract) public onlyOwner isQueued("setDistributeTuringContract"){
        DistributeTuringContract = _DistributeTuringContract;
    }

    function setWhiteListContract(ITuringWhitelist _TuringWhiteListContract) public onlyOwner isQueued("setWhiteListContract") {
        TuringWhitelistContract = _TuringWhiteListContract;
    }

    function setRateOfPerformanceFee(uint256 _rateOfPerformanceFee) public onlyOwner isQueued("setRateOfPerformanceFee") {
        rateOfPerformanceFee = _rateOfPerformanceFee;
    }

    function setControllerMachine(address _controllerMachine) public onlyOwner isQueued("setControllerMachine") {
        controllerMachine = _controllerMachine;
    }

    function setVVSRouter(IVVSRouter _VVSRouterContract) public onlyOwner isQueued("setVVSRouter") {
        VVSRouterContract = _VVSRouterContract;
    }

    function setCraftsmanContract(ICraftsman _craftsmanContract) public onlyOwner isQueued("setCraftsmanContract") {
        CraftsmanContract = _craftsmanContract;
    }

    function changeWantToken(address _WANT) public onlyOwner isQueued("changeWantToken") {
        WANT = IBEP20(_WANT);
    }

    function changeTuringToken(address _TURING) public onlyOwner isQueued("changeTuringToken") {
        TURING = IBEP20(_TURING);
    }

    function changeWcroToken(address _WCRO) public onlyOwner isQueued("changeWcroToken") {
        WCRO = _WCRO;
    }

    function changeusdcToken(address _USDC) public onlyOwner isQueued("changeUsdcToken") {
        USDC = _USDC;
    }

    function setRateOfControllerFee(uint256 _rateOfControllerFee) public onlyOwner isQueued("setRateOfControllerFee") {
        rateOfControllerFee = _rateOfControllerFee;
    }

    function setPidOfMining(uint256 _pidOfMining) public onlyOwner isQueued("setPidOfMining") {
        pidOfMining = _pidOfMining;
    }

    function deposit(uint256 _wantAmt) external nonReentrant onlyWhitelisted {
        // check balance if rounding wrong in UI
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
        // update total principal
        shareOf[msg.sender] = shareOf[msg.sender].add(_wantAmt);
        totalShare = totalShare.add(_wantAmt);
        CraftsmanContract.enterStaking(_wantAmt);
        _updateUser(msg.sender);
        emit onDeposit(msg.sender, _wantAmt);
    }

    function withdraw(uint256 _wantAmt) external nonReentrant onlyWhitelisted {
        harvest(msg.sender);
        if (_wantAmt > shareOf[msg.sender]) {
            _wantAmt = shareOf[msg.sender];
        }
        require(_wantAmt > 0, 'INVALID_INPUT');
        CraftsmanContract.leaveStaking(_wantAmt);
        uint256 _cWantBal = WANT.balanceOf(address(this));
        if (_wantAmt > _cWantBal) {
            _wantAmt = _cWantBal;
        }
        // sub share
        shareOf[msg.sender] = shareOf[msg.sender].sub(_wantAmt);
        totalShare = totalShare.sub(_wantAmt);
        // transfer to user
        WANT.transfer(msg.sender, _wantAmt);
        // update user's info
        _updateUser(msg.sender);
        emit onWithdraw(msg.sender, _wantAmt);
    }

    function harvest(address _user) public onlyWhitelisted{
        _harvest(_user);
    }

    function _harvest(address _user) private {
        timeOfHarvest = block.timestamp;

        uint256 beforeVVSBalance = WANT.balanceOf(address(this));
        if (totalShare > 0) {
            CraftsmanContract.leaveStaking(0);
            uint256 _reward = WANT.balanceOf(address(this)).sub(beforeVVSBalance);
            // update reward for system
            if (_reward > 0) {
                uint256 _performanceFee = ENABLE ? _reward.mul(rateOfPerformanceFee).div(10000) : 0;
                uint256 _controllerFee = _reward.mul(rateOfControllerFee).div(10000);
                if(_performanceFee > 0) {
                    DistributeTuringContract.processFee(pidOfMining, _performanceFee);
                }
                WANT.transfer(controllerMachine, _controllerFee);

                _reward = _reward.sub(_performanceFee).sub(_controllerFee);
                accWantPerShare = accWantPerShare.add(_reward.mul(1e24).div(totalShare));

                uint256 _cVVSBal = WANT.balanceOf(address(this));
                if (_cVVSBal > 0) {
                    CraftsmanContract.enterStaking(_cVVSBal);
                }
            }
        }
        DistributeTuringContract.harvest(pidOfMining, _user);

        uint256 _userRewardDebt  = shareOf[_user].mul(accWantPerShare).div(1e24);

        if (_userRewardDebt > rewardWantDebtOf[_user]) {
            uint256 _uVVSPending = _userRewardDebt.sub(rewardWantDebtOf[_user]);
            shareOf[_user] = shareOf[_user].add(_uVVSPending);
            totalShare = totalShare.add(_uVVSPending);
            DistributeTuringContract.updateUser(pidOfMining, _user);
        }
        rewardWantDebtOf[_user] = shareOf[_user].mul(accWantPerShare).div(1e24);

    }

    function _updateUser(address _user) private
    {
        rewardWantDebtOf[_user] = shareOf[_user].mul(accWantPerShare).div(1e24);
        DistributeTuringContract.updateUser(pidOfMining, _user);
    }
    /**
    *
        data_[1] uint256 userWantBal_,
        data_[2] uint256 turingPrice_,
        data_[3] uint256 wantPrice_,
        data_[4] uint256 totalMintPerDay_,
        data_[5] uint256 totalWantRewardPerDay_,
        data_[6] uint256 userBNBBal_,
        data_[7] uint256 userTuringPending_,
        data_[8] uint256 userWantShare_,
        data_[9] uint256 turingRewardAPY_,
        data_[10] uint256 wantRewardAPY_,
        data_[11] uint256 tvl_
    */
    function getData(
        address _user
    )
    public
    view
    returns(
        uint256[12] memory data_
    ) {
        data_[2] = getTuringPrice();
        data_[3] = getWantPrice();
        data_[4] = getTotalMintPerDayOf();
        data_[5] = getTotalRewardPerDay();

        data_[6] = address(_user).balance;
        (data_[7], ) = DistributeTuringContract.getUserInfo(pidOfMining, _user);

        data_[1] = WANT.balanceOf(_user);

        data_[8] = shareOf[_user].add(pendingWantOf(_user));

        (data_[11], ) = CraftsmanContract.userInfo(0, address(this));

        if (data_[11] > 0) {
            data_[10] = data_[5].mul(365).mul(10000).div(data_[11]);
            data_[9] = data_[4].mul(data_[2]).mul(365).mul(10000).div(data_[11].mul(data_[3]));
        }
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

    function getWantPrice() public view returns(uint256) {

        address[] memory path = new address[](3);

        path[0] = address(WANT);
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
        uint256 _reward = CraftsmanContract.pendingVVS(0, address(this));
        uint256 _rewardPerSec = 0;
        if (block.timestamp > timeOfHarvest) {
           _rewardPerSec = _reward.div(block.timestamp.sub(timeOfHarvest));
        }
        return _rewardPerSec.mul(periodOfDay);
    }

    function pendingWantOf(address _user) public view returns (uint256 _pendingWant) {

        uint256 _accWantPerShare  = accWantPerShare;
        uint256 _reward = CraftsmanContract.pendingVVS(0, address(this));
        if (_reward > 0 && totalShare > 0) {
            uint256 _performanceFee = ENABLE ? _reward.mul(rateOfPerformanceFee).div(10000) : 0;
            uint256 _controllerFee  = _reward.mul(rateOfControllerFee).div(10000);
            _reward = _reward.sub(_performanceFee).sub(_controllerFee);
            _accWantPerShare = _accWantPerShare.add(_reward.mul(1e24).div(totalShare));
        }

        uint256 _rewardDebt  = shareOf[_user].mul(_accWantPerShare).div(1e24);

        if (_rewardDebt > rewardWantDebtOf[_user]) {
            _pendingWant = _rewardDebt.sub(rewardWantDebtOf[_user]);
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
                DistributeTuringContract.getDistribution(
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
