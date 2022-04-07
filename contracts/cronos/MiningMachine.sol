// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/ITuring.sol';
import './interfaces/ITuringFarm.sol';
import './interfaces/ITuringDevLock.sol';
import './interfaces/ITuringTimeLock.sol';
import './interfaces/ITuringWhiteList.sol';
import './library/SafeMath.sol'; 
import './library/Ownable.sol'; 

contract MiningMachine is Ownable {

    uint256 public version = 100;
    using SafeMath for uint256;
    // Dev Locked Contract.
    ITuringTimeLock public turingTimeLockContract;
    ITuringWhitelist public turingWhitelistContract;
    ITuringDevLock public devLockedTokenContract; 

    ITuring public TUR;
    uint256 public totalBlockPerDay = 28800;// just use for dislay at UI
    // Turing each block.
    uint256 public turPerBlock = 50000000000000000;
    // The total point for all pools
    uint256 public totalAllocPoint = 1000;
    // The block when mining start
    uint256 public startBlock;

    PoolInfo[] public poolInfo;

    mapping(uint256 => mapping(address => uint256)) public rewardDebtOf;
    
    struct PoolInfo {
    	address want; // LP token Addess
        ITuringFarm turingFarm;             // Address of Turing Farm Contract.
        uint256 allocPoint;                 // Mining speef for the pool.
        uint256 lastRewardBlock;            // Last block number when the pool get reward.
        uint256 accTurPerShare;             // Turing Per Share of the pool.
    }
    modifier isQueued(string memory _functionName) {
        require(turingTimeLockContract.isQueuedTransaction(address(this), _functionName) == true, "INVALID_PERMISTION");
        _;
        turingTimeLockContract.doneTransaction(_functionName);
    }
    modifier onlyWhitelisted() 
    {
        if(msg.sender != tx.origin) {
            require(turingWhitelistContract.isWhitelisted(msg.sender) == true, "INVALID_WHITElIST");
        }
        _;
    }
    event onHarvest(uint256 _pid, address _user, uint256 _amt);
    constructor(
        ITuring _tur,
        ITuringWhitelist _turingWhiteListContract,
        ITuringDevLock _devLockedTokenContract,
        ITuringTimeLock _turingTimeLockContract,
        uint256 _turPerBlock,
        uint256 _startBlock
    ) {
        devLockedTokenContract = _devLockedTokenContract;
        turingTimeLockContract = _turingTimeLockContract;
        turingWhitelistContract = _turingWhiteListContract;
        TUR = _tur;
        turPerBlock = _turPerBlock;
        startBlock = _startBlock;
    }

    receive() external payable {
        
    }
    function setTotalBlockPerDay(uint256 _totalBlockPerDay) public onlyOwner isQueued("setTotalBlockPerDay") {
        totalBlockPerDay = _totalBlockPerDay;
    }

    function setTotalAllocPoint(uint256 _totalAllocPoint) public onlyOwner isQueued("setTotalAllocPoint") {
        require(_totalAllocPoint > 0, "INVALID_AMOUNT");
        totalAllocPoint = _totalAllocPoint;
    }
    function setTuringWhiteListContract(ITuringWhitelist _turingWhiteListContract) public onlyOwner isQueued("setTuringWhiteListContract") {
        turingWhitelistContract = _turingWhiteListContract;
    }
    function setTuringTokenContract(ITuring _TUR) public onlyOwner isQueued("setTuringTokenContract") {
        require(address(TUR) != address(0), "INVALID_ADDRESS");
        TUR = _TUR;
    }
    function setDevLockedTokenContract(ITuringDevLock _devLockedTokenContract) public onlyOwner isQueued("setDevLockedTokenContract") {
        devLockedTokenContract = _devLockedTokenContract;
    }
    // Add a new pool. Can only be called by the owner.
    function addPool(uint256 _allocPoint, ITuringFarm _turFarm) public onlyOwner isQueued("addPool") { 
    	address want = address(_turFarm.want());
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        poolInfo.push(PoolInfo({
            want: want,
            
            turingFarm: _turFarm,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accTurPerShare: 0
        }));
    }

    //Update the given pool's allocation point. Can only be called by the owner.
    function setPoolPoint(uint256 _pid, uint256 _allocPoint) public onlyOwner isQueued("setPoolPoint") {
    	require(poolInfo[_pid].allocPoint != _allocPoint, 'INVALID_INPUT');
    	_updatePool(_pid);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid, uint256 _amount) public onlyWhitelisted {
        // nhan dc tien
        // cont => 
        _updatePool(_pid);
    }

    function harvest(uint256 _pid, address _user) external onlyWhitelisted returns(uint256 _pendingTur) 
    {	
    	_updatePool(_pid);
    	uint256 _rewardDebt;
    	(_pendingTur, _rewardDebt, ) = getUserInfo(_pid, _user);

    	uint256 _turBal = TUR.balanceOf(address(this));

    	rewardDebtOf[_pid][_user] = _rewardDebt;

    	if (_pendingTur > _turBal) {
            _pendingTur = _turBal;
    	}
        if (_pendingTur > 0) {
            TUR.transfer(_user, _pendingTur);
            emit onHarvest(_pid, _user, _pendingTur);
        }
    }

    function updateUser(uint256 _pid, address _user) public returns(bool)
    {
        PoolInfo memory pool = poolInfo[_pid];
        require(address(pool.turingFarm) == msg.sender, 'INVALID_PERMISSION');

        uint256 _userShare  = pool.turingFarm.shareOf(_user);
        rewardDebtOf[_pid][_user] = _userShare.mul(pool.accTurPerShare).div(1e12);

        return true;
    }
    function _updatePool(uint256 _pid, _reward) private {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 _totalShare = pool.turingFarm.totalShare();
        uint256 _multiplier = getBlockFrom(pool.lastRewardBlock, block.number);
        // uint256 _reward = _multiplier.mul(turPerBlock).mul(pool.allocPoint).div(totalAllocPoint);

        if (_totalShare == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 _cTurBalBefore = TUR.balanceOf(address(this));
        TUR.mint(address(this), _reward);
        uint256 _cTurBalAfter = TUR.balanceOf(address(this));
        uint256 _cTurBalChanged = _cTurBalAfter.sub(_cTurBalBefore);
        if (_reward > _cTurBalChanged) {
            _reward = _cTurBalChanged;
        } 
        TUR.mint(address(devLockedTokenContract), _reward.div(10)); //Give the dev 10% of TURING token to a locked contract
        devLockedTokenContract.addDevFund(_reward.div(10));

        pool.accTurPerShare = pool.accTurPerShare.add(_reward.mul(1e12).div(_totalShare));
        pool.lastRewardBlock = block.number;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getBlockFrom(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    function getMiningSpeedOf(uint256 _pid) public view returns(uint256) {
        return poolInfo[_pid].allocPoint.mul(100).div(totalAllocPoint);
    }

    function getTotalMintPerDayOf(uint256 _pid) public view returns(uint256) {
        return totalBlockPerDay.mul(turPerBlock).mul(poolInfo[_pid].allocPoint).div(totalAllocPoint);
    }

    function getTurAddr() public view returns(address) {
        return address(TUR);
    }

    // View function to get User's Info in a pool.
    function getUserInfo(uint256 _pid, address _user) public view returns (uint256 _pendingTur, uint256 _rewardDebt, uint256 _userShare) { 

        PoolInfo memory pool = poolInfo[_pid];

        uint256 accTurPerShare = pool.accTurPerShare;

        // uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        uint256 _totalShare = pool.turingFarm.totalShare();
        _userShare  = pool.turingFarm.shareOf(_user);

        if (block.number > pool.lastRewardBlock && _totalShare != 0) {
            uint256 _multiplier = getBlockFrom(pool.lastRewardBlock, block.number);
            uint256 _reward = _multiplier.mul(turPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accTurPerShare = accTurPerShare.add(_reward.mul(1e12).div(_totalShare));
        }
        _rewardDebt  = _userShare.mul(accTurPerShare).div(1e12);

        if (_rewardDebt > rewardDebtOf[_pid][_user]) {
            _pendingTur = _rewardDebt.sub(rewardDebtOf[_pid][_user]);
        }
    }
}