// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";
import "../types/PositionMap.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";
import "./BaseContract.sol";

contract FundingAndSettlement is BaseContract {
  using BIMath for BI;

  function _fundAndSettle(int64 timestamp, SubAccount storage sub) internal {
    _fundPerp(sub);
    _settleOptionsOrFutures(sub, sub.options);
    _settleOptionsOrFutures(sub, sub.futures);
  }

  function _fundPerp(SubAccount storage sub) internal {
    // Skip Funding, since it has already been applied
    if (sub.lastAppliedFundingTimestamp == state.prices.fundingTime) {
      return;
    }

    Currency quoteCurrency = sub.quoteCurrency;
    mapping(bytes32 => int64) storage fundingIndex = state.prices.fundingIndex;
    uint64 qdec = _getCurrencyDecimal(quoteCurrency);
    PositionsMap storage perps = sub.perps;
    BI memory fundingPayment;

    bytes32[] storage keys = perps.keys;
    uint len = keys.length;
    for (uint i; i < len; ++i) {
      bytes32 assetID = keys[i];
      int64 latestFundingIndex = fundingIndex[assetID];
      Position storage perp = perps.values[assetID];
      Currency underlying = assetGetUnderlying(assetID);
      uint64 underlyingDecimals = _getCurrencyDecimal(underlying);

      uint fundingIndexChange = uint256(int256(latestFundingIndex - perp.lastAppliedFundingIndex));
      if (fundingIndexChange == 0) {
        continue;
      }

      // Funding (11.2): fundingPayment = fundingIndexChange * positionSize
      BI memory perpBalance = BI(perp.balance, underlyingDecimals);
      fundingPayment = fundingPayment.add(BI(int256(fundingIndexChange), priceDecimal)).mul(perpBalance).scale(qdec);
      perp.lastAppliedFundingIndex = latestFundingIndex;
      int64 newSpotBalance = int64(sub.spotBalances[quoteCurrency]) + fundingPayment.toInt64(qdec);
      require(newSpotBalance >= 0, ERR_BALANCE_UNDERFLOW);
      sub.spotBalances[quoteCurrency] = uint64(newSpotBalance);
      sub.lastAppliedFundingTimestamp = state.prices.fundingTime;
    }
  }

  function _settleOptionsOrFutures(SubAccount storage sub, PositionsMap storage positions) internal {}
}
