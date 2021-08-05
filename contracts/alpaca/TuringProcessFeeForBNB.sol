// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

import './library/SafeMath.sol';
import './library/Ownable.sol';

import './interfaces/IBEP20.sol';
import './interfaces/IPancakeSwapRouter.sol';
interface ITuringWhitelist {
    function whitelisted(address _address) external view returns (bool);
}
interface ITuringTimeLock {

    function doneTransactions(string memory _functionName) external;
    function clearFieldValue(string memory _functionName, string memory _fieldName, uint8 _typeOfField) external;

    function getAddressChangeOnTimeLock(address _contractCall, string memory _functionName, string memory _fieldName) external view returns(address); 
    function getUintChangeOnTimeLock(address _contractCall, string memory _functionName, string memory _fieldName) external view returns(uint256);
    function isQueuedTransaction(address _contractCall, string memory _functionName) external view returns(bool);
}
contract TuringProcessFeeForBNB is Ownable {
    uint128 public version = 100;
    using SafeMath for uint256;

    ITuringWhitelist public TuringWhitelist; 
    ITuringTimeLock public TuringTimeLock;
    IPancakeSwapRouter public PancakeSwap;

    IBEP20 public TURING;
    address public WBNB;

    address public performanceMachine; // the contract will use fee to Buy tUR on pankace swap , then burn the turs token
    address public controllerMachine;
    uint256 public CONTROLLER_FEE = 1000; // 10% of fee

    modifier onlyWhitelist()
    {
        if (msg.sender != tx.origin) {
          require(TuringWhitelist.whitelisted(msg.sender) == true, 'INVALID_WHITELIST');
        }
        _;
    }
    constructor (
    ITuringTimeLock _turingTimeLock,
    ITuringWhitelist _turingWhitelist,
    IPancakeSwapRouter _PancakeSwap,
    address _wbnb,
        IBEP20 _turing
            ) public {
    TuringTimeLock = _turingTimeLock;
    TuringWhitelist = _turingWhitelist;
    PancakeSwap = _PancakeSwap;

    TURING = _turing;
    WBNB = _wbnb;
    }
    receive() external payable {

    }

    function setWhitelistContract(ITuringWhitelist _whitelistContract) public onlyOwner {
            TuringWhitelist = _whitelistContract;
    }
    function setPerformanceMachine() public onlyOwner 
    {
        require(TuringTimeLock.isQueuedTransaction(address(this), 'setPerformanceMachine'), "INVALID_PERMISSION");

        address _performanceMachine = TuringTimeLock.getAddressChangeOnTimeLock(address(this), 'setPerformanceMachine', 'performanceMachine');

        require(_performanceMachine != address(0), "INVALID_ADDRESS");

        performanceMachine = _performanceMachine;

        TuringTimeLock.clearFieldValue('setPerformanceMachine', 'performanceMachine', 1);
        TuringTimeLock.doneTransactions('setPerformanceMachine');
    }
    function setControllerMachine() public onlyOwner 
    {
        require(TuringTimeLock.isQueuedTransaction(address(this), 'setControllerMachine'), "INVALID_PERMISSION");

        address _controllerMachine = TuringTimeLock.getAddressChangeOnTimeLock(address(this), 'setControllerMachine', 'controllerMachine');

        require(_controllerMachine != address(0), "INVALID_ADDRESS");

        controllerMachine = _controllerMachine;

        TuringTimeLock.clearFieldValue('setControllerMachine', 'controllerMachine', 1);
        TuringTimeLock.doneTransactions('setControllerMachine');
    }
    function setControllerFee() public onlyOwner 
    {
        require(TuringTimeLock.isQueuedTransaction(address(this), 'setControllerFee'), "INVALID_PERMISSION");
        CONTROLLER_FEE = TuringTimeLock.getUintChangeOnTimeLock(address(this), 'setControllerFee', 'CONTROLLER_FEE');
        TuringTimeLock.clearFieldValue('setControllerFee', 'CONTROLLER_FEE', 2);
        TuringTimeLock.doneTransactions('setControllerFee');
    }

    function processFee() public payable onlyWhitelist {
            uint256 _controllerFee = msg.value.mul(CONTROLLER_FEE).div(10000);
            if (_controllerFee > 0) {
                    address(uint160(controllerMachine)).transfer(_controllerFee);
            }
    }

    function burnBNB() public onlyWhitelist {
        // Buy Turing and transfer TURING to Performance machine to burn TURING
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(TURING);
        PancakeSwap.swapExactETHForTokens{ value: totalBNB() }(1, path, performanceMachine, block.timestamp);
    }
    function totalBNB() public view returns(uint256) {
        return address(this).balance;
    }
}