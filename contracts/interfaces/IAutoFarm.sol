pragma solidity 0.6.12;

interface IAutoFarm {

	function deposit(uint256 _pid, uint256 _wantAmt) external;
	function withdraw(uint256 _pid, uint256 _wantAmt) external;
	function pendingAUTO(uint256 _pid, address _user)
        external
        view
        returns (uint256);

     function stakedWantTokens(uint256 _pid, address _user)
        external
        view
        returns (uint256);
}