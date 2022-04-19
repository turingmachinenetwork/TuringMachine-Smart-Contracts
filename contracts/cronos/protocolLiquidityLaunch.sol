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
    IBEP20 public TURING_CRO_LP;

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
    uint256 public totalTuringBuyLaunchpad = 10000e18; // 10000 turing
    uint256 public baseRatio = 1e18;
    uint256 public ratioCroAddLp = 8e17; // 80%
    uint256 public requireClose = 200e18; // 80% turing selled

    bool public ENABLE = true;
    
    uint256 public maxQuantityBuyTuringOfUser = 100e18; // 100
    mapping(address => uint256) public turingbuyedOf;
    mapping(uint256 => uint256) public ratioPidsOf;     // 30% = 0,3e18 = 3e17 

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
        IBEP20 _TURING_CRO_LP,
        address _USDC,
        address _WCRO
    ) {
        TuringTimeLockContract = _TuringTimeLockContract;
        TuringWhitelistContract = _TuringWhiteListContract;
        VVSRouterContract = _VVSRouterContract;
        DistributeTuringContract = _DistributeTuringContract;
        TuirngCroLpContract = _TuirngCroLpContract;
        PriceOracleContract = _PriceOracleContract;

        TURING_CRO_LP = _TURING_CRO_LP;
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

    function transferOwnership(address _newOwner) public onlyOwner isQueued("transferOwnership") {
        owner = _newOwner;
    }

    function setTuringWhiteListContract(ITuringWhitelist _TuringWhiteListContract) public onlyOwner isQueued("setTuringWhiteListContract") {
        TuringWhitelistContract = _TuringWhiteListContract;
    }

    function setTuringTokenContract(IBEP20 _TURING) public onlyOwner isQueued("setTuringTokenContract") {
        require(address(TURING) != address(0), "INVALID_ADDRESS");
        TURING = _TURING;
    }

    function setTuringCroLpToken(IBEP20 _TURING_CRO_LP) public onlyOwner isQueued("setTuringCroLpToken") {
        TURING_CRO_LP = _TURING_CRO_LP;
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

    function setRequireClose(uint256 _requireClose) public onlyOwner isQueued("setRequireClose") {
        requireClose = _requireClose;
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
        ratioPidsOf[_pid] = _ratio;
    }

    function buy() public payable onlyWhitelisted {
        require(ENABLE == true, "SYSTEM_STOP");
        require(msg.value > 0, "INVALID_AMOUNT_1");
        uint256 croRefund;
        uint256 turingReceive;
        uint256 croPay;
        (croPay, croRefund, turingReceive) = getProcessAmt(msg.sender, msg.value);

        require(croPay.add(croRefund) <= msg.value, "INVALID_AMOUNT_2");
        if(turingReceive > 0) {
            TURING.transfer(msg.sender, turingReceive);

            totalTuringBuyLaunchpad = totalTuringBuyLaunchpad.sub(turingReceive);
            turingbuyedOf[msg.sender] = turingbuyedOf[msg.sender].add(turingReceive);
        }

        if(croRefund >  0) {
            bool sent = payable(msg.sender).send(croRefund);
            require(sent, "Failed to send Ether");
        }

        emit onBuy(msg.sender, croPay, croRefund, turingReceive);

    }

    function close() public onlyOwner {
        require(totalTuringBuyLaunchpad <= requireClose, "INVALID_CLOSE");
        require(ENABLE == true, "SYSTEM_STOP");
        ENABLE = false;
        uint256 _croBalance;
        _croBalance = getCroBalance();

        require(ratioCroAddLp > 0, "INVALID_RATIO_CRO_ON_ADD_LIQUIDITY_POOL");
        uint256 _amtCroOnAddLp = _croBalance.mul(ratioCroAddLp).div(baseRatio);
        uint256 _amtCroDistributeOnFarm = _croBalance.sub(_amtCroOnAddLp);

        _addLiquidity(_amtCroOnAddLp);
        _DistributeOnFarms(_amtCroDistributeOnFarm);
        _enableFarmTuring();

    }

    function emergencyWithdraw() public onlyOwner isQueued("emergencyWithdraw") {
        uint256 _turingCroLpBlc = TURING_CRO_LP.balanceOf(address(this));
        require(_turingCroLpBlc > 0, "NO ASSET");
        TURING_CRO_LP.transfer(owner, _turingCroLpBlc);
    }

    function burnLpToken() public onlyOwner {
        uint256 _turingCroLpBlc = TURING_CRO_LP.balanceOf(address(this));
        require(_turingCroLpBlc > 0, "NO ASSET");
        TURING_CRO_LP.transfer(address(0), _turingCroLpBlc);
    }

    function _enableFarmTuring() private {
        DistributeTuringContract.enableFarmTuring();
    }

    function _DistributeOnFarms(uint256 _amtCroDistributeOnFarm) private {
        uint256 totalPool = DistributeTuringContract.poolLength();
        uint256[] memory arrPid = new uint256[](totalPool);
        for(uint256 _pid = 0; _pid < totalPool; _pid++){
            arrPid[_pid] = ratioPidsOf[_pid];
        }
        DistributeTuringContract.processProtocolLiquidityLaunch{value: _amtCroDistributeOnFarm}(arrPid);
    }

    function _addLiquidity(uint256 _amtCroOnAddLp) private {
        uint112 _amtCroLpContract;
        uint112 _amtTuringLpContract;
        uint256 _amtTuringOnAddLp;

        (_amtCroLpContract, _amtTuringLpContract) = getReserves();
        _amtTuringOnAddLp = getEstimateTuringOnAddLp(_amtCroOnAddLp, _amtCroLpContract, _amtTuringLpContract);

        VVSRouterContract.addLiquidityETH{value: _amtCroOnAddLp}(address(TURING), _amtTuringOnAddLp, 1, 1, address(this), block.timestamp);
    }

        // 1 turing = ? cro 
    function getPriceTuringToCRO() public view returns(uint256) {
        uint256 _priceUsdcToCro = PriceOracleContract.priceOf(USDC);
        return priceTuringLaunchpad.mul(_priceUsdcToCro).div(baseRatio);
    }

    // function getProcessAmt(address _user, uint256 _amtCRO) public view returns(uint256 _croSend, uint256 _croRefund, uint256 _turingReceive) {
    //     if(turingbuyedOf[_user] == maxQuantityBuyTuringOfUser) {
    //         return(0, _amtCRO, 0);
    //     }
    //     uint256 _maxTuringCanBuyOf = getTurBuyMaxOf(_user);

    //     uint256 _convertInputCroOfUser = _amtCRO.mul(baseRatio).div(getPriceTuringToCRO());

    //     if(_maxTuringCanBuyOf <= _convertInputCroOfUser) {
    //         _croSend = _maxTuringCanBuyOf.mul(getPriceTuringToCRO()).div(baseRatio);
    //         _croRefund = _amtCRO.sub(_croSend);
    //         _turingReceive = _maxTuringCanBuyOf;
    //         return(_croSend, _croRefund, _turingReceive);
    //     }

    //     if(_maxTuringCanBuyOf > _convertInputCroOfUser) {
    //         _croSend = _amtCRO;
    //         _croRefund = 0;
    //         _turingReceive = _convertInputCroOfUser;
    //         return(_croSend, _croRefund, _turingReceive);
    //     }
    // }

    function getProcessAmt(address _user, uint256 _croSend) public view returns(uint256 _croPay, uint256 _croRefund, uint256 _uTurBuyAmt) {
        _croPay = _croSend;

        uint256 _maxBuy = getTurBuyMaxOf(_user);

        if(_maxBuy <= 0) {
            return(0, _croPay, 0);
        }

        uint256 _pTurToCRO = getPriceTuringToCRO();

        _uTurBuyAmt = _croPay.mul(baseRatio).div(_pTurToCRO);

        if(_uTurBuyAmt >= _maxBuy) {
            _uTurBuyAmt = _maxBuy;
            _croPay = _uTurBuyAmt.mul(_pTurToCRO).div(baseRatio);
            _croRefund = _croSend.sub(_croPay);
        }
        return (_croPay, _croRefund, _uTurBuyAmt);
    }

    function getTurBuyMaxOf(address _user) public view returns(uint256) {
        if (
            turingbuyedOf[_user] >= maxQuantityBuyTuringOfUser ||
            totalTuringBuyLaunchpad <= 0 ||
            ENABLE == false
            ) {
            return 0;
        }
        // user
        uint256 _maxBuy = maxQuantityBuyTuringOfUser.sub(turingbuyedOf[_user]);

        if (totalTuringBuyLaunchpad >= _maxBuy) {
            return _maxBuy;
        }
        return totalTuringBuyLaunchpad;
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

    function getCroBalance() public view returns(uint256) {
        return address(this).balance;
    }
    /**
    data_[0] = uint256 croBalanceOfUSer;
    data_[1] = uint256 maxTuringBuy;
    data_[2] =  uint256 maxCroBuy;
    data_[3] = uint256 croBalanceOfContract;
    data_[4] = uint256 croAddLp;
    data_[5] = uint256 croDistributeFarms;
    data_[6] = uint256 maxQuantityBuyTuringOfUser;
    data_[7] = uint256 totalTuringBuyLaunchpad;
    data_[8] = uint256 priceTuringLaunchpad;
    data_[9] = uint256 priceTuringToCRO;
     */
    function getData(address _user) public view returns(uint256[10] memory data_) {
        data_[0] = _user.balance;
        data_[1] = getTurBuyMaxOf(_user);
        data_[2] = data_[1].mul(getPriceTuringToCRO()).div(baseRatio);
        data_[3] = getCroBalance();
        data_[4] =  data_[3].mul(ratioCroAddLp).div(baseRatio);
        data_[5] =  data_[3].mul(baseRatio.sub(ratioCroAddLp)).div(baseRatio);
        data_[6] = maxQuantityBuyTuringOfUser;
        data_[7] = totalTuringBuyLaunchpad;
        data_[8] = priceTuringLaunchpad;
        data_[9] = getPriceTuringToCRO();
    }



}