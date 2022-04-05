// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;

import '../interfaces/IVVSRouter.sol';
contract PriceInfo {
	address public owner;
    IVVSRouter public VVSRouter;
    address public WCRO;
    address public USDC;
	modifier onlyOwner()
	{
	        require(msg.sender == owner, 'INVALID_PERMISSION');
	        _;
	}
    struct Price {
		address token;
		uint256 price;
	}
	constructor(
        IVVSRouter _vvsRouter,
        address _wcro,
        address _usdc
        ) public {
	        owner = msg.sender;
            VVSRouter = _vvsRouter;
            WCRO = _wcro;
            USDC = _usdc;
	}
    function setVVSRouter(IVVSRouter _vvsRouter) public onlyOwner
    {
        VVSRouter = _vvsRouter;
    }
    function getPrice(address _token) public view returns(uint256)
	{
        if (_token == USDC) return 1e18;
        address[] memory _path;
        _path = new address[](2);
        _path[0] = _token;
        _path[1] = USDC;
        uint256 _price;
        try VVSRouter.getAmountsOut(1e18, _path) returns (uint[] memory amounts) {
            _price = amounts[1];
        } catch {
            _path = new address[](3);
            _path[0] = _token;
            _path[1] = WCRO;
            _path[2] = USDC;
            try VVSRouter.getAmountsOut(1e18, _path) returns (uint[] memory amounts) {
                _price = amounts[2];
            } catch {
                _price = 0;
            }
        }
        return _price;
	}
    function getData(address[] calldata _tokens) public view returns(Price[] memory data_) {
		data_ = new Price[](_tokens.length);
		for (uint256 idx = 0; idx < _tokens.length; idx++) {
			data_[idx].token = _tokens[idx];
			data_[idx].price = getPrice(_tokens[idx]);
		}
	}
}
