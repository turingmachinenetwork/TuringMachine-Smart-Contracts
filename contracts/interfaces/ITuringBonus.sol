// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface ITuringBonus {
	function getBonusAmount(ITuringFarm _turingFarm, address _user, uint256 _turMint) external view returns(uint256);
}