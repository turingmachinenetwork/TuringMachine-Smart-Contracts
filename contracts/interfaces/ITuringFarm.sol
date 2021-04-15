// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './IBEP20.sol';

contract ITuringFarm {

   uint256 public totalShare;

   IBEP20 public want;

   mapping(address => uint256) public shareOf; 
}