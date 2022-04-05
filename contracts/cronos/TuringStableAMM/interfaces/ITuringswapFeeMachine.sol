// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './IBEP20.sol';

interface ITuringswapFeeMachine {
    function processTradeFee(IBEP20 token, address trader) external;
}