// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/CheckContract.sol";
import "../Interfaces/IMLENDStaking.sol";


contract MLENDStakingScript is CheckContract {
    IMLENDStaking immutable MLENDStaking;

    constructor(address _mlendStakingAddress) public {
        checkContract(_mlendStakingAddress);
        MLENDStaking = IMLENDStaking(_mlendStakingAddress);
    }

    function stake(uint _MLENDamount) external {
        MLENDStaking.stake(_MLENDamount);
    }
}
