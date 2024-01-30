// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/BaseMath.sol";
import "../Dependencies/SafeMath.sol";
import "../Dependencies/Ownable.sol";
import "../Dependencies/CheckContract.sol";
import "../Dependencies/console.sol";
import "../Interfaces/IMLENDToken.sol";
import "../Interfaces/IMLENDStaking.sol";
import "../Dependencies/LiquityMath.sol";
import "../Interfaces/IMUSDToken.sol";

contract MLENDStaking is IMLENDStaking, Ownable, CheckContract, BaseMath {
    using SafeMath for uint;

    // --- Data ---
    string constant public NAME = "MLENDStaking";

    mapping( address => uint) public stakes;
    uint public totalMLENDStaked;

    uint public F_ETH;  // Running sum of DFI fees per-MLEND-staked
    uint public F_MUSD; // Running sum of MLEND fees per-MLEND-staked

    // User snapshots of F_ETH and F_MUSD, taken at the point at which their latest deposit was made
    mapping (address => Snapshot) public snapshots; 

    struct Snapshot {
        uint F_ETH_Snapshot;
        uint F_MUSD_Snapshot;
    }
    
    IMLENDToken public mlendToken;
    IMUSDToken public musdToken;

    address public troveManagerAddress;
    address public borrowerOperationsAddress;
    address public activePoolAddress;

	bool public paused = false;

    // --- Events ---

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
    ) 
        external 
        onlyOwner 
        override 
    {
        checkContract(_mlendTokenAddress);
        checkContract(_musdTokenAddress);
        checkContract(_troveManagerAddress);
        checkContract(_borrowerOperationsAddress);
        checkContract(_activePoolAddress);

        mlendToken = IMLENDToken(_mlendTokenAddress);
        musdToken = IMUSDToken(_musdTokenAddress);
        troveManagerAddress = _troveManagerAddress;
        borrowerOperationsAddress = _borrowerOperationsAddress;
        activePoolAddress = _activePoolAddress;

        emit MLENDTokenAddressSet(_mlendTokenAddress);
        emit MLENDTokenAddressSet(_musdTokenAddress);
        emit TroveManagerAddressSet(_troveManagerAddress);
        emit BorrowerOperationsAddressSet(_borrowerOperationsAddress);
        emit ActivePoolAddressSet(_activePoolAddress);
    }

    // If caller has a pre-existing stake, send any accumulated DFI and MUSD gains to them. 
    function stake(uint _MLENDamount) external override {
		require(!paused, "MLEND staking is paused.");
        _requireNonZeroAmount(_MLENDamount);

        uint currentStake = stakes[msg.sender];

        uint DFIGain;
        uint MUSDGain;
        // Grab any accumulated DFI and MUSD gains from the current stake
        if (currentStake != 0) {
            DFIGain = _getPendingETHGain(msg.sender);
            MUSDGain = _getPendingMUSDGain(msg.sender);
        }
    
       _updateUserSnapshots(msg.sender);

        uint newStake = currentStake.add(_MLENDamount);

        // Increase user’s stake and total MLEND staked
        stakes[msg.sender] = newStake;
        totalMLENDStaked = totalMLENDStaked.add(_MLENDamount);
        emit TotalMLENDStakedUpdated(totalMLENDStaked);

        // Transfer MLEND from caller to this contract
        mlendToken.sendToMLENDStaking(msg.sender, _MLENDamount);

        emit StakeChanged(msg.sender, newStake);
        emit StakingGainsWithdrawn(msg.sender, MUSDGain, DFIGain);

         // Send accumulated MUSD and DFI gains to the caller
        if (currentStake != 0) {
            musdToken.transfer(msg.sender, MUSDGain);
            _sendETHGainToUser(DFIGain);
        }
    }

    // Unstake the MLEND and send the it back to the caller, along with their accumulated MUSD & DFI gains. 
    // If requested amount > stake, send their entire stake.
    function unstake(uint _MLENDamount) external override {
		require(!paused, "MLEND staking is paused.");
        uint currentStake = stakes[msg.sender];
        _requireUserHasStake(currentStake);

        // Grab any accumulated DFI and MUSD gains from the current stake
        uint DFIGain = _getPendingETHGain(msg.sender);
        uint MUSDGain = _getPendingMUSDGain(msg.sender);
        
        _updateUserSnapshots(msg.sender);

        if (_MLENDamount > 0) {
            uint MLENDToWithdraw = LiquityMath._min(_MLENDamount, currentStake);

            uint newStake = currentStake.sub(MLENDToWithdraw);

            // Decrease user's stake and total MLEND staked
            stakes[msg.sender] = newStake;
            totalMLENDStaked = totalMLENDStaked.sub(MLENDToWithdraw);
            emit TotalMLENDStakedUpdated(totalMLENDStaked);

            // Transfer unstaked MLEND to user
            mlendToken.transfer(msg.sender, MLENDToWithdraw);

            emit StakeChanged(msg.sender, newStake);
        }

        emit StakingGainsWithdrawn(msg.sender, MUSDGain, DFIGain);

        // Send accumulated MUSD and DFI gains to the caller
        musdToken.transfer(msg.sender, MUSDGain);
        _sendETHGainToUser(DFIGain);
    }

    // --- Reward-per-unit-staked increase functions. Called by Liquity core contracts ---

    function increaseF_ETH(uint _DFIFee) external override {
        _requireCallerIsTroveManager();
        uint DFIFeePerMLENDStaked;
     
        if (totalMLENDStaked > 0) {DFIFeePerMLENDStaked = _DFIFee.mul(DECIMAL_PRECISION).div(totalMLENDStaked);}

        F_ETH = F_ETH.add(DFIFeePerMLENDStaked); 
        emit F_ETHUpdated(F_ETH);
    }

    function increaseF_MUSD(uint _MUSDFee) external override {
        _requireCallerIsBorrowerOperations();
        uint MUSDFeePerMLENDStaked;
        
        if (totalMLENDStaked > 0) {MUSDFeePerMLENDStaked = _MUSDFee.mul(DECIMAL_PRECISION).div(totalMLENDStaked);}
        
        F_MUSD = F_MUSD.add(MUSDFeePerMLENDStaked);
        emit F_MUSDUpdated(F_MUSD);
    }

    // --- Pending reward functions ---

    function getPendingETHGain(address _user) external view override returns (uint) {
        return _getPendingETHGain(_user);
    }

    function _getPendingETHGain(address _user) internal view returns (uint) {
        uint F_ETH_Snapshot = snapshots[_user].F_ETH_Snapshot;
        uint DFIGain = stakes[_user].mul(F_ETH.sub(F_ETH_Snapshot)).div(DECIMAL_PRECISION);
        return DFIGain;
    }

    function getPendingMUSDGain(address _user) external view override returns (uint) {
        return _getPendingMUSDGain(_user);
    }

    function _getPendingMUSDGain(address _user) internal view returns (uint) {
        uint F_MUSD_Snapshot = snapshots[_user].F_MUSD_Snapshot;
        uint MUSDGain = stakes[_user].mul(F_MUSD.sub(F_MUSD_Snapshot)).div(DECIMAL_PRECISION);
        return MUSDGain;
    }

    // --- Internal helper functions ---

    function _updateUserSnapshots(address _user) internal {
        snapshots[_user].F_ETH_Snapshot = F_ETH;
        snapshots[_user].F_MUSD_Snapshot = F_MUSD;
        emit StakerSnapshotsUpdated(_user, F_ETH, F_MUSD);
    }

    function _sendETHGainToUser(uint DFIGain) internal {
        emit EtherSent(msg.sender, DFIGain);
        (bool success, ) = msg.sender.call{value: DFIGain}("");
        require(success, "MLENDStaking: Failed to send accumulated DFIGain");
    }

    // --- 'require' functions ---

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == troveManagerAddress, "MLENDStaking: caller is not TroveM");
    }

    function _requireCallerIsBorrowerOperations() internal view {
        require(msg.sender == borrowerOperationsAddress, "MLENDStaking: caller is not BorrowerOps");
    }

     function _requireCallerIsActivePool() internal view {
        require(msg.sender == activePoolAddress, "MLENDStaking: caller is not ActivePool");
    }

    function _requireUserHasStake(uint currentStake) internal pure {  
        require(currentStake > 0, 'MLENDStaking: User must have a non-zero stake');  
    }

    function _requireNonZeroAmount(uint _amount) internal pure {
        require(_amount > 0, 'MLENDStaking: Amount must be non-zero');
    }

    receive() external payable {
        _requireCallerIsActivePool();
    }
	
	// --- MetaLend ---

	function pause(bool _paused) external onlyOwner {
		paused = _paused;
	}

	function renounceOwnership() external onlyOwner {
        _renounceOwnership();
    }
}
