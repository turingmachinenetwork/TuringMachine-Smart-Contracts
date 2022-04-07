// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import './IBEP20.sol';
interface ITuringFarm {
	function totalShare() external view returns(uint256);
	function WANT() external view returns(IBEP20);
	function shareOf(address) external view returns(uint256);
	function rateOfPerformanceFee() external view returns(uint256);
	function getPerfomanceFee() external view returns(uint256);
	function pendingWantOf(address) external view returns(uint256);

}