// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IAlpacaVault {
	/**
   	* @dev Returns the amount of tokens in existence.
   	*/
  	function totalSupply() external view returns (uint256);
  	function totalToken() external view returns(uint256);
	function balanceOf(address owner) external view returns (uint);
	
	/**
    * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
    *
  	* Returns a boolean value indicating whether the operation succeeded.
   	*
   	* IMPORTANT: Beware that changing an allowance with this method brings the risk
   	* that someone may use both the old and the new allowance by unfortunate
   	* transaction ordering. One possible solution to mitigate this race
   	* condition is to first reduce the spender's allowance to 0 and set the
   	* desired value afterwards:
   	* https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   	*
   	* Emits an {Approval} event.
   	*/
  	function approve(address spender, uint256 amount) external returns (bool);
	function deposit(uint256 amountToken) external payable;
	function withdraw(uint256 share) external;
}