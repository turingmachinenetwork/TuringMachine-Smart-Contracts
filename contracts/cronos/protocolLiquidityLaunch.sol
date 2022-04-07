// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './library/SafeMath.sol';
import './interfaces/ITuringWhiteList.sol';
import './interfaces/ITuringTimeLock.sol';
import './interfaces/IBEP20.sol';
import './interfaces/IVVSRouter.sol';
import './interfaces/IDistributeTuring.sol';
import './interfaces/ITuringCroLpContract.sol';

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

    address public WCRO;
    address public USDC;

    uint256 private MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    uint256 public priceTuringLaunchpad = 1e16; // $0,01
    uint256 public totalTuringBuyLaunchpad = 1000e18; // 10000 turing
    uint256 public priceTuringToCRO;
    uint256 public baseRatio = 1e18;
    uint256 public ratioCroAddLp = 8e17; // 80%

    bool public ENABLE = true;
    uint256 public minimumRateToClose = 8e17; // 80% Turing are sell
    
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
        IBEP20 _TURING,
        address _USDC,
        address _WCRO
    ) {
        TuringTimeLockContract = _TuringTimeLockContract;
        TuringWhitelistContract = _TuringWhiteListContract;
        VVSRouterContract = _VVSRouterContract;
        DistributeTuringContract = _DistributeTuringContract;
        TuirngCroLpContract = _TuirngCroLpContract;

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


    function setPriceTuringLaunchpad(uint256 _priceTuringLaunchpad) public onlyOwner isQueued("setPriceTuringLaunchpad") {
        priceTuringLaunchpad = _priceTuringLaunchpad;
    }

    function setTotalTuringBuyLaunchpad(uint256 _totalTuringBuyLaunchpad) public onlyOwner isQueued("setTotalTuringBuyLaunchpad") {
        totalTuringBuyLaunchpad = _totalTuringBuyLaunchpad;
    }

    function setMaxQuantityBuyTuringOfUser(uint256 _maxQuantityBuyTuringOfUser) public onlyOwner isQueued("setMaxQuantityBuyTuringOfUser") {
        maxQuantityBuyTuringOfUser = _maxQuantityBuyTuringOfUser;
    }

    function setPriceTuringToCRO() public onlyWhitelisted {
        uint256 _priceCRO;
        _priceCRO = getPriceCroToUsdc();
        priceTuringToCRO = _priceCRO.mul(baseRatio).div(priceTuringLaunchpad);
    }

    /**
    exemple : 
        if set pool 0 with 20% cro on distribute:
        _pid: 0;
        _ratio: (20/100) * 1e18 = 2e17;
     */
    function setRatioPidsOf(uint256 _pid, uint256 _ratio) 
    public
    onlyOwner
    isQueued("setRatioPidsOf") {
        uint256 _poolsLength = DistributeTuringContract.poolLength();
        require(_pid < _poolsLength, "INVALID_PID");
        uint256 _totalRatio;
        _totalRatio = getTotalRatioDistribute();
        require(_totalRatio.add(_ratio) <= baseRatio, "INVALID_RATIO");
        ratioPidsOf[_pid] = _ratio;
    }

    function buy() 
    public 
    payable 
    onlyWhitelisted 
    {
        require(ENABLE == true, "SYSTEM_STOP");
        require(msg.value > 0, "INVALID_AMOUNT_1");
        uint256 croRefund;
        uint256 turingReceive;
        uint256 croSend;
        (croSend, croRefund, turingReceive) = getProcessAmt(msg.sender, msg.value);

        require(croSend.add(croRefund) <= msg.value, "INVALID_AMOUNT_2");

        TURING.transfer(msg.sender, turingReceive);

        totalTuringBuyLaunchpad -= turingReceive;
        turingbuyedOf[msg.sender] += turingReceive;

        if(croRefund >  0) {
            _transfer(payable(msg.sender) , croRefund);
        }

        emit onBuy(msg.sender, croSend, croRefund, turingReceive);

    }

    function _transfer(address payable _to, uint256 _amt) private {
        bool sent = _to.send(_amt);
        require(sent, "Failed to send Ether");
    }

    function close() public onlyWhitelisted  onlyOwner {
        uint256 _croBalance;
        _croBalance = getCroBalance();

        require(ratioCroAddLp > 0, "INVALID_RATIO_CRO_ON_ADD_LIQUIDITY_POOL");
        uint256 _amtCroOnAddLp = _croBalance.mul(ratioCroAddLp).div(baseRatio);
        uint256 _amtCroDistributeOnFarm = _croBalance.sub(_amtCroOnAddLp);

        _addLiquidity(_amtCroOnAddLp);
        _DistributeOnFarms(_amtCroDistributeOnFarm);

        ENABLE = false;

    }

    function _addLiquidity(uint256 _amtCroOnAddLp) private {
        uint112 _amtCROLpContract;
        uint112 _amtTuringLpContract;
        uint256 _amtTuringOnAddLp;

        (_amtCROLpContract, _amtTuringLpContract) = getReserves();
        _amtTuringOnAddLp = getEstimateTuringOnAddLp(_amtCROLpContract, _amtTuringLpContract);

        VVSRouterContract.addLiquidityETH{value: _amtCroOnAddLp}(address(TURING), _amtTuringOnAddLp, 1, 1, msg.sender, block.timestamp);

    }

    function _DistributeOnFarms(uint256 _amtCroDistributeOnFarm) private {

        for(uint256 _pid = 0; _pid < DistributeTuringContract.poolLength(); _pid++){
            arrPid.push(ratioPidsOf[_pid]);
        }
        DistributeTuringContract.processProtocolLiquidityLaunch{value: _amtCroDistributeOnFarm}(arrPid);
    }

    function getProcessAmt(address _user, uint256 _amtCRO) public view returns(uint256 _croSend, uint256 _croRefund, uint256 _turingReceive) {
        uint256 _maxcroSend;
        _maxcroSend = getMaxAmountcroSend(_user);

        if(_maxcroSend == 0) {
            _croRefund = _amtCRO;
            _turingReceive = 0;
        }
        if(_amtCRO > _maxcroSend) {
            _croRefund = _amtCRO.sub(_maxcroSend);
            _croSend = _maxcroSend;
        } else {
            _croSend = _amtCRO;
        }
        _turingReceive = _croSend.mul(priceTuringToCRO).div(baseRatio);

    }

    function getMaxAmountcroSend(address _user) public view returns(uint256 _maxCroSend) {
        // check quantity tuirng system
        uint256 _maxQuantityBuyTuringOfUser;
        _maxQuantityBuyTuringOfUser = maxQuantityBuyTuringOfUser <= totalTuringBuyLaunchpad ? maxQuantityBuyTuringOfUser : totalTuringBuyLaunchpad;

        // get turing buy of user
        uint256 _turingSurplus;
        _turingSurplus =  maxQuantityBuyTuringOfUser.sub(turingbuyedOf[_user]) <= _maxQuantityBuyTuringOfUser ? maxQuantityBuyTuringOfUser.sub(turingbuyedOf[_user]) : _maxQuantityBuyTuringOfUser;
        if(_turingSurplus == 0) {
            _maxCroSend = 0;
        }
        uint256 _minTuringBuy = priceTuringToCRO.div(baseRatio);
        if(_turingSurplus < _minTuringBuy) {
            _maxCroSend = 0;
        }
        _maxCroSend = _turingSurplus.mul(baseRatio).div(priceTuringToCRO);

    }

    function getPriceCroToUsdc() public view returns (uint256) {
        address[] memory path = new address[](2);

        path[0] = WCRO;
        path[1] = USDC;
        uint256 _price;
        try VVSRouterContract.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
            _price = amounts[1];
        } catch {
            _price = 0;
        }
        return _price;
    }

                    /** ___________________________MATH______________________________
                        *************************************************************
                        *     x       x + a              x :  _amtCROLpContract     *
                        *    ___ =  _________            y :  _amtTuringLpContract  *
                        *     y       y + b              a :  _amtCroOnAddLp        *
                        *                                b :  _amtTuringOnAddLp     *
                        *              y * a                                        *
                        *  => b  =   _________                                      *
                        *                x                                          *
                        *************************************************************
                    */
    function getEstimateTuringOnAddLp(uint256 _amtCROLpContract, uint256 _amtTuringLpContract) public view returns(uint256 _amtTuringOnAddLp) {
        uint256 _amtCroOnAddLp;
        _amtCroOnAddLp= getCroOnAddLp();
        _amtTuringOnAddLp = _amtTuringLpContract.mul(_amtCroOnAddLp).div(_amtCROLpContract);
    }

    function getReserves() public view returns(uint112 _amtCROLpContract, uint112 _amtTuringLpContract) {
        // (_amtCROLpContract, _amtTuringLpContract,) = TuirngCroLpContract.getReserves(); //  cro mainnet 
        (_amtTuringLpContract, _amtCROLpContract,) = TuirngCroLpContract.getReserves();
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

    // withdraw cro testnet, DELETE on release mainnet
    function withdraw() public onlyOwner{
        // get the amount of Ether stored in this contract
        uint amount = address(this).balance;

        (bool success, ) = owner.call{value: amount}("");
        require(success, "Failed to send Ether");
    }

}