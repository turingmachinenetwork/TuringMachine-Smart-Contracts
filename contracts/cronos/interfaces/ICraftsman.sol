// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

contract ICraftsman { 
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    struct UserInfo {
        uint256 amount;    
        uint256 rewardDebt; 
    }
    // Deposit LP tokens to MasterChef for CAKE allocation.
    function deposit(uint256 _pid, uint256 _amount) external {}
    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external {}
    // Stake CAKE tokens to MasterChef
    function enterStaking(uint256 _amount) external {}
    // Withdraw CAKE tokens from STAKING.
    function leaveStaking(uint256 _amount) external {}
    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external {}
    // View function to see pending CAKEs on frontend.
    function pendingVVS(uint256 _pid, address _user) external view returns (uint256) {}
}