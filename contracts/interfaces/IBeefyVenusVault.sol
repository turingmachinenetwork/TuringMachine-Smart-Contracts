// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IBeefyVenusVault {

	function depositAll() external;
	function withdrawAll() external;
	function deposit(uint _amount) external;
	function withdraw(uint256 _shares) external;

	function totalSupply() external view returns (uint256);
	function balanceOf(address account) external view returns (uint256);
	function balance() external view returns (uint256);
	function available() external view returns (uint256);

}