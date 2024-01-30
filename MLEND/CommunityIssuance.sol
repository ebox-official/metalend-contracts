// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Interfaces/IMLENDToken.sol";
import "../Interfaces/ICommunityIssuance.sol";
import "../Interfaces/IMLENDIssuance.sol";
import "../Dependencies/BaseMath.sol";
import "../Dependencies/LiquityMath.sol";
import "../Dependencies/Ownable.sol";
import "../Dependencies/CheckContract.sol";
import "../Dependencies/SafeMath.sol";


contract CommunityIssuance is ICommunityIssuance, Ownable, CheckContract, BaseMath {
    using SafeMath for uint;

    // --- Data ---

    string constant public NAME = "CommunityIssuance";

    /* 
    * The community MLEND supply cap is the starting balance of the Community Issuance contract.
    * It should be minted to this contract by MLENDToken, when the token is deployed.
    * 
    * Set to 32M of total MLEND supply.
    */
    uint constant public MLENDSupplyCap = 32e24; // 32 million

    IMLENDToken public mlendToken;
    address public stabilityPoolAddress;
	IMLENDIssuance public mlendIssuance;

    uint public totalMLENDIssued;
    uint public immutable deploymentTime;
	uint public lastIssuanceTime;

	bool public paused = false;

    // --- Events ---

    event MLENDTokenAddressSet(address _mlendTokenAddress);
    event StabilityPoolAddressSet(address _stabilityPoolAddress);
	event MLENDIssuanceAddressSet(address _mlendTokenAddress);
    event TotalMLENDIssuedUpdated(uint _totalMLENDIssued);

    // --- Functions ---

    constructor() public {
        deploymentTime = block.timestamp;
		lastIssuanceTime = block.timestamp;
    }

    function setAddresses
    (
        address _mlendTokenAddress, 
        address _stabilityPoolAddress,
		address _mlendIssuanceAddress
    ) 
        external 
        onlyOwner 
        override 
    {
        checkContract(_mlendTokenAddress);
        checkContract(_stabilityPoolAddress);
		checkContract(_mlendIssuanceAddress);

        mlendToken = IMLENDToken(_mlendTokenAddress);
        stabilityPoolAddress = _stabilityPoolAddress;
		mlendIssuance = IMLENDIssuance(_mlendIssuanceAddress);

        emit MLENDTokenAddressSet(_mlendTokenAddress);
        emit StabilityPoolAddressSet(_stabilityPoolAddress);
		emit MLENDIssuanceAddressSet(_mlendIssuanceAddress);
    }

	function issueMLEND() external override returns (uint) {
		require(!paused, "MLEND issuance is paused.");
        _requireCallerIsStabilityPool();

		uint issuance = mlendIssuance.getMLENDIssuance(lastIssuanceTime);

        totalMLENDIssued = totalMLENDIssued.add(issuance);
		lastIssuanceTime = block.timestamp;
        emit TotalMLENDIssuedUpdated(totalMLENDIssued);
        
        return issuance;
    }

    function sendMLEND(address _account, uint _MLENDamount) external override {
		require(!paused, "MLEND issuance is paused.");
        _requireCallerIsStabilityPool();

        mlendToken.transfer(_account, _MLENDamount);
    }

    // --- 'require' functions ---

    function _requireCallerIsStabilityPool() internal view {
        require(msg.sender == stabilityPoolAddress, "CommunityIssuance: caller is not SP");
    }
	
	// --- MetaLend ---

	function pause(bool _paused) external onlyOwner {
		paused = _paused;
	}

	function retrieveMLEND(uint _MLENDamount) external onlyOwner {
		mlendToken.transfer(msg.sender, _MLENDamount);
	}

	function renounceOwnership() external onlyOwner {
        _renounceOwnership();
    }
}
