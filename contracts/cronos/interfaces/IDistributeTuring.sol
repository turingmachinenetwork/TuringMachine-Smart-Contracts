// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IDistributeTuring {

	function updateUser(uint256 _pid, address _user) external returns(bool); 
	function harvest(uint256 _pid, address _user) external returns(uint256 _pendingTur);
	function processFee(uint256 _pid, uint256 _wantAmt) external;
	function poolLength() external view returns (uint256);
    function processProtocolLiquidityLaunch(uint256[] calldata _ratios) external payable;
	function getUserInfo(uint256 _pid, address _user) external view returns (uint256 _turingReward, uint256 _uShare);
	function getDistribution(uint256 _pid, uint256 _amountIn) external view returns (uint256 _amountOut);


}