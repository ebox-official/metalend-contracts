// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Interfaces/IMUSDToken.sol";

contract MUSDTokenCaller {
    IMUSDToken MUSD;

    function setMUSD(IMUSDToken _MUSD) external {
        MUSD = _MUSD;
    }

    function musdMint(address _account, uint _amount) external {
        MUSD.mint(_account, _amount);
    }

    function musdBurn(address _account, uint _amount) external {
        MUSD.burn(_account, _amount);
    }

    function musdSendToPool(address _sender,  address _poolAddress, uint256 _amount) external {
        MUSD.sendToPool(_sender, _poolAddress, _amount);
    }

    function musdReturnFromPool(address _poolAddress, address _receiver, uint256 _amount ) external {
        MUSD.returnFromPool(_poolAddress, _receiver, _amount);
    }
}
