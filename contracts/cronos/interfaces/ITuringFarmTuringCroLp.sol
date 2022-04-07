// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface ITuringFarmTuringCroLp{
    function distribution(uint256 _amount) external;

    function totalShare() external view returns(uint256);
}