// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../MLEND/MLENDToken.sol";

contract MLENDTokenTester is MLENDToken {
    constructor
    (
        address _communityIssuanceAddress, 
        address _mlendStakingAddress,
        address _lockupFactoryAddress,
        address _bountyAddress,
        address _lpRewardsAddress,
        address _multisigAddress
    ) 
        public 
        MLENDToken 
    (
        _communityIssuanceAddress,
        _mlendStakingAddress,
        _lockupFactoryAddress,
        _bountyAddress,
        _lpRewardsAddress,
        _multisigAddress
    )
    {} 

    function unprotectedMint(address account, uint256 amount) external {
        // No check for the caller here

        _mint(account, amount);
    }

    function unprotectedSendToMLENDStaking(address _sender, uint256 _amount) external {
        // No check for the caller here
        
        _transfer(_sender, mlendStakingAddress, _amount);
    }

    function callInternalApprove(address owner, address spender, uint256 amount) external returns (bool) {
        _approve(owner, spender, amount);
    }

    function callInternalTransfer(address sender, address recipient, uint256 amount) external returns (bool) {
        _transfer(sender, recipient, amount);
    }

    function getChainId() external pure returns (uint256 chainID) {
        //return _chainID(); // it’s private
        assembly {
            chainID := chainid()
        }
    }
}