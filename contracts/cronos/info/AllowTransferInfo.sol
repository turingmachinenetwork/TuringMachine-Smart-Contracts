// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
import '../interfaces/IBEP20.sol';
contract AllowTransferInfo {
	struct Allow {
		address token;
		uint256 amount;
	}
	function getData(address _owner, address _spender, IBEP20[] calldata _tokens) public view returns(Allow[] memory data_)
	{
		data_ = new Allow[](_tokens.length);
		for (uint256 idx = 0; idx < _tokens.length; idx++) {
			data_[idx].token = address(_tokens[idx]);
			data_[idx].amount = _tokens[idx].allowance(_owner, _spender);
		}
	}
}
