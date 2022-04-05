// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;
import '../interfaces/IBEP20.sol';
contract VVSRouter {
    mapping(address => mapping(address => uint256)) public priceToken;

    receive() external payable {
    }
    function setPricetoken(address _from, address _to, uint256 _value) public {
        priceToken[_from][_to] = _value;
    }
    function claimToken(IBEP20 _token, uint256 _amount) public
    {
        _token.transfer(msg.sender, _amount);
    }

    function claimCro(address payable _to, uint _amount) public {
        // Note that "to" is declared as payable
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed to send Ether");
    }

    function getBalanceToken(IBEP20 _token) public view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }  

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) public returns (uint[] memory amounts) {
        amounts = getAmountsOut(amountIn, path);
        IBEP20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IBEP20(path[path.length - 1]).transfer(to, amounts[path.length - 1]);
    }
    function getAmountsOut(uint amountIn, address[] calldata path) public view returns (uint[] memory amounts){
        require(path.length >= 2, 'VVSLibrary: INVALID_PATH');
        uint256 _price = priceToken[path[0]][path[path.length - 1]];
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[path.length - 1] = amountIn * _price / 1e18;
    }

     function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        amountToken = amountTokenDesired;
        amountETH = msg.value;
    }


}