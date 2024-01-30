// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../MLEND/MLENDStaking.sol";


contract MLENDStakingTester is MLENDStaking {
    function requireCallerIsTroveManager() external view {
        _requireCallerIsTroveManager();
    }
}
