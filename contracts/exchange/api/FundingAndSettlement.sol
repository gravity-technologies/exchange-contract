// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";
import "../types/PositionMap.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";
import "../common/Error.sol";
import "./BaseContract.sol";

contract FundingAndSettlement is BaseContract {
  using BIMath for BI;

  function _fundAndSettle(SubAccount storage sub) internal {
    _fundPerp(sub);
    _settleOptionsOrFutures(sub, sub.futures);
    _settleOptionsOrFutures(sub, sub.options);
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
    int64 fundingTime = state.prices.fundingTime;
    int64 newSpotBalance = int64(sub.spotBalances[quoteCurrency]);
    uint len = keys.length;
    for (uint i; i < len; ++i) {
      bytes32 assetID = keys[i];
      int64 latestFundingIndex = fundingIndex[assetID];
      Position storage perp = perps.values[assetID];
      int256 fundingIndexChange = int256(latestFundingIndex - perp.lastAppliedFundingIndex);
      if (fundingIndexChange == 0) {
        continue;
      }
      // Funding (11.2): fundingPayment = fundingIndexChange * positionSize
      BI memory perpBalance = BI(perp.balance, _getCurrencyDecimal(assetGetUnderlying(assetID)));
      fundingPayment = fundingPayment.add(BI(fundingIndexChange, PRICE_DECIMALS)).mul(perpBalance).scale(qdec);
      perp.lastAppliedFundingIndex = latestFundingIndex;
      newSpotBalance += fundingPayment.toInt64(qdec);
    }
    require(newSpotBalance >= 0, ERR_UNDERFLOW);
    sub.spotBalances[quoteCurrency] = newSpotBalance;
    sub.lastAppliedFundingTimestamp = fundingTime;
  }

  // TEMPORARY COMMENTED OUT - TO FIX SETTLEMENT LOGIC IN NEXT PR
  function _settleOptionsOrFutures(SubAccount storage sub, PositionsMap storage positions) internal {
    // uint64 qdec = _getCurrencyDecimal(sub.quoteCurrency);
    // BI memory newSubBalance = BI(int64(sub.spotBalances[sub.quoteCurrency]), qdec);
    // bytes32[] storage positionMapKeys = positions.keys;
    // mapping(bytes32 => Position) storage positionValues = positions.values;
    // uint positionLen = positionMapKeys.length;
    // int64 stateTimestamp = state.timestamp;
    // for (uint i; i < positionLen; ++i) {
    //   bytes32 assetID = positionMapKeys[i];
    //   (uint64 settlePrice, bool found) = _getAssetSettlementPrice(stateTimestamp, assetID);
    //   if (!found) {
    //     continue;
    //   }
    //   remove(positions, assetID);
    //   if (settlePrice == 0) {
    //     continue;
    //   }
    //   BI memory posBalance = BI(positionValues[assetID].balance, _getCurrencyDecimal(assetGetUnderlying(assetID)));
    //   newSubBalance = newSubBalance.add(posBalance.mul(BI(int256(uint256(settlePrice)), PRICE_DECIMALS)));
    // }
    // sub.spotBalances[sub.quoteCurrency] = newSubBalance.toInt64(qdec);
  }

  function _getAssetSettlementPrice(int64 timestamp, bytes32 assetID) private returns (uint64, bool) {
    if (assetGetExpiration(assetID) <= timestamp) {
      return (0, true);
    }
    uint64 storedPrice = state.prices.settlement[assetID];
    if (storedPrice != 0) {
      return (storedPrice, true);
    }

    (uint64 settlementPrice, bool found) = _getSettlementPrice9Decimals(assetID);
    state.prices.settlement[assetID] = settlementPrice;
    return (settlementPrice, found);
  }

  function _getSettlementPrice9Decimals(bytes32 assetID) private view returns (uint64, bool) {
    Kind kind = assetGetKind(assetID);
    Asset memory asset = parseAssetID(assetID);
    (uint64 futPrice, bool found) = _getFutureSettlementPrice9Decimals(asset.underlying, asset.quote, asset.expiration);

    if (kind == Kind.FUTURES) {
      return (futPrice, found);
    } else if (kind == Kind.CALL) {
      int64 callPrice = BI(int256(uint256(futPrice)), PRICE_DECIMALS)
        .sub(BI(int256(uint256(asset.strikePrice)), _getCurrencyDecimal(asset.quote)))
        .toInt64(PRICE_DECIMALS);
      if (callPrice < 0) {
        return (0, true);
      }
      return (uint64(callPrice), true);
    } else if (kind == Kind.PUT) {
      int64 putPrice = BI(int256(uint256(asset.strikePrice)), _getCurrencyDecimal(asset.quote))
        .sub(BI(int256(uint256(futPrice)), PRICE_DECIMALS))
        .toInt64(PRICE_DECIMALS);
      if (putPrice < 0) {
        return (0, true);
      }
      return (uint64(putPrice), true);
    }

    // Should never reach here
    revert(ERR_NOT_FOUND);
  }

  function _getFutureSettlementPrice9Decimals(
    Currency underlying,
    Currency quote,
    int64 expiry
  ) private view returns (uint64, bool) {
    (uint64 underlyingPrice, bool underlyingFound) = _getCurrencySettlementPrice9Decimals(underlying, expiry);
    if (!underlyingFound) {
      return (0, false);
    }
    (uint64 quotePrice, bool quoteFound) = _getCurrencySettlementPrice9Decimals(quote, expiry);
    if (!quoteFound) {
      return (0, false);
    }
    require(quotePrice != 0, ERR_DIV_BY_ZERO);
    return (uint64(underlyingPrice / quotePrice), true);
  }

  function _getCurrencySettlementPrice9Decimals(Currency currency, int64 expiry) private view returns (uint64, bool) {
    Asset memory asset = Asset({
      kind: Kind.SETTLEMENT,
      underlying: currency,
      quote: currency,
      expiration: expiry,
      strikePrice: 0
    });
    uint64 price = state.prices.settlement[assetToID(asset)];
    return (price, price != 0);
  }
}
