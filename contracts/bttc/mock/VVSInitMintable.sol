// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./library/ERC20.sol";

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
contract VVSInitMintable is ERC20("VVSToken", "VVS", 6), Ownable {
    uint256 public nextDistributionTimestamp;

    uint256 public constant nextDistributionWindow = 365 days;
    uint256 public constant BLOCK_TIME = 6 seconds;

    bool isAfterFirstYear;
    uint256 public SUPPLY_PER_YEAR;
    uint256 public SUPPLY_PER_BLOCK;

    event SupplyDistributed(uint256 amount);

    constructor (
        uint256 _supplyPerYear
    ) public {
        SUPPLY_PER_YEAR = _supplyPerYear;
        SUPPLY_PER_BLOCK = _perYearToPerBlock(_supplyPerYear);
        nextDistributionTimestamp = block.timestamp;
    }

    function distributeSupply(
        address[] memory _teamAddresses,
        uint256[] memory _teamAmounts
    ) public onlyOwner {
        require(block.timestamp >= nextDistributionTimestamp, "VVSInitMintable: Not ready");
        require(_teamAddresses.length == _teamAmounts.length, "VVSInitMintable: Array length mismatch");

        if (isAfterFirstYear) {
            SUPPLY_PER_YEAR = SUPPLY_PER_YEAR.div(2);
        } else {
            isAfterFirstYear = true;
        }

        uint256 communitySupplyPerYear = SUPPLY_PER_YEAR;
        for (uint256 i; i < _teamAddresses.length; i++) {
            _mint(_teamAddresses[i], _teamAmounts[i]);
            communitySupplyPerYear = communitySupplyPerYear.sub(_teamAmounts[i]);
        }

        require(communitySupplyPerYear >= SUPPLY_PER_YEAR.mul(30).div(100));

        SUPPLY_PER_BLOCK = _perYearToPerBlock(communitySupplyPerYear);
        nextDistributionTimestamp = nextDistributionTimestamp.add(nextDistributionWindow);
        emit SupplyDistributed(SUPPLY_PER_YEAR.sub(communitySupplyPerYear));
    }

    function _perYearToPerBlock (
        uint256 perYearValue
    ) internal pure returns (uint256) {
        return perYearValue.mul(BLOCK_TIME).div(365 days);
    }
}
