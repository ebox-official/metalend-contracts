// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import './Interfaces/IDefaultPool.sol';
import "./Dependencies/SafeMath.sol";
import "./Dependencies/Ownable.sol";
import "./Dependencies/CheckContract.sol";
import "./Dependencies/console.sol";

/*
 * The Default Pool holds the DFI and MUSD debt (but not MUSD tokens) from liquidations that have been redistributed
 * to active troves but not yet "applied", i.e. not yet recorded on a recipient active trove's struct.
 *
 * When a trove makes an operation that applies its pending DFI and MUSD debt, its pending DFI and MUSD debt is moved
 * from the Default Pool to the Active Pool.
 */
contract DefaultPool is Ownable, CheckContract, IDefaultPool {
    using SafeMath for uint256;

    string constant public NAME = "DefaultPool";

    address public troveManagerAddress;
    address public activePoolAddress;
    uint256 internal DFI;  // deposited DFI tracker
    uint256 internal MUSDDebt;  // debt

	bool public paused = false;

    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event DefaultPoolMUSDDebtUpdated(uint _MUSDDebt);
    event DefaultPoolETHBalanceUpdated(uint _ETH);

    // --- Dependency setters ---

    function setAddresses(
        address _troveManagerAddress,
        address _activePoolAddress
    )
        external
        onlyOwner
    {
        checkContract(_troveManagerAddress);
        checkContract(_activePoolAddress);

        troveManagerAddress = _troveManagerAddress;
        activePoolAddress = _activePoolAddress;

        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);
    }

    // --- Getters for public variables. Required by IPool interface ---

    /*
    * Returns the DFI state variable.
    *
    * Not necessarily equal to the the contract's raw DFI balance - DFI can be forcibly sent to contracts.
    */
    function getETH() external view override returns (uint) {
        return DFI;
    }

    function getMUSDDebt() external view override returns (uint) {
        return MUSDDebt;
    }

    // --- Pool functionality ---

    function sendETHToActivePool(uint _amount) external override {
		require(!paused, "DefaultPool is paused.");

        _requireCallerIsTroveManager();
        address activePool = activePoolAddress; // cache to save an SLOAD
        DFI = DFI.sub(_amount);
        emit DefaultPoolETHBalanceUpdated(DFI);
        emit EtherSent(activePool, _amount);

        (bool success, ) = activePool.call{ value: _amount }("");
        require(success, "DefaultPool: sending DFI failed");
    }

    function increaseMUSDDebt(uint _amount) external override {
		require(!paused, "DefaultPool is paused.");

        _requireCallerIsTroveManager();
        MUSDDebt = MUSDDebt.add(_amount);
        emit DefaultPoolMUSDDebtUpdated(MUSDDebt);
    }

    function decreaseMUSDDebt(uint _amount) external override {
		require(!paused, "DefaultPool is paused.");

        _requireCallerIsTroveManager();
        MUSDDebt = MUSDDebt.sub(_amount);
        emit DefaultPoolMUSDDebtUpdated(MUSDDebt);
    }

    // --- 'require' functions ---

    function _requireCallerIsActivePool() internal view {
        require(msg.sender == activePoolAddress, "DefaultPool: Caller is not the ActivePool");
    }

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == troveManagerAddress, "DefaultPool: Caller is not the TroveManager");
    }

    // --- Fallback function ---

    receive() external payable {
        _requireCallerIsActivePool();
        DFI = DFI.add(msg.value);
        emit DefaultPoolETHBalanceUpdated(DFI);
    }
	
	// --- MetaLend ---

	function pause(bool _paused) external onlyOwner {
		paused = _paused;
	}

	function renounceOwnership() external onlyOwner {
        _renounceOwnership();
    }
}
