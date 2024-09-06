// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "../types/DataStructure.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";

contract RiskCheck is BaseContract {
  using BIMath for BI;

  error InvalidTotalValue(uint64 subAccountID, int256 value);

  function _requireNonNegativeUsdValue(SubAccount storage sub) internal view {
    require(_getSubAccountUsdValue(sub).val >= 0, "invalid total value");
  }

  /// @dev Get the total value of a sub account in quote currency decimal
  function _getSubAccountUsdValue(SubAccount storage sub) internal view returns (BI memory) {
    BI memory totalValue = _getPositionsUsdValue(sub.perps).add(_getPositionsUsdValue(sub.futures)).add(
      _getPositionsUsdValue(sub.options)
    );

    for (Currency i = currencyStart(); currencyIsValid(i); i = currencyNext(i)) {
      int64 balance = sub.spotBalances[i];
      if (balance == 0) {
        continue;
      }
      BI memory balanceBI = BI(int256(balance), _getBalanceDecimal(i));
      bytes32 spotID = _getSpotAssetID(i);
      totalValue = totalValue.add(balanceBI.mul(_requireMarkPriceBI(spotID)));
    }

    return totalValue;
  }

  /// @dev Get the total value of a position collections
  function _getPositionsUsdValue(PositionsMap storage positions) internal view returns (BI memory) {
    BI memory total;
    bytes32[] storage keys = positions.keys;
    mapping(bytes32 => Position) storage values = positions.values;

    uint count = keys.length;
    for (uint i; i < count; ++i) {
      Position storage pos = values[keys[i]];
      bytes32 assetWithUSDQuote = assetSetQuote(pos.id, Currency.USD);
      BI memory markPrice = _requireMarkPriceBI(assetWithUSDQuote);
      uint64 uDec = _getBalanceDecimal(assetGetUnderlying(assetWithUSDQuote));
      BI memory balance = BI(int256(pos.balance), uDec);
      total = total.add(balance.mul(markPrice));
    }
    return total;
  }
}
