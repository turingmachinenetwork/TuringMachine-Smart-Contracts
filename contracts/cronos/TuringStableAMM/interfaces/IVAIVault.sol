// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

contract IVAIVault {

    /// @notice Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    // Info of each user that stakes tokens.
    mapping(address => UserInfo) public userInfo;

	function deposit(uint256 _amount) external {}
    function withdraw(uint256 _amount) external {}
    function claim() external {}
}
