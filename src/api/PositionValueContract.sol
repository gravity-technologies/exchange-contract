// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./HelperContract.sol";
import "./OracleContract.sol";
import "../DataStructure.sol";

contract PositionValueContract is HelperContract, OracleContract {
  /// @dev return the total value of a sub account
  function _getTotalValue(SubAccount storage sub) internal view returns (int256) {
    return sub.balance + _getPositionsPnl(sub.perps) + _getPositionsPnl(sub.futures) + _getPositionsPnl(sub.options);
  }

  function _getPositionsPnl(DerivativeCollection storage positions) internal view returns (int256) {
    int256 pnl = 0;
    uint128[] storage keys = positions.keys;
    mapping(uint128 => DerivativePosition) storage values = positions.values;
    uint count = keys.length;
    for (uint i = 0; i < count; i++) {
      DerivativePosition storage pos = values[keys[i]];
      int256 price = int256(_getDerivPrice(pos.id));
      pnl += (price - int128(pos.averageEntryPrice)) * int128(pos.contractBalance);
    }
    return pnl;
  }
}
