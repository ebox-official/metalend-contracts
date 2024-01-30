// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/Ownable.sol";
import "../Dependencies/SafeMath.sol";
import "../Interfaces/IMLENDToken.sol";

/*
* The lockup contract architecture utilizes a single LockupContract, with an unlockTime. The unlockTime is passed as an argument 
* to the LockupContract's constructor. The contract's balance can be withdrawn by the beneficiary when block.timestamp > unlockTime. 
* At construction, the contract checks that unlockTime is at least one year later than the Liquity system's deployment time. 

* Within the first year from deployment, the deployer of the MLENDToken (Liquity AG's address) may transfer MLEND only to valid 
* LockupContracts, and no other addresses (this is enforced in MLENDToken.sol's transfer() function).
* 
* The above two restrictions ensure that until one year after system deployment, MLEND tokens originating from Liquity AG cannot 
* enter circulating supply and cannot be staked to earn system revenue.
*/
contract LockupContract is Ownable {
    using SafeMath for uint;

    // --- Data ---
    string constant public NAME = "LockupContract";

    uint constant public SECONDS_IN_ONE_YEAR = 31536000; 

    address public beneficiary;

    IMLENDToken public mlendToken;

    // Unlock time is the Unix point in time at which the beneficiary can withdraw.
    uint public unlockTime;

    // --- Events ---

    event LockupContractCreated(address _beneficiary, uint _unlockTime);
    event LockupContractEmptied(uint _MLENDwithdrawal);

    // --- Functions ---

    constructor 
    (
        address _mlendTokenAddress, 
        address _beneficiary, 
        uint _unlockTime
    )
        public 
    {
		// MetaLend modification
        setData(_mlendTokenAddress, _beneficiary, _unlockTime);
    }

    function withdrawMLEND() external {
        _requireCallerIsBeneficiary();
        _requireLockupDurationHasPassed();

        IMLENDToken mlendTokenCached = mlendToken;
        uint MLENDBalance = mlendTokenCached.balanceOf(address(this));
        mlendTokenCached.transfer(beneficiary, MLENDBalance);
        emit LockupContractEmptied(MLENDBalance);
    }

    // --- 'require' functions ---

    function _requireCallerIsBeneficiary() internal view {
        require(msg.sender == beneficiary, "LockupContract: caller is not the beneficiary");
    }

    function _requireLockupDurationHasPassed() internal view {
        require(block.timestamp >= unlockTime, "LockupContract: The lockup duration must have passed");
    }

    function _requireUnlockTimeIsAtLeastOneYearAfterSystemDeployment(uint _unlockTime) internal view {
        uint systemDeploymentTime = mlendToken.getDeploymentStartTime();
        require(_unlockTime >= systemDeploymentTime.add(SECONDS_IN_ONE_YEAR), "LockupContract: unlock time must be at least one year after system deployment");
    }
	
	// --- MetaLend ---

	function setData(address _mlendTokenAddress, address _beneficiary, uint _unlockTime) public onlyOwner {
		mlendToken = IMLENDToken(_mlendTokenAddress);

        /*
        * Set the unlock time to a chosen instant in the future, as long as it is at least 1 year after
        * the system was deployed 
        */
        _requireUnlockTimeIsAtLeastOneYearAfterSystemDeployment(_unlockTime);
        unlockTime = _unlockTime;
        
        beneficiary =  _beneficiary;
        emit LockupContractCreated(_beneficiary, _unlockTime);
	}

	function renounceOwnership() external onlyOwner {
        _renounceOwnership();
    }
}
