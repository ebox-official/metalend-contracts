// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/CheckContract.sol";
import "../Dependencies/Ownable.sol";
import "../Dependencies/SafeMath.sol";
import "../Interfaces/IMLENDToken.sol";
//import "../Interfaces/ILockupContractFactory.sol";
//import "../Dependencies/console.sol";


contract MLENDToken is CheckContract, Ownable, IMLENDToken {
    using SafeMath for uint256;

    // --- ERC20 Data ---

    string constant internal _NAME = "MetaLend Token";
    string constant internal _SYMBOL = "MLEND";
    uint8 constant internal  _DECIMALS = 18;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    uint private _totalSupply;

    // --- MLENDToken specific data ---

    // uint for use with SafeMath
    uint internal _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24

    uint public immutable deploymentStartTime;
    address public immutable multisigAddress;

    address public communityIssuanceAddress;
    address public mlendStakingAddress;

    uint public constant lpRewardsEntitlement = 0;

    // --- Events ---

    event CommunityIssuanceAddressSet(address _communityIssuanceAddress);
    event MLENDStakingAddressSet(address _mlendStakingAddress);
    event LockupContractFactoryAddressSet(address _lockupContractFactoryAddress);

    // --- Functions ---

    constructor
    (
		address,
        address,
        address,
        address,
        address,
        address
    ) 
        public 
    {
        multisigAddress = msg.sender;
        deploymentStartTime  = block.timestamp;
             
        uint deployerEntitlement = _1_MILLION.mul(100);
        _mint(msg.sender, deployerEntitlement);
    }

    // --- External functions ---

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function getDeploymentStartTime() external view override returns (uint256) {
        return deploymentStartTime;
    }

    function getLpRewardsEntitlement() external view override returns (uint256) {
        return lpRewardsEntitlement;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _requireValidRecipient(recipient);

        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _requireValidRecipient(recipient);

        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external override returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external override returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function sendToMLENDStaking(address _sender, uint256 _amount) external override {
        _requireCallerIsMLENDStaking();
        _transfer(_sender, mlendStakingAddress, _amount);
    }

    // --- Internal operations ---

    function _chainID() private pure returns (uint256 chainID) {
        assembly {
            chainID := chainid()
        }
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    // --- Helper functions ---

    function _callerIsMultisig() internal view returns (bool) {
        return (msg.sender == multisigAddress);
    }

	  function _isFirstYear() internal pure returns (bool) {
		return false;
    }

    // --- 'require' functions ---
    
    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && 
            _recipient != address(this),
            "MLEND: Cannot transfer tokens directly to the MLEND token contract or the zero address"
        );
    }

    function _requireCallerIsMLENDStaking() internal view {
         require(msg.sender == mlendStakingAddress, "MLENDToken: caller must be the MLENDStaking contract");
    }

    // --- Optional functions ---

    function name() external view override returns (string memory) {
        return _NAME;
    }

    function symbol() external view override returns (string memory) {
        return _SYMBOL;
    }

    function decimals() external view override returns (uint8) {
        return _DECIMALS;
    }

	// --- MetaLend ---

	function renounceOwnership() external onlyOwner {
        _renounceOwnership();
    }
	
	function setAddresses(address _communityIssuanceAddress, address _mlendStakingAddress) external onlyOwner {
		checkContract(_communityIssuanceAddress);
        checkContract(_mlendStakingAddress);
       
        communityIssuanceAddress = _communityIssuanceAddress;
        mlendStakingAddress = _mlendStakingAddress;

		emit CommunityIssuanceAddressSet(communityIssuanceAddress);
    	emit MLENDStakingAddressSet(mlendStakingAddress);
	}
}
