// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../MLEND/CommunityIssuance.sol";

contract CommunityIssuanceTester is CommunityIssuance {
    function obtainMLEND(uint _amount) external {
        mlendToken.transfer(msg.sender, _amount);
    }

    function getCumulativeIssuanceFraction() external view returns (uint) {
		return 0;
    }

    function unprotectedIssueMLEND() external returns (uint) {
		return 0;
    }
}
