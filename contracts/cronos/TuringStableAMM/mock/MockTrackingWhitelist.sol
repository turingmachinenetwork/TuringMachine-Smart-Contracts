// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface ITuringswapTradePair {
    
	function addLP(uint256 minLP, uint256 baseInputAmount, uint256 maxTokenInputAmount, uint256 deadline) external;
	function removeLP(uint256 amountLP, uint256 minBaseOutput, uint256 minTokenOutput, uint256 deadline) external;

    function swapBaseToTokenWithBaseInput(uint256 baseInputAmount, uint256 minTokenOutput, uint256 deadline) external;
    function swapTokenToBaseWithTokenInput(uint256 tokenInputAmount, uint256 minBaseOutput, uint256 deadline) external;
    function swapBaseToTokenWithTokenOutput(uint256 maxBaseInput, uint256 tokenOutputAmount, uint256 deadline) external;
    function swapTokenToBaseWithBaseOutput(uint256 maxTokenInput, uint256 baseOutputAmount, uint256 deadline) external;

    function getBaseOutput(uint256 tokenInputAmount) external view returns (uint256);
    function getTokenOutput(uint256 baseInputAmount) external view returns (uint256);
}

interface IFarmVenusPool {
	function deposit(uint256 _wantAmt) external;
	function withdraw(uint256 _wantAmt) external;
}

contract MockTrackingWhitelist {
	function addLP(ITuringswapTradePair _swapTrade, uint256 minLP, uint256 baseInputAmount, uint256 maxTokenInputAmount, uint256 deadline) external {
		_swapTrade.addLP(minLP, baseInputAmount, maxTokenInputAmount, deadline);
	}

	function removeLP(ITuringswapTradePair _swapTrade, uint256 amountLP, uint256 minBaseOutput, uint256 minTokenOutput, uint256 deadline) external {
		_swapTrade.removeLP(amountLP, minBaseOutput, minTokenOutput, deadline);
	}

	function swapBaseToTokenWithBaseInput(ITuringswapTradePair _swapTrade, uint256 baseInputAmount, uint256 minTokenOutput, uint256 deadline) external {
		_swapTrade.swapBaseToTokenWithBaseInput(baseInputAmount, minTokenOutput, deadline);
	}

	function swapTokenToBaseWithTokenInput(ITuringswapTradePair _swapTrade, uint256 tokenInputAmount, uint256 minBaseOutput, uint256 deadline) external {
		_swapTrade.swapTokenToBaseWithTokenInput(tokenInputAmount, minBaseOutput, deadline);
	}

	function swapBaseToTokenWithTokenOutput(ITuringswapTradePair _swapTrade, uint256 maxBaseInput, uint256 tokenOutputAmount, uint256 deadline) external {
		_swapTrade.swapBaseToTokenWithTokenOutput(maxBaseInput, tokenOutputAmount, deadline);
	}

	function swapTokenToBaseWithBaseOutput(ITuringswapTradePair _swapTrade, uint256 maxTokenInput, uint256 baseOutputAmount, uint256 deadline) external {
		_swapTrade.swapTokenToBaseWithBaseOutput(maxTokenInput, baseOutputAmount, deadline);
	}

	function deposit(IFarmVenusPool _pool, uint256 _wantAmt) external {
		_pool.deposit(_wantAmt);
	}

	function withdraw(IFarmVenusPool _pool, uint256 _wantAmt) external {
		_pool.withdraw(_wantAmt);
	}
}