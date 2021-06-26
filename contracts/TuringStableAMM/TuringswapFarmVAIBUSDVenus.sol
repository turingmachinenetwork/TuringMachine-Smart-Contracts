// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './library/SafeMath.sol';
import './interfaces/IBEP20.sol';
import './interfaces/IPancakeSwapRouter.sol';
import './interfaces/IVenusDistribution.sol';
import './interfaces/ITuringTimeLock.sol';
import './interfaces/IVToken.sol';
import './interfaces/IVAIVault.sol';
import './library/Ownable.sol';

contract TuringswapFarmVAIBUSDVenus is Ownable {
    
    using SafeMath for uint256;
    
    IVToken public vBase; // vBUSD
    IVAIVault public VAIVaultContract; // vaivault
    IVenusDistribution public venusDistributionContract;
    IPancakeSwapRouter public pancakeSwapRouterContract;
    ITuringTimeLock public turingTimeLockContract;

    IBEP20 public base; // Stable coin base token (BUSD, BTCB)
    IBEP20 public token; // VAI
    IBEP20 public XVS; // 
    address public WBNB; // 

    address public turingswapTrade;

    uint256 public totalBaseSupplyToVenus = 0;
    uint256 public totalTokenSupplyToVenus = 0;
    uint256 public timeOfSupplyToVenus = 0;

    uint256 public timeOfHarvest;
    uint256 public lasttimeOfHarvest;
    uint256 public xvsRewardAmt;
    uint256 public PERIOD_DAY = 1 days;

    address public performanceMachine; // the contract will use fee to Buy tUR on pankace swap , then burn the turs token
    address public controllerMachine;

    uint256 public rateOfPerformanceFee = 50; //0.5 % on profit.
    uint256 public rateOfControllerFee = 1; // 0.01 % on profit

    modifier onlyOwnerOrSwapTradeContract()
    {
        require(msg.sender == owner() || msg.sender == turingswapTrade, 'INVALID_PERMISSION');
        _;
    }

    event onSupply(uint256 _amountBase, uint256 _amountToken);
    event onWithdrawAll(uint256 _amountBase, uint256 _amountToken);
    event onClaimOtherToken(address _tokenAddr, uint256 _amountToken);

    constructor(
        IBEP20 _base,
        IBEP20 _token,
        IBEP20 _xvs,
        address _wbnb,
        IVToken _vBase,
        IVAIVault _VAIVaultContract,
        ITuringTimeLock _turingTimeLockContract,
        IVenusDistribution _venusDistribution,
        IPancakeSwapRouter _pancakeSwapRouter
        ) public {
        WBNB = _wbnb;
        XVS = _xvs;
        base = _base;
        token = _token;
        vBase = _vBase;
        VAIVaultContract = _VAIVaultContract;

        turingTimeLockContract = _turingTimeLockContract;
        venusDistributionContract = _venusDistribution;
        pancakeSwapRouterContract = _pancakeSwapRouter;
    }

    function getReserve() public view returns (uint256, uint256) {
        uint256 baseReserve = base.balanceOf(address(this));
        uint256 tokenReserve = token.balanceOf(address(this));
        baseReserve = baseReserve.add(totalBaseSupplyToVenus);
        tokenReserve = tokenReserve.add(totalTokenSupplyToVenus);
        return (baseReserve, tokenReserve);
    }
    
    function setTuringswapTradecontract() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setTuringswapTradecontract'), "INVALID_PERMISSION");

        address _turingswapTrade = turingTimeLockContract.getAddressChangeOnTimeLock(address(this), 'setTuringswapTradecontract', 'turingswapTrade');

        require(_turingswapTrade != address(0), "INVALID_ADDRESS");

        turingswapTrade = _turingswapTrade;

        turingTimeLockContract.clearFieldValue('setTuringswapTradecontract', 'turingswapTrade', 1);
        turingTimeLockContract.doneTransactions('setTuringswapTradecontract');
    }

    function setPerformanceMachine() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setPerformanceMachine'), "INVALID_PERMISSION");

        address _performanceMachine = turingTimeLockContract.getAddressChangeOnTimeLock(address(this), 'setPerformanceMachine', 'performanceMachine');

        require(_performanceMachine != address(0), "INVALID_ADDRESS");

        performanceMachine = _performanceMachine;

        turingTimeLockContract.clearFieldValue('setPerformanceMachine', 'performanceMachine', 1);
        turingTimeLockContract.doneTransactions('setPerformanceMachine');
    }

    function setControllerFee() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setControllerFee'), "INVALID_PERMISSION");

        address _controllerMachine = turingTimeLockContract.getAddressChangeOnTimeLock(address(this), 'setControllerFee', 'controllerMachine');

        require(_controllerMachine != address(0), "INVALID_ADDRESS");

        controllerMachine = _controllerMachine;

        turingTimeLockContract.clearFieldValue('setControllerFee', 'controllerMachine', 1);
        turingTimeLockContract.doneTransactions('setControllerFee');
    }

    function setRate() public onlyOwner {

        require(turingTimeLockContract.isQueuedTransaction(address(this), 'setRate'), "INVALID_PERMISSION");

        uint256 _rateOfControllerFee = turingTimeLockContract.getUintChangeOnTimeLock(address(this), 'setRate', 'rateOfControllerFee');
        uint256 _rateOfPerformanceFee = turingTimeLockContract.getUintChangeOnTimeLock(address(this), 'setRate', 'rateOfPerformanceFee');

        rateOfControllerFee = _rateOfControllerFee;
        rateOfPerformanceFee = _rateOfPerformanceFee;

        turingTimeLockContract.clearFieldValue('setRate', 'rateOfControllerFee', 2);
        turingTimeLockContract.clearFieldValue('setRate', 'rateOfPerformanceFee', 2);

        turingTimeLockContract.doneTransactions('setRate');
    }

    function connectToVenus() public onlyOwner {
        base.approve(address(vBase), uint256(-1));
        token.approve(address(VAIVaultContract), uint256(-1));
    }

    function connectToPancake() public onlyOwner {
        XVS.approve(address(pancakeSwapRouterContract), uint256(-1));
    }
    function claimOtherToken(address tokenAddress, uint tokenAmount) external onlyOwner {

        require(tokenAddress != address(0), 'INVALID: ADDRESS');
        require(tokenAddress != address(base), 'INVALID: cannot recover base');
        require(tokenAddress != address(token), 'INVALID: cannot recover token');
        require(tokenAddress != address(vBase), 'INVALID: cannot recover vBase');
        require(tokenAddress != address(VAIVaultContract), 'INVALID: cannot recover VAIVaultContract');
        require(tokenAddress != address(XVS), 'INVALID: cannot recover XVS');

        IBEP20(tokenAddress).transfer(performanceMachine, tokenAmount);

        emit onClaimOtherToken(tokenAddress, tokenAmount);
    }
    function supply() public onlyOwnerOrSwapTradeContract {

        require(address(vBase) != address(0), "INVALID_VBASE");
        require(address(VAIVaultContract) != address(0), "INVALID_VAIVaultContract");

        uint256 baseReserve = base.balanceOf(address(this));
        uint256 tokenReserve = token.balanceOf(address(this));

        if (baseReserve > 0) {
            vBase.mint(baseReserve);
            totalBaseSupplyToVenus = totalBaseSupplyToVenus.add(baseReserve);
        }

        if (tokenReserve > 0) {
            VAIVaultContract.deposit(tokenReserve);
            totalTokenSupplyToVenus = totalTokenSupplyToVenus.add(tokenReserve);
        }

        timeOfSupplyToVenus = block.timestamp;

        emit onSupply(baseReserve, tokenReserve);
    }
    function withdrawAll() public onlyOwnerOrSwapTradeContract {
        _withdrawAll();
    }

    function harvest() public onlyOwnerOrSwapTradeContract returns(uint256) {
        address[] memory vTokens = new address[](1);
        vTokens[0] = address(vBase);
        venusDistributionContract.claimVenus(address(this), vTokens);

        VAIVaultContract.claim();
        // convert XVS To Base Token
        uint256 xvsBal = XVS.balanceOf(address(this));
        if (xvsBal <= 0) {
            return 0;
        }
        address[] memory path = new address[](3);
        path[0] = address(XVS);
        path[1] = WBNB;
        path[2] = address(base);

        uint256 baseBalBefore = base.balanceOf(address(this));

        pancakeSwapRouterContract.swapExactTokensForTokens(xvsBal, 0, path, address(this), block.timestamp);

        uint256 baseBalAfter = base.balanceOf(address(this));
        // update info
        lasttimeOfHarvest = timeOfHarvest <= 0 ? timeOfSupplyToVenus : timeOfHarvest;
        timeOfHarvest = block.timestamp;
        uint256 baseReward = baseBalAfter > baseBalBefore ? baseBalAfter.sub(baseBalBefore) : 0;

        uint256 performanceFee = baseReward.mul(rateOfPerformanceFee).div(10000);
        uint256 controllerFee  = baseReward.mul(rateOfControllerFee).div(10000);

        if (performanceFee > 0) {
            base.transfer(performanceMachine, performanceFee);
        }
        if (controllerFee > 0) {
            base.transfer(controllerMachine, controllerFee);
        }
        xvsRewardAmt = baseReward.sub(performanceFee).sub(controllerFee);
    }

    function _withdrawAll() private {
        require(address(vBase) != address(0), "INVALID_VBASE");
        require(address(VAIVaultContract) != address(0), "INVALID_VAIVaultContract");
        
        uint256 vBaseBal = vBase.balanceOf(address(this));
        (uint256 vaiBal, ) = VAIVaultContract.userInfo(address(this));
        if (vBaseBal > 0) {
            vBase.redeem(vBaseBal);
            totalBaseSupplyToVenus = 0;
        }
        if (vaiBal > 0) {
            VAIVaultContract.withdraw(vaiBal);
            totalTokenSupplyToVenus = 0;
        }
        emit onWithdrawAll(vBaseBal, vaiBal);
    }

    function moveOutBaseToTradeContract(uint256 _amountBase) public onlyOwnerOrSwapTradeContract {
        require(_amountBase > 0, "INVALID_AMOUNT_BASE");
        require(_amountBase <= base.balanceOf(address(this)));
        require(turingswapTrade != address(0), "INVALID_TRADE_ADDRESS");
        base.transfer(turingswapTrade, _amountBase);
    }

    function moveOutTokenToTradeContract(uint256 _amountToken) public onlyOwnerOrSwapTradeContract {
        require(_amountToken > 0, "INVALID_AMOUNT_BASE");
        require(_amountToken <= token.balanceOf(address(this)));
        require(turingswapTrade != address(0), "INVALID_TRADE_ADDRESS");
        token.transfer(turingswapTrade, _amountToken);
    }

    function releaseFundToTradeContract() public onlyOwnerOrSwapTradeContract {
        require(turingswapTrade != address(0), "INVALID_TRADE_ADDRESS");
        _withdrawAll();
        uint256 baseReserve = base.balanceOf(address(this));
        uint256 tokenReserve = token.balanceOf(address(this));

        if (baseReserve > 0) {
            base.transfer(turingswapTrade, baseReserve);
        }
        if (tokenReserve > 0) {
            token.transfer(turingswapTrade, tokenReserve);
        }   
    }

    function getXVSApy() public view returns(uint256) {
        uint256 totalSupply = IBEP20(turingswapTrade).totalSupply();
        if (totalSupply <= 0) {
            return 0;
        }
        if (timeOfHarvest <=0) { 
            return 0;
        }
        if (lasttimeOfHarvest <=0) { 
            return 0;
        }
        if (timeOfHarvest <= lasttimeOfHarvest) {
            return 0;
        }
        // PERIOD_DAY
        // daily = (xvsRewardAmt / (timeOfHarvest - lasttimeOfHarvest))/ totalSupply
        // => APY = daily * 365
        // => APY =  365 * (xvsRewardAmt / (timeOfHarvest - lasttimeOfHarvest))/ totalSupply
        return xvsRewardAmt.mul(PERIOD_DAY).mul(365).mul(1e12).div(timeOfHarvest.sub(lasttimeOfHarvest)).div(totalSupply.mul(2));
    }
    function getSupplyApy() public view returns(uint256) {
        uint256 baseBalOnVenus  = 0;
        (, uint256 vBaseBal, ,uint256 exchangeRateMantissaOfVBase) = vBase.getAccountSnapshot(address(this));
        baseBalOnVenus = vBaseBal.mul(exchangeRateMantissaOfVBase).div(1e18);
        uint256 totalBalOnVenus = baseBalOnVenus;
        if (totalBalOnVenus <= totalBaseSupplyToVenus) {
            return 0;
        }
        if (block.timestamp <= timeOfSupplyToVenus) {
            return 0;
        }
        uint256 totalSupply = IBEP20(turingswapTrade).totalSupply();
        uint256 supplyRewardAmt = totalBalOnVenus.sub(totalBaseSupplyToVenus);
        return supplyRewardAmt.mul(PERIOD_DAY).mul(365).mul(1e12).div(block.timestamp.sub(timeOfSupplyToVenus)).div(totalSupply.mul(2));
    }
}