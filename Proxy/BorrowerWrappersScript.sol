// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/SafeMath.sol";
import "../Dependencies/LiquityMath.sol";
import "../Dependencies/IERC20.sol";
import "../Interfaces/IBorrowerOperations.sol";
import "../Interfaces/ITroveManager.sol";
import "../Interfaces/IStabilityPool.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/IMLENDStaking.sol";
import "./BorrowerOperationsScript.sol";
import "./ETHTransferScript.sol";
import "./MLENDStakingScript.sol";
import "../Dependencies/console.sol";


contract BorrowerWrappersScript is BorrowerOperationsScript, ETHTransferScript, MLENDStakingScript {
    using SafeMath for uint;

    string constant public NAME = "BorrowerWrappersScript";

    ITroveManager immutable troveManager;
    IStabilityPool immutable stabilityPool;
    IPriceFeed immutable priceFeed;
    IERC20 immutable musdToken;
    IERC20 immutable mlendToken;
    IMLENDStaking immutable mlendStaking;

    constructor(
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _mlendStakingAddress
    )
        BorrowerOperationsScript(IBorrowerOperations(_borrowerOperationsAddress))
        MLENDStakingScript(_mlendStakingAddress)
        public
    {
        checkContract(_troveManagerAddress);
        ITroveManager troveManagerCached = ITroveManager(_troveManagerAddress);
        troveManager = troveManagerCached;

        IStabilityPool stabilityPoolCached = troveManagerCached.stabilityPool();
        checkContract(address(stabilityPoolCached));
        stabilityPool = stabilityPoolCached;

        IPriceFeed priceFeedCached = troveManagerCached.priceFeed();
        checkContract(address(priceFeedCached));
        priceFeed = priceFeedCached;

        address musdTokenCached = address(troveManagerCached.musdToken());
        checkContract(musdTokenCached);
        musdToken = IERC20(musdTokenCached);

        address mlendTokenCached = address(troveManagerCached.mlendToken());
        checkContract(mlendTokenCached);
        mlendToken = IERC20(mlendTokenCached);

        IMLENDStaking mlendStakingCached = troveManagerCached.mlendStaking();
        require(_mlendStakingAddress == address(mlendStakingCached), "BorrowerWrappersScript: Wrong MLENDStaking address");
        mlendStaking = mlendStakingCached;
    }

    function claimCollateralAndOpenTrove(uint _maxFee, uint _MUSDAmount, address _upperHint, address _lowerHint) external payable {
        uint balanceBefore = address(this).balance;

        // Claim collateral
        borrowerOperations.claimCollateral();

        uint balanceAfter = address(this).balance;

        // already checked in CollSurplusPool
        assert(balanceAfter > balanceBefore);

        uint totalCollateral = balanceAfter.sub(balanceBefore).add(msg.value);

        // Open trove with obtained collateral, plus collateral sent by user
        borrowerOperations.openTrove{ value: totalCollateral }(_maxFee, _MUSDAmount, _upperHint, _lowerHint);
    }

    function claimSPRewardsAndRecycle(uint _maxFee, address _upperHint, address _lowerHint) external {
        uint collBalanceBefore = address(this).balance;
        uint mlendBalanceBefore = mlendToken.balanceOf(address(this));

        // Claim rewards
        stabilityPool.withdrawFromSP(0);

        uint collBalanceAfter = address(this).balance;
        uint mlendBalanceAfter = mlendToken.balanceOf(address(this));
        uint claimedCollateral = collBalanceAfter.sub(collBalanceBefore);

        // Add claimed ETH to trove, get more MUSD and stake it into the Stability Pool
        if (claimedCollateral > 0) {
            _requireUserHasTrove(address(this));
            uint MUSDAmount = _getNetMUSDAmount(claimedCollateral);
            borrowerOperations.adjustTrove{ value: claimedCollateral }(_maxFee, 0, MUSDAmount, true, _upperHint, _lowerHint);
            // Provide withdrawn MUSD to Stability Pool
            if (MUSDAmount > 0) {
                stabilityPool.provideToSP(MUSDAmount, address(0));
            }
        }

        // Stake claimed MLEND
        uint claimedMLEND = mlendBalanceAfter.sub(mlendBalanceBefore);
        if (claimedMLEND > 0) {
            mlendStaking.stake(claimedMLEND);
        }
    }

    function claimStakingGainsAndRecycle(uint _maxFee, address _upperHint, address _lowerHint) external {
        uint collBalanceBefore = address(this).balance;
        uint musdBalanceBefore = musdToken.balanceOf(address(this));
        uint mlendBalanceBefore = mlendToken.balanceOf(address(this));

        // Claim gains
        mlendStaking.unstake(0);

        uint gainedCollateral = address(this).balance.sub(collBalanceBefore); // stack too deep issues :'(
        uint gainedMUSD = musdToken.balanceOf(address(this)).sub(musdBalanceBefore);

        uint netMUSDAmount;
        // Top up trove and get more MUSD, keeping ICR constant
        if (gainedCollateral > 0) {
            _requireUserHasTrove(address(this));
            netMUSDAmount = _getNetMUSDAmount(gainedCollateral);
            borrowerOperations.adjustTrove{ value: gainedCollateral }(_maxFee, 0, netMUSDAmount, true, _upperHint, _lowerHint);
        }

        uint totalMUSD = gainedMUSD.add(netMUSDAmount);
        if (totalMUSD > 0) {
            stabilityPool.provideToSP(totalMUSD, address(0));

            // Providing to Stability Pool also triggers MLEND claim, so stake it if any
            uint mlendBalanceAfter = mlendToken.balanceOf(address(this));
            uint claimedMLEND = mlendBalanceAfter.sub(mlendBalanceBefore);
            if (claimedMLEND > 0) {
                mlendStaking.stake(claimedMLEND);
            }
        }

    }

    function _getNetMUSDAmount(uint _collateral) internal returns (uint) {
        uint price = priceFeed.fetchPrice();
        uint ICR = troveManager.getCurrentICR(address(this), price);

        uint MUSDAmount = _collateral.mul(price).div(ICR);
        uint borrowingRate = troveManager.getBorrowingRateWithDecay();
        uint netDebt = MUSDAmount.mul(LiquityMath.DECIMAL_PRECISION).div(LiquityMath.DECIMAL_PRECISION.add(borrowingRate));

        return netDebt;
    }

    function _requireUserHasTrove(address _depositor) internal view {
        require(troveManager.getTroveStatus(_depositor) == 1, "BorrowerWrappersScript: caller must have an active trove");
    }
}
