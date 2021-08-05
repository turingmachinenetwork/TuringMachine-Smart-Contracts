// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './library/SafeMath.sol';
import './library/Ownable.sol';

import './interfaces/IBEP20.sol';
import './interfaces/IAlpacaVault.sol';
import './interfaces/ITuringProcessFeeForBNB.sol';
import './interfaces/IAlpacaFairLaunch.sol';
import './interfaces/IPancakeSwapRouter.sol';
import './interfaces/IMiningMachine.sol';
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

contract TuringAlpacaFarmBNB is Ownable {
  uint128 public version = 100;
  using SafeMath for uint256;
  IAlpacaVault public ibBNB; //
  IAlpacaFairLaunch public AlpacaFairLaunch;
  IPancakeSwapRouter public PancakeSwap;
  ITuringWhitelist public TuringWhitelist; 
  IMiningMachine public TuringMiningMachine;
  ITuringTimeLock public TuringTimeLock;
  ITuringProcessFeeForBNB public TuringProcessFeeForBNB;
  uint256 public pidOfVault;

  IBEP20 public ALPACA; 
  IBEP20 public want; 
  address public TURING;
  address public WBNB;
  address public BUSD;

  bool public isPaused = false;
  bool public isStopDepositToAlpaca = false;
  bool public isStopConvertBNBToIbBNB = false;

  mapping(address => uint256) public shareOf;
  uint256 public totalShare = 0;
  uint256 public totalSupply = 0;
  uint256 public timeOfUpdateTotalSupply = 0;
  uint256 public pidOfMining;
  uint256 public PERIOD_DAY = 1 days;
  uint256 public FARM_FEE = 500; // 500 / 10000 = 5%;
  modifier onlyWhitelist()
  {
    if (msg.sender != tx.origin) {
      require(TuringWhitelist.whitelisted(msg.sender) == true, 'INVALID_WHITELIST');
    }
    _;
  }

  modifier inNetworkEnable() {
    require(isPaused == false, 'NETWORK_PAUSED');
    _;
  }
  event onDeposit(address _user, uint256 _amount);
  event onWithdraw(address _user, uint256 _amount);
  constructor (
    ITuringTimeLock _turingTimeLock,
    IAlpacaVault _ibBNB,
    IAlpacaFairLaunch _alpacaFairLaunch,
    IPancakeSwapRouter _pancakeSwap,
    ITuringProcessFeeForBNB _turingProcessFeeForBNB,
    IBEP20 _alpacaToken,
    address _wbnb,
    address _busd,
    address _turing,
    uint256 _pidOfVault
  ) public {
      ibBNB = _ibBNB;
      TuringTimeLock = _turingTimeLock;
      AlpacaFairLaunch = _alpacaFairLaunch;
      PancakeSwap = _pancakeSwap;
      TuringProcessFeeForBNB = _turingProcessFeeForBNB;
      pidOfVault = _pidOfVault;

      ALPACA = _alpacaToken;
      TURING = _turing;
      want = IBEP20(_wbnb);
      WBNB = _wbnb;
      BUSD = _busd;
      // connectToAlpacaFarm
      _ibBNB.approve(address(_alpacaFairLaunch), uint256(-1));
      // connectToPancakeSwap
      ALPACA.approve(address(_pancakeSwap), uint256(-1));
  }
  receive() external payable {
        
  }
  function pausedNetwork() public onlyOwner {
    isPaused = true;
  }
  function enableNetwork() public onlyOwner {
    isPaused = false;
  }
  function openDepositToAlpaca() public onlyOwner {
    isStopDepositToAlpaca = false;
  }
  function stopDepositToAlpaca() public onlyOwner {
    isStopDepositToAlpaca = true;
  }
  function openConvertBNBToIbBNB() public onlyOwner {
    isStopConvertBNBToIbBNB = false;
  }
  function stopConvertBNBToIbBNB() public onlyOwner {
    isStopConvertBNBToIbBNB = true;
  }
  function setMiningMachine() public onlyOwner 
  {
    require(TuringTimeLock.isQueuedTransaction(address(this), 'setMiningMachine'), "INVALID_PERMISSION");

    address _miningMachine = TuringTimeLock.getAddressChangeOnTimeLock(address(this), 'setMiningMachine', 'miningMachine');

    require(_miningMachine != address(0), "INVALID_ADDRESS");

    TuringMiningMachine = IMiningMachine(_miningMachine);

    TuringTimeLock.clearFieldValue('setMiningMachine', 'miningMachine', 1);
    TuringTimeLock.doneTransactions('setMiningMachine');
  }
  function setTuringProcessFeeForBNB() public onlyOwner 
  {
    require(TuringTimeLock.isQueuedTransaction(address(this), 'setTuringProcessFeeForBNB'), "INVALID_PERMISSION");

    address _turingProcessFeeForBNB = TuringTimeLock.getAddressChangeOnTimeLock(address(this), 'setTuringProcessFeeForBNB', 'turingProcessFeeForBNB');

    require(_turingProcessFeeForBNB != address(0), "INVALID_ADDRESS");

    TuringProcessFeeForBNB = ITuringProcessFeeForBNB(_turingProcessFeeForBNB);

    TuringTimeLock.clearFieldValue('setTuringProcessFeeForBNB', 'turingProcessFeeForBNB', 1);
    TuringTimeLock.doneTransactions('setTuringProcessFeeForBNB');
  }
  function setPidOfMining() public onlyOwner 
  {
    require(TuringTimeLock.isQueuedTransaction(address(this), 'setPidOfMining'), "INVALID_PERMISSION");
    pidOfMining = TuringTimeLock.getUintChangeOnTimeLock(address(this), 'setPidOfMining', 'pidOfMining');
    TuringTimeLock.clearFieldValue('setPidOfMining', 'pidOfMining', 2);
    TuringTimeLock.doneTransactions('setPidOfMining');
  }
  function setWhitelistContract(ITuringWhitelist _whitelistContract) public onlyOwner {
    TuringWhitelist = _whitelistContract;
  }
  function connectToAlpacaAndPancake() public onlyOwner {
    ibBNB.approve(address(AlpacaFairLaunch), uint256(-1));
    ALPACA.approve(address(PancakeSwap), uint256(-1));
  }
  // Deposit Staking tokens to FairLaunchToken for ALPACA allocation.
  function deposit() external payable inNetworkEnable onlyWhitelist {
    require(msg.value > 0, "TUR_FARM:INVALID_AMOUNT");
    _turingHarvest(msg.sender);
    uint256 _fee = getFarmFee();
    _withdrawFromAlpaca();
    // Update share of user and total share of system
    uint256 _pool = getTotalBal().sub(msg.value, 'TUR_FARM:INVALID_POOl');
    uint256 _shares = 0;
    if (totalShare == 0) {
      _shares = msg.value;
    } else {
      _shares = (msg.value.mul(totalShare)).div(_pool); 
    }
    shareOf[msg.sender] = shareOf[msg.sender].add(_shares);
    totalShare = totalShare.add(_shares);
    _processFee(_fee); 
    _convertBNBToIbBNB();
    _depositToAlpaca();
    _updateTuringRewardDebtOf(msg.sender);
    onDeposit(msg.sender, msg.value);
  }
  // Withdraw Staking tokens from FairLaunchToken.
  function withdraw(uint256 _amount) external inNetworkEnable onlyWhitelist {
    require(_amount > 0, "TUR_FARM:INVALID_AMOUNT");
    _turingHarvest(msg.sender);
    uint256 _uBal = balanceOf(msg.sender);
    if (_amount > _uBal) {
      _amount = _uBal;
    }
    require(_amount > 0, "TUR_FARM:INVALID_USER_BAL");
    uint256 _fee = getFarmFee();
    _withdrawFromAlpaca();
    uint256 _avaiableBal = avaiableBal();
    if (_avaiableBal < _amount) {
        _amount = _avaiableBal;
    }
    require(_amount > 0, "TUR_FARM:INVALID_AVAIABLE_BAL");
    // Sub share of user 
    uint256 _pool = getTotalBal();
    uint256 _shares = _amount.mul(totalShare).div(_pool);
    if (_shares > shareOf[msg.sender]) {
      _shares = shareOf[msg.sender];
    }
    require(_shares > 0, "TUR_FARM:INVALID_SHARE");
    shareOf[msg.sender] = shareOf[msg.sender].sub(_shares);
    totalShare = totalShare.sub(_shares, 'TUR_FARM:INVALID_TOTAL_SHARE');
    // transfer BNB to user
    address(uint160(msg.sender)).transfer(_amount);
    _processFee(_fee);
    _convertBNBToIbBNB();
    _depositToAlpaca();
    _updateTuringRewardDebtOf(msg.sender);

    emit onWithdraw(msg.sender, _amount);
  }
  // Harvest ALPACAs earn from the pool.
  // function harvest(uint256 _pid) external;
  function harvest(address _user) external inNetworkEnable onlyWhitelist {
    uint256 _fee = getFarmFee();
    _turingHarvest(_user);
    _withdrawFromAlpaca();
    _processFee(_fee);
    _convertBNBToIbBNB();
    _depositToAlpaca();
  }
  function _turingHarvest(address _user) private 
  { 
    TuringMiningMachine.harvest(pidOfMining, _user);
  }
  function _updateTuringRewardDebtOf(address _user) private 
  {
    TuringMiningMachine.updateUser(pidOfMining, _user);
  }
  function _convertAlpacaToBNB() private {
    // Get ALPACA balance
    uint256 _alpacaBal = ALPACA.balanceOf(address(this));
    if (_alpacaBal > 0) {
      // Convert Alpaca to BNB
      address[] memory path = new address[](2);
      path[0] = address(ALPACA);
      path[1] = WBNB;
      PancakeSwap.swapExactTokensForETH(_alpacaBal, 0, path, address(this), block.timestamp);
    }
  }
  function _convertBNBToIbBNB() private {
    // Get BNB balance
    uint256 _bnbBal = avaiableBal();
    // Convert BNB to ibBNB
    if (isStopConvertBNBToIbBNB == false && _bnbBal > 0) {
      ibBNB.deposit{ value: _bnbBal }(_bnbBal);
    }
  }
  function _convertIbBNBToBNB() private {
    // Get ibBNB balance
    uint256 _ibBNBBal = ibBNB.balanceOf(address(this));
    // Convert ibBNB to BNB
    if (_ibBNBBal > 0) {
      ibBNB.withdraw(_ibBNBBal);
    }
  }
  function _processFee(uint256 _fee) private {
    uint256 _avaiableBal = avaiableBal();
    if (_fee > _avaiableBal) {
      _fee = _avaiableBal;
    }
    if (_fee > 0) {
      TuringProcessFeeForBNB.processFee{ value: _fee }();
    }
  }
  function _withdrawFromAlpaca() private {
    // get ibBNB on Alpaca
    (uint256 _ibBNBBalOnAlpaca, , ,) = AlpacaFairLaunch.userInfo(pidOfVault, address(this));
    if (_ibBNBBalOnAlpaca > 0) {
      AlpacaFairLaunch.withdrawAll(address(this), pidOfVault);
    }
    _convertIbBNBToBNB();
    _convertAlpacaToBNB();
  }
  function _depositToAlpaca() private {
    // Get ibBNB balance of contract
    uint256 _ibBNBBal = ibBNB.balanceOf(address(this));
    // Deposit ibBNB to Alpaca system
    if (isStopDepositToAlpaca == false && _ibBNBBal > 0) {
      AlpacaFairLaunch.deposit(address(this), pidOfVault, _ibBNBBal);
    }
    // update total supply
    totalSupply = getTotalBNBValueOfIbBNB();
    timeOfUpdateTotalSupply = block.timestamp;
  }

  function getTotalBal() public view returns(uint256) {
    uint256 _totalIbBNBValue  = getTotalBNBValueOfIbBNB();
    uint256 _totalAlpacaValue = getTotalBNBValueOfAlpaca();
    uint256 _supplyFee = 0;
    uint256 _alpacaFee = _totalAlpacaValue.mul(FARM_FEE).div(10000);
    if (_totalIbBNBValue > totalSupply) {
      _supplyFee = (_totalIbBNBValue.sub(totalSupply)).mul(FARM_FEE).div(10000);
    }
    return avaiableBal().add(_totalIbBNBValue).add(_totalAlpacaValue).sub(_alpacaFee).sub(_supplyFee);
  }
  function getFarmFee() public view returns(uint256) {
    uint256 _totalIbBNBValue  = getTotalBNBValueOfIbBNB();
    uint256 _totalAlpacaValue = getTotalBNBValueOfAlpaca();
    uint256 _supplyFee = 0;
    uint256 _alpacaFee = _totalAlpacaValue.mul(FARM_FEE).div(10000);
    if (_totalIbBNBValue > totalSupply) {
      _supplyFee = (_totalIbBNBValue.sub(totalSupply)).mul(FARM_FEE).div(10000);
    }
    return _supplyFee.add(_alpacaFee);
  }
  function avaiableBal() public view returns(uint256) {
    return address(this).balance;
  }
  function getTotalBNBValueOfIbBNB() public view returns(uint256) {
    uint256 _ibBNBBal = getTotalIbBNB();
    if (_ibBNBBal <= 0) {
      return 0;
    }
    // Convert ibBNB to BNB
    return _ibBNBBal.mul(ibBNB.totalToken()).div(ibBNB.totalSupply());
  }
  function getTotalBNBValueOfAlpaca() public view returns(uint256) {
    address[] memory path = new address[](2);
    path[0] = address(ALPACA);
    path[1] = WBNB;
    // Get ALPACA balance
    uint256 _alpacaBal = ALPACA.balanceOf(address(this));
    _alpacaBal = _alpacaBal.add(getPendingAlpaca());
    if (_alpacaBal <= 0) {
      return 0;
    }
    // Convert ALPACA to BNB
    uint256 _totalBNBValueOfAlpaca;
    try PancakeSwap.getAmountsOut(_alpacaBal, path) returns(uint[] memory amounts) {
      _totalBNBValueOfAlpaca = amounts[1];
    } catch {
      _totalBNBValueOfAlpaca = 0;   
    }
    return _totalBNBValueOfAlpaca;
  }
  function getTotalIbBNB() public view returns(uint256) {
    // get ibBNB on Alpaca
    (uint256 _ibBNBBalOnAlpaca, , ,) = AlpacaFairLaunch.userInfo(pidOfVault, address(this));
    return ibBNB.balanceOf(address(this)).add(_ibBNBBalOnAlpaca);
  }
  function getPendingAlpaca() public view returns(uint256) {
    return AlpacaFairLaunch.pendingAlpaca(pidOfVault, address(this));
  }
  function balanceOf(address _addr) public view returns(uint256) 
  {
    if (totalShare <= 0) {
      return 0;
    }
    return (getTotalBal().mul(shareOf[_addr])).div(totalShare);
  }

  function getData(
    address _user
  ) 
  public 
  view
  returns(
    uint256 bnbPrice_,
    uint256 totalMintPerDay_, 
    uint256 userTuringPending_, 
    uint256 userBNBBal_, 
    uint256 userBNBShare_, 
    uint256 turingAPY_,
    uint256 alpacaAPY_,
    uint256 supplyAPY_,
    uint256 totalShare_,
    uint256 tvl_
  ) {
      bnbPrice_ = getBNBPrice();
      totalMintPerDay_ = TuringMiningMachine.getTotalMintPerDayOf(pidOfMining);
      (userTuringPending_, , ) = TuringMiningMachine.getUserInfo(pidOfMining, _user);
      userBNBBal_ = address(_user).balance;
      userBNBShare_ = balanceOf(_user);
      totalShare_ = getTotalBal();
      tvl_ = totalShare_.mul(bnbPrice_).div(1e18);
        
      turingAPY_ = getTuringApy();
      alpacaAPY_ = getAlpacaApy();
      supplyAPY_ = getSupplyApy();
  } 
  function getTuringApy() public view returns(uint256) {
    uint256 _bnbPrice = getBNBPrice();
    uint256 _totalSupplyValue = totalSupply.mul(_bnbPrice).div(1e18);
    if (_totalSupplyValue <= 0) {
      _totalSupplyValue = avaiableBal();
    }
    if (_totalSupplyValue <= 0) {
      return 0;
    }

    uint256 _totalMintPerDay = TuringMiningMachine.getTotalMintPerDayOf(pidOfMining);
    uint256 _turingPrice = getTuringPrice();
    uint256 _turingRewardPerDayValue = _totalMintPerDay.mul(_turingPrice).div(1e18);
    return _turingRewardPerDayValue.mul(365).mul(10000).div(_totalSupplyValue);
  }
  function getSupplyApy() public view returns(uint256) {
    if (totalSupply <= 0) {
      return 0;
    }
    if (timeOfUpdateTotalSupply <=0) { 
      return 0;
    }
    uint256 _totalBNBBal = getTotalBNBValueOfIbBNB();
    if (_totalBNBBal <= totalSupply) {
      return 0;
    }
    uint256 _reward = _totalBNBBal.sub(totalSupply);
    // sub fee
    _reward = _reward.sub(_reward.mul(FARM_FEE).div(10000));
    return _reward.mul(PERIOD_DAY).mul(365).mul(1e12).div(block.timestamp.sub(timeOfUpdateTotalSupply)).div(totalSupply);
  }
  function getAlpacaApy() public view returns(uint256) {
    if (totalSupply <= 0) {
      return 0;
    }
    if (timeOfUpdateTotalSupply <=0) { 
      return 0;
    }
    uint256 _bnbPrice = getBNBPrice();
    uint256 _totalSupplyValue = totalSupply.mul(_bnbPrice).div(1e18);
    uint256 _pendingAlpaca = getPendingAlpaca();
    uint256 _alpacaPrice   = getAlpacaPrice();
    uint256 _pendingAlpacaValue = _pendingAlpaca.mul(_alpacaPrice).div(1e18);
    // sub fee
    _pendingAlpacaValue = _pendingAlpacaValue.sub(_pendingAlpacaValue.mul(FARM_FEE).div(10000));
    return _pendingAlpacaValue.mul(PERIOD_DAY).mul(365).mul(1e12).div(block.timestamp.sub(timeOfUpdateTotalSupply)).div(_totalSupplyValue);
  }
  function getBNBPrice() public view returns(uint256) {
    address[] memory path = new address[](2);
    path[0] = WBNB;
    path[1] = BUSD;
    uint256 _price;
    try PancakeSwap.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
      _price = amounts[1];
    } catch {
      _price = 0;   
    }
    return _price;
  }

  function getTuringPrice() public view returns(uint256) {
    address[] memory path = new address[](3);
    path[0] = TURING;
    path[1] = WBNB;
    path[2] = BUSD;
    uint256 _price;
    try PancakeSwap.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
      _price = amounts[2];
    } catch {
      _price = 0;   
    }
    return _price;
  }
  function getAlpacaPrice() public view returns(uint256) {
    address[] memory path = new address[](3);
    path[0] = address(ALPACA);
    path[1] = WBNB;
    path[2] = BUSD;
    uint256 _price;
    try PancakeSwap.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
      _price = amounts[2];
    } catch {
      _price = 0;   
    }
    return _price;
  }
}