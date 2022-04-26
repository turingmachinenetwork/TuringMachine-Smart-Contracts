// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
interface IBRC20 {
	function balanceOf(address account) external view returns (uint256);
}
contract BalanceInfo {
        struct BRC20BALANCE {
                address token;
                uint256 amount;
        }
	function getData(address _account, IBRC20[] memory _tokens) public view returns(BRC20BALANCE[] memory tokensBal_, uint256 bttBal_)
	{
		bttBal_ = address(_account).balance;
		tokensBal_ = new BRC20BALANCE[](_tokens.length);
		for (uint256 idx = 0; idx < _tokens.length; idx++) {
			tokensBal_[idx].token = address(_tokens[idx]);
			tokensBal_[idx].amount = _tokens[idx].balanceOf(_account);
		}
	}
}
