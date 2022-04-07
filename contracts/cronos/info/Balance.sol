// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
interface IBEP20 {
	function balanceOf(address account) external view returns (uint256);
}
contract BalanceInfo {
        struct BEP20BALANCE {
                address token;
                uint256 amount;
        }
	function getData(address _account, IBEP20[] memory _tokens) public view returns(BEP20BALANCE[] memory tokensBal_, uint256 croBal_)
	{
		croBal_ = address(_account).balance;
		tokensBal_ = new BEP20BALANCE[](_tokens.length);
		for (uint256 idx = 0; idx < _tokens.length; idx++) {
			tokensBal_[idx].token = address(_tokens[idx]);
			tokensBal_[idx].amount = _tokens[idx].balanceOf(_account);
		}
	}
}
