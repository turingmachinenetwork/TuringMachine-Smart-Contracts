// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IMiningMachine {
	function burn(address account, uint256 amount) external;
	function harvest(uint256 _pid, address _user) external returns(uint256 _pendingTur);
	function updateUser(uint256 _pid, address _user) external returns(bool); 

	function getMiningSpeedOf(uint256 _pid) external view returns(uint256);
	function getTotalMintPerDayOf(uint256 _pid) external view returns(uint256);
	function getUserInfo(uint256 _pid, address _user) external view returns (uint256 _pendingTur, uint256 _rewardDebt, uint256 _userShare);
	function getTurAddr() external view returns(address); 
}