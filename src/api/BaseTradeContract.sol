// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./HelperContract.sol";
import "../types/DataStructure.sol";

contract BaseTradeContract is HelperContract {
  error InvalidTotalValue(address subAccountID, int256 value);

  /// @dev return the total value of a sub account
  function _getUsdValue(SubAccount storage sub) internal view returns (int256) {
    return sub.balance + _getPositionsPnl(sub.perps) + _getPositionsPnl(sub.futures) + _getPositionsPnl(sub.options);
  }

  function _requireValidTotalValue(SubAccount storage sub) internal view {
    int256 val = _getUsdValue(sub);
    if (val < 0) {
      revert InvalidTotalValue(sub.id, val);
    }
  }

  function _getPositionsPnl(DerivativeCollection storage positions) internal view returns (int256) {
    int256 pnl = 0;
    uint128[] storage keys = positions.keys;
    mapping(uint128 => DerivativePosition) storage values = positions.values;
    uint count = keys.length;
    for (uint i = 0; i < count; i++) {
      DerivativePosition storage pos = values[keys[i]];
      int256 price = int256(uint256(state.PriceState.Derivative[pos.id]));
      pnl += (price - int128(pos.averageEntryPrice)) * int128(pos.contractBalance);
    }
    return pnl;
  }

  function _perpFunding(SubAccount storage sub) internal {
    uint128[] storage keys = sub.perps.keys;
    mapping(uint128 => DerivativePosition) storage values = sub.perps.values;
    uint count = keys.length;
    int128 balanceDelta;
    for (uint i = 0; i < count; i++) {
      DerivativePosition storage perp = values[keys[i]];
      // Upcasting from uint64 -> int128 is safe
      int128 price = int128(uint128(state.prices.derivatives[perp.id]));
      // Upcasting from uint64 -> int128 is safe
      int128 lastPerpPrice = int128(uint128(perp.lastAppliedFundingIndex));
      balanceDelta += (price - lastPerpPrice) * perp.contractBalance;
    }
    sub.balance += balanceDelta;
  }

  // TODO
  function _getInterestRate(uint128 id) internal view returns (uint64) {
    return state.prices.interestRates[id];
  }

  function _settleOptions(sub storage SubAccount) internal {}

  function _settleFutures(sub storage SubAccount) internal {}

  function _perpFundingAndSettleFuturesOptions(sub storage SubAccount) internal {
    _perpFunding(sub);
    _settleFutures(sub);
    _settleOptions(sub);
  }
}
