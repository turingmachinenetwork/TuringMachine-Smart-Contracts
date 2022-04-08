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

contract protocolLiquidityLaunch {
    using SafeMath for uint256;
    using SafeMath for uint112;

    address public owner;

    IBEP20 public TURING;
    IVVSRouter public VVSRouterContract;
    IDistributeTuring public DistributeTuringContract;    
    ITuringTimeLock public TuringTimeLockContract;
    ITuringWhitelist public TuringWhitelistContract;
    ITuringCrpLpContract public TuirngCroLpContract;
    IPriceOracle public PriceOracleContract;

    address public WCRO;
    address public USDC;

    uint256 private MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    uint256 public priceTuringLaunchpad = 1e16; // $0,01
    uint256 public totalTuringBuyLaunchpad = 100000e18; // 100000 turing
    uint256 public priceTuringToCRO;
    uint256 public baseRatio = 1e18;
    uint256 public ratioCroAddLp = 8e17; // 80%

    bool public ENABLE = true;
    
    uint256 public maxQuantityBuyTuringOfUser = 100e18; // 100
    mapping(address => uint256) public turingbuyedOf;
    mapping(uint256 => uint256) public ratioPidsOf;     // 30% = 0,3e18 = 3e17 

    uint256[] public arrPid;

    event onBuy(address _user, uint256 _croSend, uint256 _croRefund, uint256 _turingReceive);

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
            require(TuringWhitelistContract.isWhitelisted(msg.sender) == true, "INVALID_WHITElIST");
        }
        _;
    }

    receive() external payable {}

    constructor(
        ITuringTimeLock _TuringTimeLockContract,
        ITuringWhitelist _TuringWhiteListContract,
        IVVSRouter _VVSRouterContract,
        IDistributeTuring _DistributeTuringContract,
        ITuringCrpLpContract _TuirngCroLpContract,
        IPriceOracle _PriceOracleContract,
        IBEP20 _TURING,
        address _USDC,
        address _WCRO
    ) {
        TuringTimeLockContract = _TuringTimeLockContract;
        TuringWhitelistContract = _TuringWhiteListContract;
        VVSRouterContract = _VVSRouterContract;
        DistributeTuringContract = _DistributeTuringContract;
        TuirngCroLpContract = _TuirngCroLpContract;
        PriceOracleContract = _PriceOracleContract;

        TURING = _TURING;
        USDC = _USDC;
        WCRO = _WCRO;

        owner = msg.sender;
    }

    function enable() public onlyOwner {
        ENABLE = true;
    }
    function disable() public onlyOwner {
        ENABLE = false;
    }

    function connectVVSRouter() public onlyWhitelisted {
        TURING.approve(address(VVSRouterContract), MAX_INT);
    }

    function setTuringWhiteListContract(ITuringWhitelist _TuringWhiteListContract) public onlyOwner isQueued("setTuringWhiteListContract") {
        TuringWhitelistContract = _TuringWhiteListContract;
    }

    function setTuringTokenContract(IBEP20 _TURING) public onlyOwner isQueued("setTuringTokenContract") {
        require(address(TURING) != address(0), "INVALID_ADDRESS");
        TURING = _TURING;
    }

    function setDistributeTuringContract(IDistributeTuring _DistributeTuringContract) public onlyOwner isQueued("setDistributeTuringContract") {
        DistributeTuringContract = _DistributeTuringContract;
    }

    function setTuirngCroLpContract(ITuringCrpLpContract _TuirngCroLpContract) public onlyOwner isQueued("setTuirngCroLpContract") {
        TuirngCroLpContract = _TuirngCroLpContract;
    }

    function setVVSRouterContract(IVVSRouter _VVSRouterContract) public onlyOwner isQueued("setVVSRouterContract") {
        VVSRouterContract = _VVSRouterContract;
    }

    function setPriceOracleContract(IPriceOracle _PriceOracleContract) public onlyOwner isQueued("setPriceOracleContract") {
        PriceOracleContract = _PriceOracleContract;
    }

    function setPriceTuringLaunchpad(uint256 _priceTuringLaunchpad) public onlyOwner isQueued("setPriceTuringLaunchpad") {
        priceTuringLaunchpad = _priceTuringLaunchpad;
    }

    function setTotalTuringBuyLaunchpad(uint256 _totalTuringBuyLaunchpad) public onlyOwner isQueued("setTotalTuringBuyLaunchpad") {
        totalTuringBuyLaunchpad = _totalTuringBuyLaunchpad;
    }

    function setMaxQuantityBuyTuringOfUser(uint256 _maxQuantityBuyTuringOfUser) public onlyOwner isQueued("setMaxQuantityBuyTuringOfUser") {
        maxQuantityBuyTuringOfUser = _maxQuantityBuyTuringOfUser;
    }

    // 1 turing = ? cro 
    function getPriceTuringToCRO() public view returns(uint256) {
        uint256 _priceUsdcToCro = PriceOracleContract.priceOf(USDC);
        return priceTuringLaunchpad.mul(_priceUsdcToCro).div(baseRatio);
    }

    /**
    exemple : 
        if set pool 0 with 20% cro on distribute:
        _pid: 0;
        _ratio: (20/100) * 1e18 = 2e17;
     */
    function setRatioPidsOf(uint256 _pid, uint256 _ratio) public onlyOwner isQueued("setRatioPidsOf") {
        uint256 _poolsLength = DistributeTuringContract.poolLength();
        require(_pid < _poolsLength, "INVALID_PID");
        uint256 _totalRatio;
        _totalRatio = getTotalRatioDistribute();
        require(_totalRatio.add(_ratio) <= baseRatio, "INVALID_RATIO");
        ratioPidsOf[_pid] = _ratio;
    }

    function buy() public payable onlyWhitelisted {
        require(ENABLE == true, "SYSTEM_STOP");
        require(msg.value > 0, "INVALID_AMOUNT_1");
        uint256 croRefund;
        uint256 turingReceive;
        uint256 croSend;
        (croSend, croRefund, turingReceive) = getProcessAmt(msg.sender, msg.value);

        require(croSend.add(croRefund) <= msg.value, "INVALID_AMOUNT_2");

        TURING.transfer(msg.sender, turingReceive);

        totalTuringBuyLaunchpad = totalTuringBuyLaunchpad.sub(turingReceive);
        turingbuyedOf[msg.sender] = turingbuyedOf[msg.sender].add(turingReceive);

        if(croRefund >  0) {
            _transfer(payable(msg.sender) , croRefund);
        }

        emit onBuy(msg.sender, croSend, croRefund, turingReceive);

    }

    function _transfer(address payable _to, uint256 _amt) private {
        bool sent = _to.send(_amt);
        require(sent, "Failed to send Ether");
    }

    function close() public onlyWhitelisted onlyOwner {
        require(ENABLE == true, "INVALID_CLOSE");
        ENABLE = false;
        uint256 _croBalance;
        _croBalance = getCroBalance();

        require(ratioCroAddLp > 0, "INVALID_RATIO_CRO_ON_ADD_LIQUIDITY_POOL");
        uint256 _amtCroOnAddLp = _croBalance.mul(ratioCroAddLp).div(baseRatio);
        uint256 _amtCroDistributeOnFarm = _croBalance.sub(_amtCroOnAddLp);

        _addLiquidity(_amtCroOnAddLp);
        _DistributeOnFarms(_amtCroDistributeOnFarm);

        

    }

    function _addLiquidity(uint256 _amtCroOnAddLp) private {
        uint112 _amtCroLpContract;
        uint112 _amtTuringLpContract;
        uint256 _amtTuringOnAddLp;

        (_amtCroLpContract, _amtTuringLpContract) = getReserves();
        _amtTuringOnAddLp = getEstimateTuringOnAddLp(_amtCroOnAddLp, _amtCroLpContract, _amtTuringLpContract);

        VVSRouterContract.addLiquidityETH{value: _amtCroOnAddLp}(address(TURING), _amtTuringOnAddLp, 1, 1, msg.sender, block.timestamp);

    }

    function _DistributeOnFarms(uint256 _amtCroDistributeOnFarm) private {

        for(uint256 _pid = 0; _pid < DistributeTuringContract.poolLength(); _pid++){
            arrPid.push(ratioPidsOf[_pid]);
        }
        DistributeTuringContract.processProtocolLiquidityLaunch{value: _amtCroDistributeOnFarm}(arrPid);
    }

    function getProcessAmt(address _user, uint256 _amtCRO) public view returns(uint256 _croSend, uint256 _croRefund, uint256 _turingReceive) {
        uint256 _maxTuringCanBuyOf;
        _maxTuringCanBuyOf = getMaxNumberTuringOfUserOnBuy(_user);
        if(_maxTuringCanBuyOf == 0) {
            _croSend = 0;
            _croRefund = _amtCRO;
            _turingReceive = 0;
            return(_croSend, _croRefund, _turingReceive);
        }

        uint256 _convertMaxTuringCanBuyOf = _maxTuringCanBuyOf.mul(getPriceTuringToCRO()).div(baseRatio);

        if(_convertMaxTuringCanBuyOf <= _amtCRO) {
            _croSend = _convertMaxTuringCanBuyOf;
            _croRefund = _amtCRO.sub(_convertMaxTuringCanBuyOf);
            _turingReceive = _croSend.mul(baseRatio).div(getPriceTuringToCRO());
            return(_croSend, _croRefund, _turingReceive);
        }

        if(_convertMaxTuringCanBuyOf > _amtCRO) {
            _croSend = _amtCRO;
            _croRefund = 0;
            _turingReceive = _croSend.mul(baseRatio).div(getPriceTuringToCRO());
            return(_croSend, _croRefund, _turingReceive);
        }
    }

    function getMaxNumberTuringOfUserOnBuy(address _user) public view returns(uint256 _maxTuring) {
        // get turing buy of user
        uint256 _turingSurplus = maxQuantityBuyTuringOfUser.sub(turingbuyedOf[_user]);

        if(_turingSurplus == 0) {
            _maxTuring = 0;
        }

        uint256 _quantityTuringCanBuy = maxQuantityBuyTuringOfUser <= totalTuringBuyLaunchpad ? maxQuantityBuyTuringOfUser : totalTuringBuyLaunchpad;

        _maxTuring = _turingSurplus <= _quantityTuringCanBuy ? _turingSurplus : _quantityTuringCanBuy;
    }

    /** ___________________________MATH______________________________
        *************************************************************
        *     x       x + a              x :  _amtCroLpContract     *
        *    ___ =  _________            y :  _amtTuringLpContract  *
        *     y       y + b              a :  _amtCroOnAddLp        *
        *                                b :  _amtTuringOnAddLp     *
        *              y * a                                        *
        *  => b  =   _________                                      *
        *                x                                          *
        *************************************************************
    */
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

    function getCroOnAddLp() public view returns(uint256 _CroOnAddLp) {
        uint256 _croBalance;
        _croBalance = getCroBalance();
        _CroOnAddLp = _croBalance.mul(ratioCroAddLp).div(baseRatio);       
    }

    function getCroDistributeOnFarms() public view returns(uint256 _CroDistributeOnFarms) {
        uint256 _croBalance;
        _croBalance = getCroBalance();
        _CroDistributeOnFarms = _croBalance.mul(baseRatio.sub(ratioCroAddLp)).div(baseRatio);
    }

    function getTotalRatioDistribute() public view returns(uint256) {
        uint256 _poolsLength = DistributeTuringContract.poolLength();
        uint256 _totalRatio = 0;
        for(uint256 _pid = 0; _pid < _poolsLength; _pid++){
            _totalRatio += ratioPidsOf[_pid];
        }
        return _totalRatio;
    }

    function getCroBalance() public view returns(uint256) {
        return address(this).balance;
    }
    /**
    data_[0] = uint256 croBalanceOfUSer;
    data_[1] = uint256 maxCroBuy;
    data_[2] = uint256 maxTuringReceive;
    data_[3] = uint256 croBalanceOfContract;
    data_[4] = uint256 croAddLp;
    data_[5] = uint256 croDistributeFarms;
    data_[6] = uint256 maxTuringSell;
    data_[7] = uint256 maxQuantityBuyTuringOfUser;

     */
    function getData(address _user) public view returns(uint256[8] memory data_) {
        data_[0] = _user.balance;
        // data_[1] = getMaxAmountcroSend(_user);
        data_[2] = maxQuantityBuyTuringOfUser.sub(turingbuyedOf[_user]);
        data_[3] = getCroBalance();
        data_[4] = getCroOnAddLp();
        data_[5] = getCroDistributeOnFarms();
        data_[6] = totalTuringBuyLaunchpad;
        data_[7] = maxQuantityBuyTuringOfUser;
    }

}