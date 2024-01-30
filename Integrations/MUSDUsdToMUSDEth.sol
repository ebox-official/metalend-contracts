// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;

import "../Dependencies/Ownable.sol";


interface IPriceFeed {
    function latestAnswer() external view returns (int256);
}


contract MUSDUsdToMUSDEth is Ownable, IPriceFeed {
    // IPriceFeed public constant MUSD_USD = IPriceFeed(0x3D7aE7E594f2f2091Ad8798313450130d0Aba3a0);
    // IPriceFeed public constant ETH_USD = IPriceFeed(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
	IPriceFeed public MUSD_USD = IPriceFeed(0x3D7aE7E594f2f2091Ad8798313450130d0Aba3a0);
    IPriceFeed public ETH_USD = IPriceFeed(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    constructor() public {}

    function latestAnswer() external view override returns (int256) {
        return (MUSD_USD.latestAnswer() * 1 ether) / ETH_USD.latestAnswer();
    }

	// --- MetaLend ---

	function setData(IPriceFeed _MUSD_USD, IPriceFeed _DFI_USD) external onlyOwner {
		MUSD_USD = _MUSD_USD;
		ETH_USD = _DFI_USD;
	}

	function renounceOwnership() external onlyOwner {
        _renounceOwnership();
    }
}
