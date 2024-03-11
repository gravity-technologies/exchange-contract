// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "../types/DataStructure.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";

contract RiskCheck is BaseContract {
  using BIMath for BI;

  error InvalidTotalValue(uint64 subAccountID, int256 value);

  function _requireValidSubAccountUsdValue(SubAccount storage sub) internal view {
    BI memory val = _getSubAccountUsdValue(sub);
    if (val.val < 0) revert InvalidTotalValue(sub.id, val.toInt256(_getCurrencyDecimal(sub.quoteCurrency)));
  }

  function _getSubAccountUsdValue(SubAccount storage sub) internal view returns (BI memory) {
    bytes32 spotID = _getSpotAssetID(sub.quoteCurrency);
    (uint64 markPrice, bool found) = _getMarkPrice9Decimals(spotID);
    require(found, ERR_NOT_FOUND);
    BI memory balanceUsd = BI(int(uint(sub.spotBalances[sub.quoteCurrency])), _getCurrencyDecimal(sub.quoteCurrency))
      .mul(BI(int(uint(markPrice)), PRICE_DECIMALS));
    return
      balanceUsd.add(_getPositionsUsdValue(sub.perps)).add(_getPositionsUsdValue(sub.futures)).add(
        _getPositionsUsdValue(sub.options)
      );
  }

  function _getPositionsUsdValue(PositionsMap storage positions) internal view returns (BI memory) {
    BI memory total;
    bytes32[] storage keys = positions.keys;
    mapping(bytes32 => Position) storage values = positions.values;

    uint count = keys.length;
    for (uint i; i < count; ++i) {
      Position storage pos = values[keys[i]];
      (uint64 markPrice, bool found) = _getMarkPrice9Decimals(pos.id);
      require(found, ERR_NOT_FOUND);
      uint64 underlyingDecimals = _getCurrencyDecimal(assetGetUnderlying(pos.id));
      total = total.add(BI(int(uint(markPrice)), PRICE_DECIMALS)).mul(BI(int256(pos.balance), underlyingDecimals));
    }
    return total;
  }
}
