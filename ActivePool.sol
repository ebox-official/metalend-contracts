// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import './Interfaces/IActivePool.sol';
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/console.sol";

/*
 * The Active Pool holds the DFI collateral and MUSD debt (but not MUSD tokens) for all active troves.
 *
 * When a trove is liquidated, it's DFI and MUSD debt are transferred from the Active Pool, to either the
 * Stability Pool, the Default Pool, or both, depending on the liquidation conditions.
 *
 */
contract ActivePool is Ownable, CheckContract, IActivePool {
    using SafeMath for uint256;

    string constant public NAME = "ActivePool";

    address public borrowerOperationsAddress;
    address public troveManagerAddress;
    address public stabilityPoolAddress;
    address public defaultPoolAddress;
    uint256 internal DFI;  // deposited DFI tracker
    uint256 internal MUSDDebt;

	bool public paused = false;

    // --- Events ---

    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolMUSDDebtUpdated(uint _MUSDDebt);
    event ActivePoolETHBalanceUpdated(uint _ETH);

    // --- Contract setters ---

    function setAddresses(
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _stabilityPoolAddress,
        address _defaultPoolAddress
    )
        external
        onlyOwner
    {
        checkContract(_borrowerOperationsAddress);
        checkContract(_troveManagerAddress);
        checkContract(_stabilityPoolAddress);
        checkContract(_defaultPoolAddress);

        borrowerOperationsAddress = _borrowerOperationsAddress;
        troveManagerAddress = _troveManagerAddress;
        stabilityPoolAddress = _stabilityPoolAddress;
        defaultPoolAddress = _defaultPoolAddress;

        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit StabilityPoolAddressChanged(_stabilityPoolAddress);
        emit DefaultPoolAddressChanged(_defaultPoolAddress);
    }

    // --- Getters for public variables. Required by IPool interface ---

    /*
    * Returns the DFI state variable.
    *
    *Not necessarily equal to the the contract's raw DFI balance - DFI can be forcibly sent to contracts.
    */
    function getETH() external view override returns (uint) {
        return DFI;
    }

    function getMUSDDebt() external view override returns (uint) {
        return MUSDDebt;
    }

    // --- Pool functionality ---

    function sendETH(address _account, uint _amount) external override {
		require(!paused, "ActivePool is paused.");

        _requireCallerIsBOorTroveMorSP();
        DFI = DFI.sub(_amount);
        emit ActivePoolETHBalanceUpdated(DFI);
        emit EtherSent(_account, _amount);

        (bool success, ) = _account.call{ value: _amount }("");
        require(success, "ActivePool: sending DFI failed");
    }

    function increaseMUSDDebt(uint _amount) external override {
		require(!paused, "ActivePool is paused.");

        _requireCallerIsBOorTroveM();
        MUSDDebt  = MUSDDebt.add(_amount);
        ActivePoolMUSDDebtUpdated(MUSDDebt);
    }

    function decreaseMUSDDebt(uint _amount) external override {
		require(!paused, "ActivePool is paused.");

        _requireCallerIsBOorTroveMorSP();
        MUSDDebt = MUSDDebt.sub(_amount);
        ActivePoolMUSDDebtUpdated(MUSDDebt);
    }

    // --- 'require' functions ---

    function _requireCallerIsBorrowerOperationsOrDefaultPool() internal view {
        require(
            msg.sender == borrowerOperationsAddress ||
            msg.sender == defaultPoolAddress,
            "ActivePool: Caller is neither BO nor Default Pool");
    }

    function _requireCallerIsBOorTroveMorSP() internal view {
        require(
            msg.sender == borrowerOperationsAddress ||
            msg.sender == troveManagerAddress ||
            msg.sender == stabilityPoolAddress,
            "ActivePool: Caller is neither BorrowerOperations nor TroveManager nor StabilityPool");
    }

    function _requireCallerIsBOorTroveM() internal view {
        require(
            msg.sender == borrowerOperationsAddress ||
            msg.sender == troveManagerAddress,
            "ActivePool: Caller is neither BorrowerOperations nor TroveManager");
    }

    // --- Fallback function ---

    receive() external payable {
        _requireCallerIsBorrowerOperationsOrDefaultPool();
        DFI = DFI.add(msg.value);
        emit ActivePoolETHBalanceUpdated(DFI);
    }

	// --- MetaLend ---
	
	function pause(bool _paused) external onlyOwner {
		paused = _paused;
	}

	function renounceOwnership() external onlyOwner {
        _renounceOwnership();
    }
}
