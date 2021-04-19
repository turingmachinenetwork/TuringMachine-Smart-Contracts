// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);
    function maxTotalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
}

interface IPancakeSwapRouter {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

contract TuringData {

    uint256 public version = 100;

    // Dev Locked Contract.
    IPancakeSwapRouter public pancakeSwap;

    IBEP20 public TUR;
    address public wbnb;
    address public busd;

    constructor(
        IBEP20 _tur,
        address _wbnb,
        address _busd,
        IPancakeSwapRouter _pancakeSwap
    ) public {
        pancakeSwap = _pancakeSwap;

        TUR = _tur;
        wbnb = _wbnb;
        busd = _busd;
    }

    function getData() public view returns(uint256 circulatingSupply_, uint256 totalSupply_, uint256 maxSupply_, uint256 price_) 
    {
        totalSupply_ = TUR.totalSupply();
        circulatingSupply_ = totalSupply_;
        maxSupply_ = TUR.maxTotalSupply();
        price_ = getTuringPrice();
    }

    function getTuringPrice() public view returns(uint256) 
    {
        address[] memory path = new address[](3);
        path[0] = address(TUR);
        path[1] = wbnb;
        path[2] = busd;
        uint256 _price;
        try pancakeSwap.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
            _price = amounts[2];
        } catch {
            _price = 0;   
        }
        return _price;
    }
}