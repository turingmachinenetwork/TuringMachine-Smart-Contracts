// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IMiningMachine.sol';
import './interfaces/IPancakeSwapRouter.sol';
import './interfaces/IBEP20.sol';
import './library/SafeMath.sol';
import './library/ReentrancyGuard.sol';

interface ITuringWhitelist {
    function whitelisted(address _address) external view returns (bool);
}
interface ITuringTimeLock {

    function doneTransactions(string memory _functionName) external;
    function clearFieldValue(string memory _functionName, string memory _fieldName, uint8 _typeOfField) external;

    function getAddressChangeOnTimeLock(address _contractCall, string memory _functionName, string memory _fieldName) external view returns(address); 
    function getUintChangeOnTimeLock(address _contractCall, string memory _functionName, string memory _fieldName) external view returns(uint256);
    function isQueuedTransaction(address _contractCall, string memory _functionName) external view returns(bool);
}
contract TuringStake is ReentrancyGuard {

    using SafeMath for uint256;
    uint256 public version = 100;
    address public owner;
    
    IBEP20 public voteTURING; // TUR
    IBEP20 public want; // TUR
    address public wbnb;
    address public busd;

    uint256 public pidOfMining;

    uint256 public TIMELOCK = 0;
    uint256 public RATE_OF_MINT_VOTE_TURING = 10000; // 1x - 100%

    mapping(address => uint256) public timeOfDepositOf;

    IMiningMachine public miningMachine;
    IPancakeSwapRouter public pancakeSwap;
    ITuringWhitelist public whitelistContract; 
    ITuringTimeLock public turingTimeLockContract;

    uint256 public totalShare = 0;

    mapping(address => uint256) public shareOf;

    modifier onlyOwner()
    {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }
    modifier onlyWhitelist()
    {
        if (msg.sender != tx.origin) {
            require(whitelistContract.whitelisted(msg.sender) == true, 'INVALID_WHITELIST');
        }
        _;
    }
    event onDeposit(address _user, uint256 _amount);
    event onWithdraw(address _user, uint256 _amount);

    constructor(
        ITuringWhitelist _whitelistContract,
        IPancakeSwapRouter _pancakeSwap,
        ITuringTimeLock _turingTimeLockContract,
        IBEP20 _voteTuring,
        IBEP20 _tur,
        address _wbnb,
        address _busd,
        uint256 _timelock,
        uint256 _rateOfMintVoteTuring
        ) public {
        owner = msg.sender;
        turingTimeLockContract = _turingTimeLockContract;
        whitelistContract = _whitelistContract;
        pancakeSwap = _pancakeSwap;
        voteTURING = _voteTuring;
        want = _tur;
        wbnb = _wbnb;
        busd = _busd;

        TIMELOCK = _timelock;
        RATE_OF_MINT_VOTE_TURING = _rateOfMintVoteTuring;
    }

    receive() external payable {
        
    }
    function transferOwnership(address _owner) public onlyOwner {
        require(_owner != address(0), "INVALID_ADDRESS");
        owner = _owner;
    }

    function setWhitelistContract(ITuringWhitelist _whitelistContract) public onlyOwner {
        whitelistContract = _whitelistContract;
    }

    function setBUSD(address _busd) public onlyOwner {
        busd = _busd;
    }

    function setWBNB(address _wbnb) public onlyOwner {
        wbnb = _wbnb;
    }

    function setMiningMachine() public onlyOwner 
    {
        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setMiningMachine'), "INVALID_PERMISSION");

        address _miningMachine = turingTimeLockContract.getAddressChangeOnTimeLock(address(this), 'setMiningMachine', 'miningMachine');

        require(_miningMachine != address(0), "INVALID_ADDRESS");

        miningMachine = IMiningMachine(_miningMachine);

        turingTimeLockContract.clearFieldValue('setMiningMachine', 'miningMachine', 1);
        turingTimeLockContract.doneTransactions('setMiningMachine');
    }

    function setPancakeSwapRouter() public onlyOwner 
    {
        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setPancakeSwapRouter'), "INVALID_PERMISSION");

        address _pancakeSwap = turingTimeLockContract.getAddressChangeOnTimeLock(address(this), 'setPancakeSwapRouter', 'pancakeSwap');

        require(_pancakeSwap != address(0), "INVALID_ADDRESS");

        pancakeSwap = IPancakeSwapRouter(_pancakeSwap);

        turingTimeLockContract.clearFieldValue('setPancakeSwapRouter', 'pancakeSwap', 1);
        turingTimeLockContract.doneTransactions('setPancakeSwapRouter');
    }

    function setWantToken() public onlyOwner 
    {
        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setWantToken'), "INVALID_PERMISSION");

        address _want = turingTimeLockContract.getAddressChangeOnTimeLock(address(this), 'setWantToken', 'want');

        require(_want != address(0), "INVALID_ADDRESS");

        want = IBEP20(_want);

        turingTimeLockContract.clearFieldValue('setWantToken', 'want', 1);
        turingTimeLockContract.doneTransactions('setWantToken');
    }

    function setVoteTuring() public onlyOwner 
    {
        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setVoteTuring'), "INVALID_PERMISSION");

        address _voteTURING = turingTimeLockContract.getAddressChangeOnTimeLock(address(this), 'setVoteTuring', 'voteTURING');

        require(_voteTURING != address(0), "INVALID_ADDRESS");

        voteTURING = IBEP20(_voteTURING);

        turingTimeLockContract.clearFieldValue('setVoteTuring', 'voteTURING', 1);
        turingTimeLockContract.doneTransactions('setVoteTuring');
    }

    function setTIMELOCK() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setTIMELOCK'), "INVALID_PERMISSION");

        TIMELOCK = turingTimeLockContract.getUintChangeOnTimeLock(address(this), 'setTIMELOCK', 'TIMELOCK');

        turingTimeLockContract.clearFieldValue('setTIMELOCK', 'TIMELOCK', 2);
        turingTimeLockContract.doneTransactions('setTIMELOCK');
    }

    function setRateOfMintVoteTuring() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setRateOfMintVoteTuring'), "INVALID_PERMISSION");

        RATE_OF_MINT_VOTE_TURING = turingTimeLockContract.getUintChangeOnTimeLock(address(this), 'setRateOfMintVoteTuring', 'RATE_OF_MINT_VOTE_TURING');

        turingTimeLockContract.clearFieldValue('setRateOfMintVoteTuring', 'RATE_OF_MINT_VOTE_TURING', 2);
        turingTimeLockContract.doneTransactions('setRateOfMintVoteTuring');
    }

    function setPidOfMining() public onlyOwner 
    {
        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setPidOfMining'), "INVALID_PERMISSION");

        pidOfMining = turingTimeLockContract.getUintChangeOnTimeLock(address(this), 'setPidOfMining', 'pidOfMining');

        turingTimeLockContract.clearFieldValue('setPidOfMining', 'pidOfMining', 2);
        turingTimeLockContract.doneTransactions('setPidOfMining');
    }


    function deposit(uint256 _wantAmt) external nonReentrant onlyWhitelist
    {
        uint256 _wantBal = want.balanceOf(msg.sender);
        if (_wantAmt > _wantBal) {
            _wantAmt = _wantBal;
        }
        require(_wantAmt > 0, 'INVALID_INPUT');

        harvest(msg.sender);
        // Get token
    	want.transferFrom(msg.sender, address(this), _wantAmt);
        // Update User's share
        shareOf[msg.sender] = shareOf[msg.sender].add(_wantAmt);
        totalShare = totalShare.add(_wantAmt);
        // Update time of deposit for user
        timeOfDepositOf[msg.sender] = block.timestamp;
        //Mint voteTuring
        voteTURING.mint(msg.sender, _wantAmt.mul(RATE_OF_MINT_VOTE_TURING).div(10000));
        miningMachine.updateUser(pidOfMining, msg.sender);
        // Emit event
        emit onDeposit(msg.sender, _wantAmt);

    }
    function withdraw(uint256 _wantAmt) external nonReentrant onlyWhitelist
    {
        require(timeOfDepositOf[msg.sender].add(TIMELOCK) <= block.timestamp, 'INVALID_TIMELOCK');
        harvest(msg.sender);
        uint256 _share = shareOf[msg.sender];
        if (_wantAmt > _share) {
            _wantAmt = _share;
        }
        require(_wantAmt > 0, 'INVALID_INPUT');
        // Check tur vote
        require(_wantAmt.mul(RATE_OF_MINT_VOTE_TURING).div(10000) <= voteTURING.balanceOf(msg.sender), 'INVALID_VOTE_TURING_BAL');
        // Burn tur vote
        voteTURING.burn(msg.sender, _wantAmt.mul(RATE_OF_MINT_VOTE_TURING).div(10000));
        // Sub Share of user
        shareOf[msg.sender] = shareOf[msg.sender].sub(_wantAmt);
        totalShare = totalShare.sub(_wantAmt);
        // Transfer Token(Tur) to user
        uint256 _wantBal = want.balanceOf(address(this)); 
        if (_wantBal < _wantAmt) {
            _wantAmt = _wantBal;
        }

        want.transfer(msg.sender, _wantAmt);
        miningMachine.updateUser(pidOfMining, msg.sender);
    	// Emit event
        emit onWithdraw(msg.sender, _wantAmt);
    }
    function harvest(address _user) public onlyWhitelist returns(uint256 _pendingTur, uint256 _bonus) 
    { 
        return miningMachine.harvest(pidOfMining, _user);
    }

    function getData(
        address _user
    ) 
    public 
    view
    returns(
        uint256 miningSpeed_,
        uint256 userTuringBal_, 
        uint256 turingPrice_, 
        uint256 totalMintPerDay_, 
        uint256 userTuringPending_, 
        uint256 userTuringShare_, 
        uint256 turingRewardAPY_,
        uint256 userVoteTuring_, 
        uint256 totalVoteTuring_,
        uint256 withdrawTime_,
        uint256 totalShare_,
        uint256 tvl_
    ) {
        withdrawTime_ = getWithdrawTime(_user);
        turingPrice_ = getTuringPrice();
        totalMintPerDay_ = miningMachine.getTotalMintPerDayOf(pidOfMining);
        totalVoteTuring_ = voteTURING.totalSupply();
        miningSpeed_ = miningMachine.getMiningSpeedOf(pidOfMining);
        userVoteTuring_  = voteTURING.balanceOf(_user);
        (userTuringPending_, , ) = miningMachine.getUserInfo(pidOfMining, _user);
        userTuringBal_ = want.balanceOf(_user);
        userTuringShare_ = shareOf[_user];
        totalShare_ = totalShare;

        tvl_ = totalShare_.mul(turingPrice_).div(1e18);
        
        if (totalShare_ > 0) {
            turingRewardAPY_ = totalMintPerDay_.mul(365).mul(10000).div(totalShare_);
        }
    } 
    function getWithdrawTime(address _user) public view returns(uint256) {
        return timeOfDepositOf[_user].add(TIMELOCK);
    }
    function getTuringPrice() public view returns(uint256) {
        address[] memory path = new address[](3);

        path[0] = address(want);
        path[1] = wbnb;
        path[2] = busd;
        uint256 _price;
        try pancakeSwap.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
            _price = amounts[2];
        } catch {
            _price = 0;   
        }
        return _price;
    }
}