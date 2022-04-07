// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IVenusDistribution {
    function claimVenus(address holder, address[] memory vTokens) external;
    function venusSpeeds(address) external view returns (uint);
}
