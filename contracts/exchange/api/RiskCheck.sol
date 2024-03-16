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
    bytes32 spotID = _getSpotAssetID(sub.quoteCurrency);
    (uint64 markPrice, bool found) = _getMarkPrice9Decimals(spotID);
    require(found, ERR_NOT_FOUND);
    BI memory derivVal = _getPositionsUsdValue(sub.perps).add(_getPositionsUsdValue(sub.futures)).add(
      _getPositionsUsdValue(sub.options)
    );
    uint qDec = _getBalanceDecimal(sub.quoteCurrency);

    // TODO: go through all supported currency
    BI memory spotVal = BI(int(sub.spotBalances[sub.quoteCurrency]), qDec).mul(
      BI(int(uint(markPrice)), PRICE_DECIMALS)
    );
    return spotVal.add(derivVal);
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
