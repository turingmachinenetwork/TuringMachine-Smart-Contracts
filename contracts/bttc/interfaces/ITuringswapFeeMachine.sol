// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './IBRC20.sol';

interface ITuringswapFeeMachine {
    function processTradeFee(IBRC20 token, address trader) external;
}