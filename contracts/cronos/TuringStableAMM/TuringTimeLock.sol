// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import "./library/SafeMath.sol";
import "./library/Ownable.sol";

contract TuringTimeLock is Ownable {
    using SafeMath for uint256;
    mapping(address => mapping(bytes32 => LockTransaction)) public lockTransactionOf;

    uint256 public constant GRACE_PERIOD = 30 days;
    uint256 public constant MINIMUM_DELAY = 3 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;
    uint256 public DELAY;

    struct LockTransaction {
        bool queued;
        uint256 executeTime;
   }

    event onQueuedTransaction(address _contractCall, string _functionName, uint256 _executeTime);
    event onCancelTransaction(address _contractCall, string _functionName);  

    function setDelay(uint256 _delay) public onlyOwner {
        require(_delay >= MINIMUM_DELAY);
        require(_delay <= MAXIMUM_DELAY);
        DELAY = _delay;
    }

    function isQueuedTransaction(address _contractCall, string memory _functionName) public view returns(bool) {
        LockTransaction storage _lock = lockTransactionOf[_contractCall][keccak256(abi.encode(_functionName))];
        require(_lock.queued == true, "Contract has not been queued transaction.");
        require(_lock.executeTime <= block.timestamp, "Transaction hasn't surpassed time lock.");
        require(_lock.executeTime.add(GRACE_PERIOD) >= block.timestamp, "Transaction is stale.");
        return true;
    } 

    function queuedTransaction(address _contractCall, string memory _functionName) public onlyOwner {
        LockTransaction storage _lock = lockTransactionOf[_contractCall][keccak256(abi.encode(_functionName))];
        _lock.queued = true;
        _lock.executeTime = block.timestamp.add(DELAY);
        emit onQueuedTransaction(_contractCall, _functionName, _lock.executeTime);
    }

    function cancelTransaction(address _contractCall, string memory _functionName) public onlyOwner {
        LockTransaction storage _lock = lockTransactionOf[_contractCall][keccak256(abi.encode(_functionName))];
        require(_lock.queued == true, "contract has not been queued transaction.");
        _lock.queued = false;
        emit onCancelTransaction(_contractCall, _functionName);
    }

    function doneTransaction(string memory _functionName) public {
        LockTransaction storage _lock = lockTransactionOf[msg.sender][keccak256(abi.encode(_functionName))];
        require(_lock.queued == true, "contract has not been queued transaction.");
        _lock.queued = false;
    }

}
