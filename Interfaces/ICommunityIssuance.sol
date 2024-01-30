// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface ICommunityIssuance { 
    
    // --- Events ---
    
    event MLENDTokenAddressSet(address _mlendTokenAddress);
    event StabilityPoolAddressSet(address _stabilityPoolAddress);
    event TotalMLENDIssuedUpdated(uint _totalMLENDIssued);

    // --- Functions ---

    function setAddresses(address _mlendTokenAddress, address _stabilityPoolAddress, address _mlendIssuanceAddress) external;

    function issueMLEND() external returns (uint);

    function sendMLEND(address _account, uint _MLENDamount) external;
}
