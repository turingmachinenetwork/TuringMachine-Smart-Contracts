// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

abstract contract IAlpacaFairLaunch {
	// Info of each user that stakes Staking tokens.
  	mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  	// Info of each user.
  	struct UserInfo {
    	uint256 amount; // How many Staking tokens the user has provided.
    	uint256 rewardDebt; // Reward debt. See explanation below.
    	uint256 bonusDebt; // Last block that user exec something to the pool.
    	address fundedBy; // Funded by who?
	    //
	    // We do some fancy math here. Basically, any point in time, the amount of ALPACAs
	    // entitled to a user but is pending to be distributed is:
	    //
	    //   pending reward = (user.amount * pool.accAlpacaPerShare) - user.rewardDebt
	    //
	    // Whenever a user deposits or withdraws Staking tokens to a pool. Here's what happens:
	    //   1. The pool's `accAlpacaPerShare` (and `lastRewardBlock`) gets updated.
	    //   2. User receives the pending reward sent to his/her address.
	    //   3. User's `amount` gets updated.
	    //   4. User's `rewardDebt` gets updated.
  	}
  	function pendingAlpaca(uint256 _pid, address _user) external view returns (uint256) {}
	// Deposit Staking tokens to FairLaunchToken for ALPACA allocation.
  	function deposit(address _for, uint256 _pid, uint256 _amount) external {}
  	// Withdraw Staking tokens from FairLaunchToken.
  	function withdraw(address _for, uint256 _pid, uint256 _amount) external {}
  	function withdrawAll(address _for, uint256 _pid) external {}
  	// Harvest ALPACAs earn from the pool.
  	function harvest(uint256 _pid) external {}
}