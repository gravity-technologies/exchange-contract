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

  function _fundAndSettle(int64 timestamp, SubAccount storage sub) internal {
    _fundPerp(sub);
    _settleOptionsOrFutures(timestamp, sub, sub.futures);
    _settleOptionsOrFutures(timestamp, sub, sub.options);
  }

  function _fundPerp(SubAccount storage sub) internal {
    // Skip Funding, since it has already been applied
    if (sub.lastAppliedFundingTimestamp == state.prices.fundingTime) {
      return;
    }

    Currency quoteCurrency = sub.quoteCurrency;
    mapping(bytes32 => int64) storage fundingIndex = state.prices.fundingIndex;
    uint64 qdec = _getBalanceDecimal(quoteCurrency);
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
      BI memory perpBalance = BI(perp.balance, _getBalanceDecimal(assetGetUnderlying(assetID)));
      fundingPayment = fundingPayment.add(BI(fundingIndexChange, PRICE_DECIMALS)).mul(perpBalance).scale(qdec);
      perp.lastAppliedFundingIndex = latestFundingIndex;
      newSpotBalance += fundingPayment.toInt64(qdec);
    }
    require(newSpotBalance >= 0, ERR_UNDERFLOW);
    sub.spotBalances[quoteCurrency] = newSpotBalance;
    sub.lastAppliedFundingTimestamp = fundingTime;
  }

  function _settleOptionsOrFutures(int64 timestamp, SubAccount storage sub, PositionsMap storage positions) internal {
    uint64 qdec = _getBalanceDecimal(sub.quoteCurrency);
    BI memory newSubBalance = BI(int64(sub.spotBalances[sub.quoteCurrency]), qdec);
    bytes32[] storage posKeys = positions.keys;
    mapping(bytes32 => Position) storage posValues = positions.values;
    uint posLen = posKeys.length;
    for (uint i; i < posLen; ++i) {
      bytes32 assetID = posKeys[i];
      (uint64 settlePrice, bool found) = _getAssetSettlementPrice(timestamp, assetID);
      if (!found) {
        continue;
      }
      remove(positions, assetID);
      if (settlePrice == 0) {
        continue;
      }
      BI memory posBalance = BI(posValues[assetID].balance, _getBalanceDecimal(assetGetUnderlying(assetID)));
      newSubBalance = newSubBalance.add(posBalance.mul(BI(int256(uint256(settlePrice)), PRICE_DECIMALS)));
    }
    sub.spotBalances[sub.quoteCurrency] = newSubBalance.toInt64(qdec);
  }

  function _getAssetSettlementPrice(int64 timestamp, bytes32 assetID) private returns (uint64, bool) {
    if (assetGetExpiration(assetID) <= timestamp) {
      return (0, false);
    }
    SettlementPriceEntry storage entry = state.prices.settlement[assetID];
    if (entry.isSet) {
      return (entry.value, true);
    }

    (uint64 settlementPrice, bool found) = _getSettlementPrice9Decimals(assetID);
    if (!found) {
      return (0, false);
    }
    state.prices.settlement[assetID] = SettlementPriceEntry(true, settlementPrice);
    return (settlementPrice, true);
  }

  function _getSettlementPrice9Decimals(bytes32 assetID) internal view returns (uint64, bool) {
    Kind kind = assetGetKind(assetID);
    if (kind == Kind.SPOT || kind == Kind.PERPS) {
      return (0, false);
    }

    Asset memory asset = parseAssetID(assetID);
    (uint64 fPrice, bool found) = _getFutureSettlementPrice9Decimals(asset.underlying, asset.quote, asset.expiration);
    if (!found) {
      return (0, false);
    }

    if (kind == Kind.FUTURES) {
      return (fPrice, found);
    }

    if (kind == Kind.CALL) {
      return (fPrice > asset.strikePrice ? fPrice - asset.strikePrice : 0, true);
    }

    if (kind == Kind.PUT) {
      return (fPrice < asset.strikePrice ? asset.strikePrice - fPrice : 0, true);
    }

    return (0, false);
  }

  function _getFutureSettlementPrice9Decimals(
    Currency underlying,
    Currency quote,
    int64 expiry
  ) private view returns (uint64, bool) {
    (uint64 uPrice, bool underlyingFound) = _getCurrencySettlementPrice9Decimals(underlying, expiry);
    if (!underlyingFound) {
      return (0, false);
    }
    (uint64 qPrice, bool quoteFound) = _getCurrencySettlementPrice9Decimals(quote, expiry);
    if (!quoteFound) {
      return (0, false);
    }
    // Just panic when the quote price is 0
    return (uPrice / qPrice, true);
  }

  function _getCurrencySettlementPrice9Decimals(Currency currency, int64 expiry) private view returns (uint64, bool) {
    Asset memory asset = Asset({
      kind: Kind.SETTLEMENT,
      underlying: currency,
      quote: Currency.USD,
      expiration: expiry,
      strikePrice: 0
    });
    SettlementPriceEntry storage price = state.prices.settlement[assetToID(asset)];
    return (price.value, price.isSet);
  }
}
