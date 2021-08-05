// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './interfaces/IBEP20.sol';
import './interfaces/IAlpacaVault.sol';
import './interfaces/IAlpacaFairLaunch.sol';

import './library/Ownable.sol';

contract TuringAlpacaFarmBNBTest is Ownable {
	IAlpacaVault public AlpacaVault; // ibBNB
	IAlpacaFairLaunch public AlpacaFairLaunch;
	uint256 public pidOfVault;
	constructor (
		IAlpacaVault _alpacaVault,
		IAlpacaFairLaunch _alpacaFairLaunch,
		uint256 _pidOfVault
		) public {
	    AlpacaVault = _alpacaVault;
	    AlpacaFairLaunch = _alpacaFairLaunch;
	    pidOfVault = _pidOfVault;
	    // connectToAlpacaFarm
	    IBEP20(address(_alpacaVault)).approve(address(_alpacaFairLaunch), uint256(-1));
	}
    receive() external payable {
        
    }
	function moveBEP20Token(address _token, uint256 _amount) external onlyOwner {
		IBEP20(_token).transfer(msg.sender, _amount);
	}
	
	// Deposit Staking tokens to FairLaunchToken for ALPACA allocation.
  	// function deposit(address _for, uint256 _pid, uint256 _amount) external;
  	function deposit() external payable onlyOwner {
  		// Get ibBNB
  		AlpacaVault.deposit{ value: msg.value }(msg.value);
  		// Get AlpacaVaultToken balance
  		uint256 _alpacaVaultBal = AlpacaVault.balanceOf(address(this));
  		// Deposit
  		AlpacaFairLaunch.deposit(address(this), pidOfVault, _alpacaVaultBal);
  	}
  	// Withdraw Staking tokens from FairLaunchToken.
  	// function withdraw(address _for, uint256 _pid, uint256 _amount) external;
  	function withdraw(uint256 _amount) external onlyOwner {
  		AlpacaFairLaunch.withdraw(address(this), pidOfVault, _amount);
  		// Get AlpacaVaultToken balance
  		uint256 _alpacaVaultBal = AlpacaVault.balanceOf(address(this));
  		AlpacaVault.withdraw(_alpacaVaultBal);
  		// transfer BNB to user
  		address(uint160(msg.sender)).transfer(address(this).balance);
  	}
  	// Harvest ALPACAs earn from the pool.
  	// function harvest(uint256 _pid) external;
  	function harvest() external onlyOwner {
  		AlpacaFairLaunch.harvest(pidOfVault);
  	}
}