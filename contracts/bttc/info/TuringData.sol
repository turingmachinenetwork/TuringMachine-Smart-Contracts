// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);
    function MAX_TOTAL_SUPPLY() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
}

interface IVVSRouter {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

contract TuringData {

    uint256 public version = 100;

    // Dev Locked Contract.
    IVVSRouter public VVSRouter;

    IBEP20 public TUR;
    address public WCRO;
    address public USDC;

    constructor(
        IBEP20 _tur,
        address _wcro,
        address _usdc,
        IVVSRouter _vvsRouter
    ) public {
        VVSRouter = _vvsRouter;

        TUR = _tur;
        WCRO = _wcro;
        USDC = _usdc;
    }

    function getData() public view returns(uint256 circulatingSupply_, uint256 totalSupply_, uint256 maxSupply_, uint256 price_) 
    {
        totalSupply_ = TUR.totalSupply();
        circulatingSupply_ = totalSupply_;
        maxSupply_ = TUR.MAX_TOTAL_SUPPLY();
        price_ = getTuringPrice();
    }

    function getTuringPrice() public view returns(uint256) 
    {
        address[] memory path = new address[](3);
        path[0] = address(TUR);
        path[1] = WCRO;
        path[2] = USDC;
        uint256 _price;
        try VVSRouter.getAmountsOut(1e18, path) returns(uint[] memory amounts) {
            _price = amounts[2];
        } catch {
            _price = 0;   
        }
        return _price;
    }
}