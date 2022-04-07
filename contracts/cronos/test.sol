// SPDX-License-Identifier: MIT
pragma solidity = 0.6.12;

contract testB {

    function getOverFlow(uint256 _value) public view returns(uint256) {
        return _value * 1e24;
    }
}
