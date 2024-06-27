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

      uint64 dec = _getBalanceDecimal(i);
      BI memory balanceBI = BI(int256(balance), dec);

      bytes32 spotID = _getSpotAssetID(i);
      (uint64 markPrice, bool found) = _getMarkPrice9Decimals(spotID);

      require(found, ERR_NOT_FOUND);

      BI memory markPriceBI = BI(int256(uint256(markPrice)), PRICE_DECIMALS);
      BI memory balanceValue = balanceBI.mul(markPriceBI);

      totalValue = totalValue.add(balanceValue);
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
      (uint64 markPrice, bool found) = _getMarkPrice9Decimals(pos.id);
      require(found, ERR_NOT_FOUND);
      uint64 uDec = _getBalanceDecimal(assetGetUnderlying(pos.id));
      BI memory balance = BI(int256(pos.balance), uDec);
      BI memory markPriceBI = BI(int(uint(markPrice)), PRICE_DECIMALS);
      total = total.add(markPriceBI.mul(balance));
    }
    return total;
  }
}
