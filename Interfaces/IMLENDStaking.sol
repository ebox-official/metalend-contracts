// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface IMLENDStaking {

    // --- Events --
    
    event MLENDTokenAddressSet(address _mlendTokenAddress);
    event MUSDTokenAddressSet(address _musdTokenAddress);
    event TroveManagerAddressSet(address _troveManager);
    event BorrowerOperationsAddressSet(address _borrowerOperationsAddress);
    event ActivePoolAddressSet(address _activePoolAddress);

    event StakeChanged(address indexed staker, uint newStake);
    event StakingGainsWithdrawn(address indexed staker, uint MUSDGain, uint ETHGain);
    event F_ETHUpdated(uint _F_ETH);
    event F_MUSDUpdated(uint _F_MUSD);
    event TotalMLENDStakedUpdated(uint _totalMLENDStaked);
    event EtherSent(address _account, uint _amount);
    event StakerSnapshotsUpdated(address _staker, uint _F_ETH, uint _F_MUSD);

    // --- Functions ---

    function setAddresses
    (
        address _mlendTokenAddress,
        address _musdTokenAddress,
        address _troveManagerAddress, 
        address _borrowerOperationsAddress,
        address _activePoolAddress
    )  external;

    function stake(uint _MLENDamount) external;

    function unstake(uint _MLENDamount) external;

    function increaseF_ETH(uint _ETHFee) external; 

    function increaseF_MUSD(uint _MLENDFee) external;  

    function getPendingETHGain(address _user) external view returns (uint);

    function getPendingMUSDGain(address _user) external view returns (uint);
}
