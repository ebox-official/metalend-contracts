// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../ActivePool.sol";

contract ActivePoolTester is ActivePool {
    
    function unprotectedIncreaseMUSDDebt(uint _amount) external {
        MUSDDebt  = MUSDDebt.add(_amount);
    }

    function unprotectedPayable() external payable {
        DFI = DFI.add(msg.value);
    }
}
