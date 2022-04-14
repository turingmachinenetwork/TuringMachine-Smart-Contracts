// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IBEP20.sol';
import './interfaces/ICraftsman.sol';
import './interfaces/IVVSRouter.sol';
import './interfaces/IDistributeTuring.sol';
import './library/SafeMath.sol';
import './library/ReentrancyGuard.sol';
import './library/SortitionSumTreeFactory.sol';
import './interfaces/ITuringTimeLock.sol';
import './interfaces/ITuringWhiteList.sol';


contract TuringNoLossLotteryVVS is ReentrancyGuard {
    uint256 public version = 100;
    using SafeMath for uint256;
    address public owner;
    bytes32 TREE_KEY;
    uint256 constant MAX_TREE_LEAVES = 5;
    uint256 public pidOfMining;
    IBEP20 public WANT; // VVS
    IBEP20 public TURING; // TURING
    address public WCRO;
    address public USDC;

    using SortitionSumTreeFactory for SortitionSumTreeFactory.SortitionSumTrees;

    SortitionSumTreeFactory.SortitionSumTrees sumTreeFactory;

    IVVSRouter public VVSRouter;
    ICraftsman public Craftsman;
    IDistributeTuring public DistributeTuringContract;
    ITuringTimeLock public TuringTimeLockContract;
    ITuringWhitelist public TuringWhitelistContract;

    uint256 public totalShare = 0;
    uint256 public totalPlayer = 0;

    mapping(address => uint256) public shareOf;
    mapping(address => uint256) public lastDepositTimeOf;

    bool public ENABLE = false; 

    uint256 public HALFTIME = 7 days;
    // uint256 public HALFTIME = 3600;
    uint256 public LOTTERY_END_TIME;

    uint256 public timeOfHarvest = 0;
    uint256 public periodOfDay = 1 days;
    uint256 public rateOfConvertWinAmtToTuring = 3500; // 35% 
    uint256 public rateOfPerformanceFee = 3000; // 5 % on profit.
    uint256 public rateFeeOfWithdrawEarly = 50; // Max 0.5 %
    uint256 public pendingTimeOfWithdraw = 3 * 24 * 60 * 60;

    uint256 public totalHistory = 5;
    uint256 public lastHistory = 0;
    uint256 public totalRandom = 0;

    mapping(uint256 => History) public historyList;

    struct History {
        uint256 time;
        uint256 tiketsWin;
        uint256 totalTickets;
        address winner;
        uint256 wonAmt;
        uint256 turRewardAmt;
        // uint256 performanceFee;
    }
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


    event onDraw(uint256 _index, address _user, uint256 _amount, uint256 _cakeConvertToTuringAmt);
    event onDeposit(address _user, uint256 _amount);
    event onWithdraw(address _user, uint256 _amount, uint256 _fee);

    constructor(
        ITuringTimeLock _turingTimeLockContract,
        ITuringWhitelist _turingWhiteListContract,
        IVVSRouter _vvsRouter,
        IDistributeTuring _DistributeTuringContract,
        ICraftsman _craftsman,
        IBEP20 _WANT, // VVS
        IBEP20 _TURING,
        address _WCRO,
        address _USDC
        ) public {
        owner = msg.sender;

        DistributeTuringContract = _DistributeTuringContract;
        VVSRouter = _vvsRouter;
        Craftsman = _craftsman;
        TuringTimeLockContract = _turingTimeLockContract;
        TuringWhitelistContract = _turingWhiteListContract;

        WANT = _WANT;

        TURING = _TURING;
        WCRO = _WCRO;
        USDC = _USDC;


        LOTTERY_END_TIME = HALFTIME.add(block.timestamp);


        TREE_KEY = keccak256(abi.encodePacked("TuringNoLossVVS", block.timestamp, address(this), msg.sender));
        sumTreeFactory.createTree(TREE_KEY, MAX_TREE_LEAVES);

        ConnectToVVS();
    }

    function enable() public {
        require(msg.sender == owner || msg.sender == address(DistributeTuringContract), "ONLY_OWNER_OR_ONLY_OWNER_OR_DISTRIBUTE_TURING");
        ENABLE = true;
    }
    function disable() public onlyOwner {
        ENABLE = false;
    }

    receive() external payable {
        
    }
    function changeTotalRandom(uint256 _value) public onlyOwner
    {
        totalRandom = _value;
    }
    function ConnectToVVS() public onlyOwner 
    {
        WANT.approve(address(Craftsman), uint256(-1));
        WANT.approve(address(VVSRouter), uint256(-1));
    }

    function ConnectToDistributeContract() public onlyOwner {
        WANT.approve(address(DistributeTuringContract), uint256(-1));
    }  

    function transferOwnership(address _newOwner) public onlyOwner isQueued("transferOwnership") {
        owner = _newOwner;
    }

    function setDistributeTuringContract(IDistributeTuring _DistributeTuringContract) public onlyOwner isQueued("setDistributeTuringContract") {
        DistributeTuringContract = _DistributeTuringContract;
    }

    function setWhiteListContract(ITuringWhitelist _turingWhiteListContract) public onlyOwner isQueued("setWhiteListContract") 
    {
        TuringWhitelistContract = _turingWhiteListContract;
    }
    function setVVSRouter(IVVSRouter _vvsRouter) public onlyOwner isQueued("setVVSRouter") 
    {
        VVSRouter = _vvsRouter;
    }

    function changeHalftime(uint256 _value) public onlyOwner isQueued("changeHalftime")
    {
        HALFTIME = _value;
    } 

    function changeLotteryEndTime(uint256 _value) public onlyOwner isQueued("changeLotteryEndTime")
    {
        LOTTERY_END_TIME = _value;
    }

    function setRateOfConvertWinAmtToTuring(uint256 _value) public onlyOwner isQueued("setRateOfConvertWinAmtToTuring")
    {
        rateOfConvertWinAmtToTuring = _value;
    }

    function setRateOfPerformanceFee(uint256 _value) public onlyOwner isQueued("setRateOfPerformanceFee")
    {
        rateOfPerformanceFee = _value;
    }

    function setPendingTimeOfWithdraw(uint256 _value) public onlyOwner onlyOwner isQueued("setPendingTimeOfWithdraw")
    {
        pendingTimeOfWithdraw = _value;
    }

    function setRatefeeOfWithdrawEarly(uint256 _value) public onlyOwner isQueued("setRatefeeOfWithdrawEarly")
    {
        rateFeeOfWithdrawEarly = _value;
    }

    function setPidOfMining(uint256 _value) public onlyOwner isQueued("setPidOfMining")
    {
        pidOfMining = _value;
    }
    function changeWantToken(address _WANT) public onlyOwner isQueued("changeWantToken") 
    {
        WANT = IBEP20(_WANT);
    }

    function changeTuringToken(address _TURING) public onlyOwner isQueued("changeTuringToken") 
    {
        TURING = IBEP20(_TURING);
    }

    function changeWcroToken(address _WCRO) public onlyOwner isQueued("changeWcroToken") 
    {
        WCRO = _WCRO;
    }

    function changeUsdcToken(address _USDC) public onlyOwner isQueued("changeUsdcToken") 
    {
        USDC = _USDC;
    }
    // User action    

    function deposit(uint256 _wantAmt) external nonReentrant onlyWhitelisted
    {
        uint256 _uWantBal = WANT.balanceOf(msg.sender);
        if (_wantAmt > _uWantBal) {
            _wantAmt = _uWantBal;
        }
        require(_wantAmt > 0, 'INVALID_INPUT');
        if (shareOf[msg.sender] <= 0) {
            totalPlayer = totalPlayer.add(1);
        }

        _harvest(msg.sender);
        // get want from user
        uint256 _cWantBalBefore = WANT.balanceOf(address(this)); 
        WANT.transferFrom(msg.sender, address(this), _wantAmt);
        uint256 _cWantBalAfter = WANT.balanceOf(address(this));
        require(_wantAmt >= _cWantBalAfter.sub(_cWantBalBefore), "INVALID_GET_TOKEN_FROM_USER");
        // update total principal
        shareOf[msg.sender] = shareOf[msg.sender].add(_wantAmt);
        totalShare = totalShare.add(_wantAmt);
        // mint tickit
        sumTreeFactory.set(TREE_KEY, shareOf[msg.sender], bytes32(uint256(address(msg.sender))));

        lastDepositTimeOf[msg.sender] = block.timestamp;

        Craftsman.enterStaking(_wantAmt);
        
        DistributeTuringContract.updateUser(pidOfMining, msg.sender);

        emit onDeposit(msg.sender, _wantAmt);
    }
    function withdraw(uint256 _wantAmt) external nonReentrant onlyWhitelisted
    {

        _harvest(msg.sender);
        if (_wantAmt > shareOf[msg.sender]) {
            _wantAmt = shareOf[msg.sender];
        }
        require(_wantAmt > 0, 'INVALID_INPUT');
        Craftsman.leaveStaking(_wantAmt);
        uint256 _cWantBal = WANT.balanceOf(address(this));
        if (_wantAmt > _cWantBal) {
            _wantAmt = _cWantBal;
        }
        uint256 _fee = getFeeOfWithdrawEarly(msg.sender, _wantAmt);
        require(shareOf[msg.sender].sub(_fee) >= _wantAmt, 'INVALID_AMOUNT_WITHDRAW');
        // update total principal
        shareOf[msg.sender] = shareOf[msg.sender].sub(_fee).sub(_wantAmt);
        totalShare = totalShare.sub(_fee).sub(_wantAmt);
        // burn ticket
        sumTreeFactory.set(TREE_KEY, shareOf[msg.sender], bytes32(uint256(address(msg.sender))));

        WANT.transfer(msg.sender, _wantAmt);

        if (shareOf[msg.sender] <= 0) {
            totalPlayer = totalPlayer.sub(1);
        }

        DistributeTuringContract.updateUser(pidOfMining, msg.sender);

        emit onWithdraw(msg.sender, _wantAmt, _fee);
    }

    function harvest(address _user) external nonReentrant onlyWhitelisted 
    {
        _harvest(_user);
    }
    function _harvest(address _user) private 
    {
        timeOfHarvest = block.timestamp;
        uint256 beforeWantBalance = WANT.balanceOf(address(this)); 
        if(totalShare > 0) {
            Craftsman.leaveStaking(0);
            uint256 _rewardAmt = WANT.balanceOf(address(this)).sub(beforeWantBalance);
            if (_rewardAmt > 0) {
                uint256 _performanceFee = ENABLE ? _rewardAmt.mul(rateOfPerformanceFee).div(10000) : 0;
                DistributeTuringContract.processFee(pidOfMining, _performanceFee);

                uint256 _wantBal = WANT.balanceOf(address(this));
                Craftsman.enterStaking(_wantBal);
            }
        }
        DistributeTuringContract.harvest(pidOfMining, _user);
    }

    function draw() external nonReentrant onlyWhitelisted
    {
        uint256 _totalShare = totalShare;
        require(LOTTERY_END_TIME <= block.timestamp, 'INVALID_TIME');
        uint256 _tiketsWin = _random(); 
        require(_tiketsWin > 0, 'INVALID_TICKETS_WIN');
        address _userLucky = getOwnerOfToken(_tiketsWin);
       
        require(_userLucky != address(0), 'INVALID_USER_LUCKY');
        _claimReward();

        (uint256 _cWantStaked, ) = Craftsman.userInfo(0, address(this));
        Craftsman.leaveStaking(_cWantStaked);

        uint256 _cWantBal = WANT.balanceOf(address(this));

        require(_cWantBal > totalShare, 'INVALID_VVS_BALANCE');

        uint256 _wonAmt = _cWantBal.sub(totalShare);

        uint256 _rewardConvertToTuringAmt = _wonAmt.mul(rateOfConvertWinAmtToTuring).div(10000);
        uint256 _turRewardAmt = 0;
        if (_rewardConvertToTuringAmt > 0) {
            _turRewardAmt = _transferTuringReward(_userLucky, _rewardConvertToTuringAmt);
        }

        _wonAmt = _wonAmt.sub(_rewardConvertToTuringAmt);

        shareOf[_userLucky] = shareOf[_userLucky].add(_wonAmt);
        totalShare = totalShare.add(_wonAmt);
        sumTreeFactory.set(TREE_KEY, shareOf[msg.sender], bytes32(uint256(address(msg.sender))));

        _cWantBal = WANT.balanceOf(address(this));

        Craftsman.enterStaking(_cWantBal);

        LOTTERY_END_TIME = HALFTIME.add(block.timestamp);

        // UPdate history
        if (lastHistory >= 5) {
            lastHistory = 0;
        }
        History storage _h = historyList[lastHistory];

        _h.time = block.timestamp;
        _h.tiketsWin = _tiketsWin;
        _h.totalTickets = _totalShare;
        _h.winner = _userLucky;
        _h.wonAmt = _wonAmt;
        _h.turRewardAmt = _turRewardAmt;
        // _h.performanceFee = _performanceFee;

        lastHistory = lastHistory.add(1);

        emit onDraw(_tiketsWin, _userLucky, _wonAmt, _rewardConvertToTuringAmt);
    }

    function _claimReward() private {
        timeOfHarvest = block.timestamp;
        uint256 beforeWantBalance = WANT.balanceOf(address(this));
        if(totalShare > 0) {
            Craftsman.leaveStaking(0);
            uint256 _cWantBal = WANT.balanceOf(address(this)).sub(beforeWantBalance);
            if (_cWantBal > 0) {
                uint256 _performanceFee = ENABLE ? _cWantBal.mul(rateOfPerformanceFee).div(10000) : 0;
                DistributeTuringContract.processFee(pidOfMining, _performanceFee);
            }
        }
    }

    function _transferTuringReward(address _user, uint256 _amount) private returns(uint256)
    {
        uint256 _befoTurBal = TURING.balanceOf(address(this));
        address[] memory path = new address[](3);
        path[0] = address(WANT);
        path[1] = WCRO;
        path[2] = address(TURING);

        VVSRouter.swapExactTokensForTokens(_amount, 0, path, address(this), block.timestamp);

        uint256 _afterTurBal = TURING.balanceOf(address(this));
        uint256 _turRewardAmt = 0;
        if (_afterTurBal > _befoTurBal) {
            _turRewardAmt = _afterTurBal.sub(_befoTurBal);
            TURING.transfer(_user, _turRewardAmt);
        }
        return _turRewardAmt;
    }

    function _random() private returns (uint256) {

        if (totalShare <= 0) {
            return 0;
        }
        totalRandom += 1;
        uint256 randomHash = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, totalRandom, totalShare)));

        return randomHash % totalShare;
    }

    function getOwnerOfToken(uint256 _token) public view returns (address) {
      return address(uint256(sumTreeFactory.draw(TREE_KEY, _token)));
    } 
    /**
        data_[0] uint256 miningSpeed_, 
        data_[1] uint256 userWant_, 
        data_[2] uint256 userTickets_, 
        data_[3] uint256 userWantCanWithdraw_, // cake 
        data_[4] uint256 userTuringPending_, 
        data_[5] uint256 userTuringBal_, 
        data_[6] uint256 userBNBBal_, 
        data_[7] uint256 prize_, 
        data_[8] uint256 turingRewardAPY_, 
        data_[9] uint256 totalTickets_, 
        data_[10] uint256 wantPrice_, 
        data_[11] uint256 turingPrice_, 
        data_[12] uint256 endLotteryTime_, 
        data_[13] uint256 tvl_,
        data_[14] uint256 userWantBal
        data_[15] uint256 totalPlayer
    */
    function getData(
        address _user
    ) 
    public 
    view 
    returns(
        uint256[16] memory data_
    ) {
        
        data_[1] = shareOf[_user];
        data_[2] = shareOf[_user];
        data_[3] = shareOf[_user].sub(getFeeOfWithdrawEarly(_user, shareOf[_user]));
        data_[5] = TURING.balanceOf(_user);
        data_[6] = address(_user).balance;
        data_[9] = totalShare;
        (data_[4] , ) = DistributeTuringContract.getUserInfo(pidOfMining, _user);
        uint256 _totalMintPerDay = getTotalMintPerDayOf();
        // get token price by busd
        data_[10] = getWantPrice();
        data_[11] = getTuringPrice();
        data_[12] = LOTTERY_END_TIME;
        data_[13] = totalShare;
        data_[7] = getTotalReward();

        if (data_[13] > 0) {
            data_[8] = _totalMintPerDay.mul(365).mul(data_[11]).mul(10000).div(data_[13].mul(data_[10]));
        }

        data_[14] = WANT.balanceOf(_user);
        data_[15] = totalPlayer;
    }   

    function getFeeOfWithdrawEarly(address _user, uint256 _amount) public view returns(uint256) {
        uint256 _distance = block.timestamp.sub(lastDepositTimeOf[_user]);
        if (pendingTimeOfWithdraw <= _distance) {
            return 0;
        } 
        uint256 _fee = _amount.mul(rateFeeOfWithdrawEarly).div(10000);
        _fee = _fee.sub(_fee.mul(_distance).div(pendingTimeOfWithdraw));
        return _fee;
    }

    function getTotalReward() public view returns(uint256) {
        uint256 _pendingVVS = Craftsman.pendingVVS(0, address(this));
        (uint256 _vvsStaked, ) = Craftsman.userInfo(0, address(this));
        uint256 _totalVVS = _vvsStaked.add(_pendingVVS.mul(uint256(10000).sub(rateOfPerformanceFee)).div(10000));
        uint256 _totalReward = 0;

        if (_totalVVS > totalShare) {
            _totalReward = _totalVVS.sub(totalShare);
        }
        return _totalReward;
    }

    function getTuringPrice() public view returns(uint256) {
        address[] memory path = new address[](3);

        path[0] = address(TURING);
        path[1] = WCRO;
        path[2] = USDC;
        uint256 _price;
        try VVSRouter.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
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
        try VVSRouter.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
            _price = amounts[2];
        } catch {
            _price = 0;   
        }
        return _price;
    }

    function getTotalMintPerDayOf() public view returns (uint256) {
        uint256 _performanceFee = getPerfomanceFee();
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
        uint256 _wantReward = Craftsman.pendingVVS(0, address(this));
        uint256 _performanceFee = ENABLE ? _wantReward.mul(rateOfPerformanceFee).div(10000) : 0;
        return _performanceFee;
    }
}