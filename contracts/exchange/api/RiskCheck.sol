// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "../types/DataStructure.sol";
import "../util/Asset.sol";

contract RiskCheck is BaseContract {
  error InvalidTotalValue(uint64 subAccountID, int256 value);

  /// @dev return the total value of a sub account with 18 decimal places
  function _getSubAccountUsdValue(SubAccount storage sub) internal view returns (int128) {
    bytes32 currencyID = _getCurrencyAssetID(sub.quoteCurrency);
    // upcasting price from int64 -> int128 is safe
    int128 balanceUsd = int128(uint128(sub.spotBalances[sub.quoteCurrency])) *
      int128(uint128(state.prices.mark[currencyID]));
    return
      balanceUsd +
      _getPositionsUsdValue(sub.perps) +
      _getPositionsUsdValue(sub.futures) +
      _getPositionsUsdValue(sub.options);
  }

  // FIXME: return the correct asset encoding of quote currency
  function _getCurrencyAssetID(Currency c) internal pure returns (bytes32) {
    if (c == Currency.ETH) return 0x0;
    if (c == Currency.BTC) return 0x0;
    if (c == Currency.USDC) return 0x0;
    if (c == Currency.USDT) return 0x0;
    require(false, "invalid currency");
    return 0;
  }

  function _requireValidSubAccountUsdValue(SubAccount storage sub) internal view {
    int128 val = _getSubAccountUsdValue(sub);
    if (val < 0) revert InvalidTotalValue(sub.id, val);
  }

  function _getPositionsUsdValue(PositionsMap storage positions) internal view returns (int128) {
    int128 total;
    bytes32[] storage keys = positions.keys;
    mapping(bytes32 => Position) storage values = positions.values;
    mapping(bytes32 => uint64) storage assetPrices = state.prices.mark;

    uint count = keys.length;
    for (uint i; i < count; ++i) {
      Position storage pos = values[keys[i]];
      total += int128(uint128(assetPrices[pos.id])) * int128(pos.balance);
    }
    return total;
  }
}
