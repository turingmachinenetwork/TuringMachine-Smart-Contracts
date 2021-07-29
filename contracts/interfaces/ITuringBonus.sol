// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './ITuringFarm.sol';

interface ITuringBonus {
	function getBonusAmount(ITuringFarm _turingFarm, address _user, uint256 _turMint) external view returns(uint256);
}