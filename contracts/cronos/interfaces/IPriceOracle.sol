// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

interface IPriceOracle {
    function priceOf(address _token) external view returns(uint256);
}