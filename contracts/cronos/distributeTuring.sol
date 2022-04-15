// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/ITuring.sol';
import './interfaces/ITuringFarm.sol';
import './interfaces/ITuringDevLock.sol';
import './interfaces/ITuringTimeLock.sol';
import './interfaces/ITuringWhiteList.sol';
import './interfaces/IPriceOracle.sol';
import './interfaces/ITuringFarmTuringCroLp.sol';
import './interfaces/IVVSRouter.sol';
import './interfaces/IBEP20.sol';
import './library/SafeMath.sol'; 
import './library/Ownable.sol'; 

contract distributeTuring is Ownable {
    uint256 public version = 100;
    using SafeMath for uint256;

    ITuringTimeLock public TuringTimeLockContract;
    ITuringWhitelist public TuringWhitelistContract;
    IPriceOracle public PriceOracleContract;
    ITuringDevLock public DevLockedTokenContract;
    ITuringFarmTuringCroLp public TuringFarmTuringCroLPContract;
    IVVSRouter public vvsRouter; 

    ITuring public TURING;
    address public WCRO;
    address public ProtocolLiquidityLaunchContract;

    uint256 MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 ratioRewardTuringCroLp = 1000; //10%
    uint256 baseRatio = 1e18;
    uint256 public ratioConvertTuringToWcro;

    mapping(uint256 => mapping(address => uint256)) public rewardDebtOf;
    mapping(address => uint256) public tokenDecimals;

    modifier isQueued(string memory _functionName) {
        require(TuringTimeLockContract.isQueuedTransaction(address(this), _functionName) == true, "INVALID_PERMISTION");
        _;
        TuringTimeLockContract.doneTransaction(_functionName);
    }
    modifier onlyWhitelisted() 
    {
        if(msg.sender != tx.origin) {
            require(TuringWhitelistContract.isWhitelisted(msg.sender) == true, "INVALID_WHITElIST");
        }
        _;
    }

    PoolInfo[] public poolInfo;
    
    struct PoolInfo {
    	address want;                       // LP token Addess
        ITuringFarm turingFarm;             // Address of Turing Farm Contract.   
        IBEP20 tokenReward;                 // token earn
        uint256 accTurPerShare;             // % 
    }
    event onHarvest(uint256 _pid, address _user, uint256 _amt);
    constructor(
        ITuring _TURING,
        ITuringTimeLock _TuringTimeLockContract,
        ITuringWhitelist _TuringWhiteListContract,
        ITuringDevLock _DevLockedTokenContract,
        IVVSRouter _vvsRouter,

        address _WCRO
    ) {
        DevLockedTokenContract = _DevLockedTokenContract;
        TuringTimeLockContract = _TuringTimeLockContract;
        TuringWhitelistContract = _TuringWhiteListContract;
        vvsRouter = _vvsRouter;
        TURING = _TURING;
        WCRO = _WCRO;
    }

    receive() external payable {
    }

    function setPriceOracleContract(IPriceOracle _PriceOracleContract) public onlyOwner isQueued("setPriceOracleContract") {
        PriceOracleContract = _PriceOracleContract;
    }

    function setTuringWhiteListContract(ITuringWhitelist _TuringWhiteListContract) public onlyOwner isQueued("setTuringWhiteListContract") {
        TuringWhitelistContract = _TuringWhiteListContract;
    }

    function setTuringTokenContract(ITuring _TURING) public onlyOwner isQueued("setTuringTokenContract") {
        require(address(TURING) != address(0), "INVALID_ADDRESS");
        TURING = _TURING;
    }

    function setDevLockedTokenContract(ITuringDevLock _DevLockedTokenContract) public onlyOwner isQueued("setDevLockedTokenContract") {
        DevLockedTokenContract = _DevLockedTokenContract;
    }

    /**                     MATH
        1 turing = (baseRatio / _value) * WCRO
        example:
            we have baseRatio = 1e18.
            if you want to set the ratio 1 turing = 0,7 WCRO.
            => _value = 1e18 * 0,7 = 7e17;
            vice versa if 0,7 turing = 1 WCRO
            => _value = 1e18 / 0,7 =1.42857142857*1e18.
     */ 
    function setRatioConvertTuringToWcro(uint256 _value) public onlyOwner isQueued("setRatioConvertTuringToWcro") {
        ratioConvertTuringToWcro = _value;
    }

    function setTokenDecimals(address _token, uint256 _decimals) public onlyOwner isQueued("setTokenDecimals") {
        tokenDecimals[_token] = _decimals;
    }

    function setRatioRewardTuringCroLp(uint256 _value) public onlyOwner isQueued("setRatioRewardTuringCroLp") {
        require(ratioRewardTuringCroLp != _value, "MUST NOT BETHE SAME");
        ratioRewardTuringCroLp = _value;
    }

    function setVvsRouterContract(IVVSRouter _vvsRouter) public onlyOwner isQueued("setVvsRouterContract") {
        vvsRouter = _vvsRouter;
    }

    function setTuringFarmTuringCroLPContract(address _TuringFarmTuringCroLPContract) public onlyOwner isQueued("setTuringFarmTuringCroLPContract") {
        TuringFarmTuringCroLPContract = ITuringFarmTuringCroLp(_TuringFarmTuringCroLPContract);
    }

    function setProtocolLiquidityLaunchContract(address _ProtocolLiquidityLaunchContract) public onlyOwner isQueued("setProtocolLiquidityLaunchContract") {
        ProtocolLiquidityLaunchContract = _ProtocolLiquidityLaunchContract;
    }

    function connectToVVS(IBEP20 _token) public onlyOwner {
        _token.approve(address(vvsRouter), MAX_INT);
    }

    function connectToTuringFarmTuringCroLpContract() public onlyOwner {
        TURING.approve(address(TuringFarmTuringCroLPContract), MAX_INT);
    }

    function addPool(ITuringFarm _turFarm, IBEP20 _tokenReward) public onlyOwner isQueued("addPool") {
        address want = address(_turFarm.WANT());
        poolInfo.push(PoolInfo({
            want: want,
            turingFarm: _turFarm,
            tokenReward: _tokenReward,
            accTurPerShare: 0
        }));
    }

    function processFee(uint256 _pid, uint256 _wantAmt) external {
        if(_wantAmt == 0) { 
            return;
        }

        PoolInfo storage pool = poolInfo[_pid];
        require(address(pool.turingFarm) == msg.sender, "ONLY_FARM_CONTRACT");

        uint256 _beforeTokenRewardOfBal = pool.tokenReward.balanceOf(address(this));
        pool.tokenReward.transferFrom(msg.sender, address(this), _wantAmt);
        require(_wantAmt >= pool.tokenReward.balanceOf(address(this)).sub(_beforeTokenRewardOfBal), "INVALID_AMOUNT_TOKEN");
        // convert token reward to tur
        uint256 _turingReward = getDistribution(_pid, _wantAmt);
        if(_turingReward > 0) {
            _updatePool(_pid, _turingReward);    
        }
    }

    function processProtocolLiquidityLaunch(uint256[] calldata _ratios) external payable {
        require(msg.sender == ProtocolLiquidityLaunchContract, "ONLY_PROTOCOL_LIQUIDITY_LUANCH_CONTRACT");
        uint256 _rewardCRO = msg.value;

        uint256 _convertCroToTuring = _rewardCRO.mul(baseRatio).div(ratioConvertTuringToWcro);

        for(uint256 _pid = 0; _pid < poolInfo.length; _pid++){
            if(_ratios[_pid] > 0) {
                _updatePool(_pid,_convertCroToTuring.mul(_ratios[_pid]).div(baseRatio));
            }
        }
    }

    function _updatePool(uint256 _pid, uint256 _reward) private {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 _totalShare = pool.turingFarm.totalShare();
        if(_totalShare == 0) {
            return;
        }
        uint256 _cTurBal = TURING.balanceOf(address(this));
        if (_reward > _cTurBal) {
            _reward = _cTurBal;
        } 

        TURING.transfer(address(DevLockedTokenContract), _reward.div(10)); //Give the dev 10% of TURING token to a locked contract
        DevLockedTokenContract.addDevFund(_reward.div(10));

        if(!disableTuringFarmTuringCroLp()) {
            _cTurBal = TURING.balanceOf(address(this));
            if (_reward > _cTurBal) {
                _reward = _cTurBal;
            }
            uint256 _turingRewardOfTuringFarmTuringCroLPContract = _reward.mul(ratioRewardTuringCroLp).div(10000);
            if(_turingRewardOfTuringFarmTuringCroLPContract > 0) {
                TuringFarmTuringCroLPContract.distribution(_turingRewardOfTuringFarmTuringCroLPContract);
            }
        }

        pool.accTurPerShare = pool.accTurPerShare.add(_reward.mul(1e24).div(_totalShare));
    }

    function harvest(uint256 _pid, address _user) external onlyWhitelisted returns(uint256 _uPendingTur){
        PoolInfo storage pool = poolInfo[_pid];

        uint256 _turBal = TURING.balanceOf(address(this));

        uint256 _uShare = pool.turingFarm.shareOf(_user);
        uint256 _accTurPerShare = pool.accTurPerShare;

        uint256 _allRerawdTurOfUser = (_uShare.mul(_accTurPerShare).div(1e24));
        uint256 _uRewardDebt = rewardDebtOf[_pid][_user];
        if(_allRerawdTurOfUser > _uRewardDebt) {
            _uPendingTur = _allRerawdTurOfUser.sub(_uRewardDebt);
        }
        if(_uPendingTur > _turBal) {
            _uPendingTur = _turBal;
        }
        if(_uPendingTur > 0) {
            TURING.transfer(_user, _uPendingTur);
        }
        //update reward debt of user
        rewardDebtOf[_pid][_user] = _allRerawdTurOfUser;

        emit onHarvest(_pid, _user, _uPendingTur);
    }

    function burnToken(IBEP20 _tokenBurn) public onlyWhitelisted {

        uint256 _tokenBal = _tokenBurn.balanceOf(address(this));
        uint256 _beforeTuringBal = TURING.balanceOf(address(this));

        require(address(TURING) != address(_tokenBurn), 'INVALID_PERMISSION');

        address[] memory path;
        if (address(_tokenBurn) != address(WCRO)) {

            path = new address[](3);
            path[0] = address(_tokenBurn);
            path[1] = address(WCRO);
            path[2] = address(TURING);

        } else if(address(_tokenBurn) == address(WCRO)){

            path = new address[](2);
            path[0] = address(WCRO);
            path[1] = address(TURING);
        }

        vvsRouter.swapExactTokensForTokens(_tokenBal, 0, path, address(this), block.timestamp);

        // burn turing token
        uint256 _afterTuringBal = TURING.balanceOf(address(this));
        uint256 _turingBurn = _afterTuringBal.sub(_beforeTuringBal);
        if (_turingBurn > 0) {
            TURING.burn(address(this), _turingBurn);
        }       
    }

    function bunrCro() public payable onlyOwner {
        uint256 _croBlc = address(this).balance;
        uint256 _beforeTuringBal = TURING.balanceOf(address(this));
        require(_croBlc > 0, "NOT ASSET");

        address[] memory path;
        path = new address[](2);
        path[0] = address(WCRO);
        path[1] = address(TURING);

        vvsRouter.swapETHForExactTokens{value: _croBlc}(_croBlc, path, address(this), block.timestamp);

        uint256 _afterTuringBal = TURING.balanceOf(address(this));
        uint256 _turingBurn = _afterTuringBal.sub(_beforeTuringBal);
        if (_turingBurn > 0) {
          TURING.burn(address(this), _turingBurn);
        }

    }

    function enableFarmTuring() external {
        require(msg.sender == ProtocolLiquidityLaunchContract, "ONLY_PROTOCOL_LIQUIDITY_LUANCH_CONTRACT");
        uint256 _poolsLength;
        _poolsLength = poolLength();
        for(uint256 _pid = 0; _pid < _poolsLength; _pid++) {
            PoolInfo storage pool = poolInfo[_pid];
            if(pool.turingFarm.ENABLE() == false) {
                pool.turingFarm.enable();
            }
        }
    }

    function updateUser(uint256 _pid, address _user) public returns(bool)
    {
        PoolInfo memory pool = poolInfo[_pid];
        require(address(pool.turingFarm) == msg.sender, 'INVALID_PERMISSION');

        uint256 _userShare  = pool.turingFarm.shareOf(_user);
        rewardDebtOf[_pid][_user] = _userShare.mul(pool.accTurPerShare).div(1e24);

        return true;
    }

    function getUserInfo(uint256 _pid, address _user) public view returns (uint256 _turingReward, uint256 _rewardDebt, uint256 _uShare) {
        PoolInfo memory pool = poolInfo[_pid];

        uint256 _accTurPerShare = pool.accTurPerShare;
        _uShare = pool.turingFarm.shareOf(_user);
        uint256 _totalShare = pool.turingFarm.totalShare();

        if (_totalShare != 0) {
            uint256 _reward = getDistribution(_pid, pool.turingFarm.getPerfomanceFee());
            _accTurPerShare = _accTurPerShare.add(_reward.mul(1e24).div(_totalShare));
        }
        _rewardDebt  = _uShare.mul(_accTurPerShare).div(1e24);

        if (_rewardDebt > rewardDebtOf[_pid][_user]) {
            _turingReward = _rewardDebt.sub(rewardDebtOf[_pid][_user]);
        }

    }

    // _amountIn: want
    // _amountOut: turing
    function getDistribution(uint256 _pid ,uint256 _amountIn) public view returns (uint256 _amountOut) {
        if(_amountIn == 0) {
            _amountOut = 0;
        }
        PoolInfo memory pool = poolInfo[_pid];
        address _tokenReward = address(pool.tokenReward);
        uint256 _convertAmtIn;
        _convertAmtIn = convertDecimals(tokenDecimals[_tokenReward], _amountIn);
        _amountOut = _convertAmtIn.mul(getTokenRewardToWCRORate(_tokenReward)).div(baseRatio);
    }

    function getTokenRewardToWCRORate(address _token) public view returns(uint256) {
        uint256 _priceTokenRewardToWCRO = PriceOracleContract.priceOf(_token);
        return _priceTokenRewardToWCRO.mul(baseRatio).div(ratioConvertTuringToWcro);
    }

    function disableTuringFarmTuringCroLp() public view returns(bool) {
        uint256 totalShareOfTuringFarmTurCroLp = TuringFarmTuringCroLPContract.totalShare();
        if(totalShareOfTuringFarmTurCroLp == 0) {
            return true;
        }
        return false;
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    function convertDecimals(uint256 _tokenDecimals, uint256 _amount) public pure returns(uint256) {
        return _amount.mul(1e18).div(10 **_tokenDecimals);
    }

}