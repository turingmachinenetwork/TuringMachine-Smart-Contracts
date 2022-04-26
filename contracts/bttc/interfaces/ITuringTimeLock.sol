// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface ITuringTimeLock {
    function isQueuedTransaction(address _contractCall, string memory _functionName) external view returns(bool);
    function doneTransaction(string memory _functionName) external;
}
