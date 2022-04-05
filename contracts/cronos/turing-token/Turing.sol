// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import '../library/SafeMath.sol';
import '../library/BEP20Token.sol';

import '../interfaces/ITuringTimeLock.sol';
contract TURING is BEP20Token {
	using SafeMath for uint256;

	ITuringTimeLock public turingTimeLockContract;
	address public distributeTuring;
	address public burnTuring;
	uint256 public MAX_TOTAL_SUPPLY = 628318 * 1e18;
	modifier isQueued(string memory _functionName) {
	    require(turingTimeLockContract.isQueuedTransaction(address(this), _functionName) == true, "INVALID_PERMISTION");
	    _;
	    turingTimeLockContract.doneTransaction(_functionName);
	}
	modifier onlyDistributeTuring() {
        require(msg.sender == distributeTuring, 'INVALID_PERMISSION');
        _;
    }
	constructor(
		ITuringTimeLock _turingTimeLockContract,
		string memory _tokenName, 
		string memory _tokenSymbol, 
		uint8 _tokenDecimal
		) BEP20Token(_tokenName, _tokenSymbol, _tokenDecimal) {
			turingTimeLockContract = _turingTimeLockContract;
	}

	function setDistributeTuring(address _addr) public onlyOwner isQueued("setDistributeTuring") {
	        distributeTuring = _addr;
	}

	function setBurnTuring(address _addr) public onlyOwner isQueued("setBurnTuring") {
	        burnTuring = _addr;
	}

	function setMaxTotalSupply(uint256 _value) public onlyOwner isQueued('setMaxTotalSupply') {
		require(_value >= totalSupply(), 'INVALID_TOTAL_SUPPLY');
		MAX_TOTAL_SUPPLY = _value;
	}
	
	function releaseTuring(uint256 _amount) public onlyOwner {
		require(distributeTuring != address(0), 'INVALID_DISTRIBUTION_MACHINE');
		require(_amount > 0, 'INVALID_AMOUNT:01');
		uint256 _totalSupply = totalSupply();
		if (_totalSupply > MAX_TOTAL_SUPPLY) {
		_amount = 0;
		} else if (_totalSupply.add(_amount) > MAX_TOTAL_SUPPLY) {
		_amount = MAX_TOTAL_SUPPLY.sub(_totalSupply);
		}
		require(_totalSupply.add(_amount) <= MAX_TOTAL_SUPPLY, 'over maxTotalSupply');
		require(_amount > 0, 'INVALID_AMOUNT:02');
		_mint(distributeTuring, _amount);
	}

    function burn(address _account, uint256 _amount) public {
		require(msg.sender == burnTuring, "ONLY_BURN_MACHINE");
		require(_account != address(0), 'INVALID_ADDRESS');
		require(_amount > 0, 'INVALID_AMOUNT');
		_burn(_account, _amount);
    }
}
