// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IMiningMachine.sol';
import './interfaces/IPancakeSwapRouter.sol';
import './interfaces/IBEP20.sol';
import './library/SafeMath.sol';
import './library/ReentrancyGuard.sol';

contract TuringFarmTuring is ReentrancyGuard {

    using SafeMath for uint256;
    uint256 public version = 100;
    address public owner;
    
    IBEP20 public want; // TUR
    address public wbnb;
    address public busd;

    IMiningMachine public miningMachine;
    IPancakeSwapRouter public pancakeSwap;

    uint256 public totalShare = 0;

    mapping(address => uint256) public shareOf;

    modifier onlyOwner()
    {
        require(msg.sender == owner, 'INVALID_PERMISSION');
        _;
    }

    event onDeposit(address _user, uint256 _amount);
    event onWithdraw(address _user, uint256 _amount);
    event onEmergencyWithdraw(address _user, uint256 _amount);

    constructor(
        IPancakeSwapRouter _pancakeSwap,
        IBEP20 _tur,
        address _wbnb,
        address _busd
        ) public {
        owner = msg.sender;
        pancakeSwap = _pancakeSwap;
        want = _tur;
        wbnb = _wbnb;
        busd = _busd;
    }

    receive() external payable {
        
    }

    function setMiningMachine(IMiningMachine _addr) public onlyOwner {
        miningMachine = _addr;
    }

    function transferOwnership(address _owner) public onlyOwner {
        require(_owner != address(0), "INVALID_ADDRESS");
        owner = _owner;
    }

    function deposit(uint256 _wantAmt) external nonReentrant {

        require(_wantAmt > 0, 'INVALID_INPUT');
        require(want.balanceOf(msg.sender) >= _wantAmt, 'INVALID_INPUT');

        harvest(msg.sender);

    	want.transferFrom(msg.sender, address(this), _wantAmt);

        shareOf[msg.sender] = shareOf[msg.sender].add(_wantAmt);

        totalShare = totalShare.add(_wantAmt);

        emit onDeposit(msg.sender, _wantAmt);

    }
    function withdraw(uint256 _wantAmt) external nonReentrant {

        require(_wantAmt > 0, 'INVALID_INPUT');
        
        harvest(msg.sender);

        uint256 _share = shareOf[msg.sender];

        require(_share >= _wantAmt, 'INVALID_AMOUNT_WITHDRAW');

        shareOf[msg.sender] = shareOf[msg.sender].sub(_wantAmt);
        totalShare = totalShare.sub(_wantAmt);

        uint256 _wantBal = want.balanceOf(address(this)); 

        if (_wantBal < _wantAmt) {
            _wantAmt = _wantBal;
        }

        want.transfer(msg.sender, _wantAmt);
    	// 
        emit onWithdraw(msg.sender, _wantAmt);
    }
    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {

        uint256 _share = shareOf[msg.sender];

        require(_share > 0, 'INVALID_AMOUNT');

        shareOf[msg.sender] = 0;

        totalShare = totalShare.sub(_share);

        uint256 _wantBal = want.balanceOf(address(this));

        if (_wantBal < _share) {
            _share = _wantBal;
        }

        want.transfer(msg.sender, _share);

        emit onEmergencyWithdraw(msg.sender, _share);
    }

    function harvest(address _user) public returns(uint256 _pendingTur, uint256 _bonus) { 
        return miningMachine.harvest(0, _user);
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
        uint256 userBNBBal_, 
        uint256 userTuringPending_, 
        uint256 userTuringShare_, 
        uint256 turingRewardAPY_,
        uint256 tvl_
    ) {
        turingPrice_ = getTuringPrice();
        totalMintPerDay_ = miningMachine.getTotalMintPerDayOf(0);

        miningSpeed_ = miningMachine.getMiningSpeedOf(0);
        userBNBBal_ = address(_user).balance;
        (userTuringPending_, , ) = miningMachine.getUserInfo(0, _user);
        userTuringBal_ = want.balanceOf(_user);
        userTuringShare_ = shareOf[_user];
        tvl_ = totalShare;

        if (tvl_ > 0) {
            turingRewardAPY_ = totalMintPerDay_.mul(365).mul(10000).div(tvl_);
        }
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