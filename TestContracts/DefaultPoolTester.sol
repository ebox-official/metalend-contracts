// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../DefaultPool.sol";

contract DefaultPoolTester is DefaultPool {
    
    function unprotectedIncreaseMUSDDebt(uint _amount) external {
        MUSDDebt  = MUSDDebt.add(_amount);
    }

    function unprotectedPayable() external payable {
        DFI = DFI.add(msg.value);
    }
}
