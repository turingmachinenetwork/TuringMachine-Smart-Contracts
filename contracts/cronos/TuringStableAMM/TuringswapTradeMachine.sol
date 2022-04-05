// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IBEP20.sol';
import './interfaces/ITuringswapTradePair.sol';
import './interfaces/ITuringswapWhitelist.sol';
import './library/SafeMath.sol';

contract TuringswapTradeMachine {
    
    using SafeMath for uint256;
    
    address public owner;
    mapping (address => bool) public pairs;

    ITuringswapWhitelist public whitelistContract; 

    IBEP20 public TUR; // TUR
    
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
    event onDistributeTuring(address _trader, uint256 _amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor(
        IBEP20 _tur,
        ITuringswapWhitelist _whitelistContract
        ) public {
         owner = msg.sender;
         TUR = _tur;
         whitelistContract = _whitelistContract;
    }
    function setWhitelistContract(ITuringswapWhitelist _whitelistContract) public onlyOwner {
        whitelistContract = _whitelistContract;
    }
    /**
    * @dev Transfers ownership of the contract to a new account (`newOwner`).
    * Can only be called by the current owner.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    function approveWithPair(IBEP20 token, ITuringswapTradePair pair) public onlyOwner{
        token.approve(address(pair), uint256(-1));
    }

    function getTokenOutput(uint256 token1InputAmount, ITuringswapTradePair token1Pair, ITuringswapTradePair token2Pair) public view returns (uint256) {
        //get token1 to base
        uint256 baseAmount = token1Pair.getBaseOutput(token1InputAmount);
        //get base to token2
        uint256 token2OutputAmount = token2Pair.getTokenOutput(baseAmount);
        return token2OutputAmount;
    }
    
    function addPair(address _pair) public onlyOwner {
        require(pairs[_pair] != true, "IN_THE_LIST");
        pairs[_pair] = true;
    }

    function removePair(address _pair) public onlyOwner {
        require(pairs[_pair] == true, "NOT_IN_THE_LIST");
        pairs[_pair] = false;
    }

    function swapTokenToTokenWithTokenInput(uint256 token1InputAmount, uint256 minToken2Output, ITuringswapTradePair token1Pair, ITuringswapTradePair token2Pair, uint256 deadline) public onlyWhitelist {
        require(token1Pair != token2Pair, 'SAME_PAIR');
        require(pairs[address(token1Pair)] == true, "PAIR1_NOT_CORRECT");
        require(pairs[address(token2Pair)] == true, "PAIR2_NOT_CORRECT");
        IBEP20 token1 = IBEP20(token1Pair.token());
        IBEP20 token2 = IBEP20(token2Pair.token());
        //get token1 to base
        uint256 baseAmount = token1Pair.getBaseOutput(token1InputAmount);
        //get base to token2
        uint256 token2OutputAmount = token2Pair.getTokenOutput(baseAmount);
        require(token2OutputAmount >= minToken2Output, 'CAN_NOT_MAKE_TRADE');
        //
        uint256 _turBalBefore = TUR.balanceOf(address(this));
        //make trade token1 to base
        token1.transferFrom(msg.sender, address(this), token1InputAmount);
        token1Pair.swapTokenToBaseWithTokenInput(token1InputAmount, baseAmount, deadline);

        //make trade base to token2
        token2Pair.swapBaseToTokenWithBaseInput(baseAmount, token2OutputAmount, deadline);
        token2.transfer(msg.sender, token2OutputAmount);

        uint256 _turBalAfter = TUR.balanceOf(address(this));

        if (_turBalAfter > _turBalBefore) {
            TUR.transfer(msg.sender, _turBalAfter.sub(_turBalBefore));
            emit onDistributeTuring(msg.sender, _turBalAfter.sub(_turBalBefore));
        }
    }
}