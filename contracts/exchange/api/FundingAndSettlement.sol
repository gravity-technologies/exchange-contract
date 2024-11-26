pragma solidity ^0.8.20;

import "../types/DataStructure.sol";
import "../types/PositionMap.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";
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
    int64 fundingTime = state.prices.fundingTime;
    if (sub.lastAppliedFundingTimestamp == fundingTime) {
      return;
    }

    Currency quoteCurrency = sub.quoteCurrency;
    uint64 qdec = _getBalanceDecimal(quoteCurrency);
    PositionsMap storage perps = sub.perps;
    BI memory fundingPayment;

    bytes32[] storage keys = perps.keys;
    uint len = keys.length;
    for (uint i; i < len; ++i) {
      bytes32 assetID = keys[i];
      int64 latestFundingIndex = state.prices.fundingIndex[assetID];
      Position storage perp = perps.values[assetID];
      int256 fundingIndexChange = latestFundingIndex - perp.lastAppliedFundingIndex;
      if (fundingIndexChange == 0) {
        continue;
      }
      // Funding (11.2): fundingPayment = fundingIndexChange * positionSize
      fundingPayment = fundingPayment.add(_getPerpFundingPayment(assetID, perp, fundingIndexChange));
      perp.lastAppliedFundingIndex = latestFundingIndex;
    }
    sub.spotBalances[quoteCurrency] -= fundingPayment.toInt64(qdec);
    sub.lastAppliedFundingTimestamp = fundingTime;
  }

  function _getPerpFundingPayment(
    bytes32 assetID,
    Position storage perp,
    int256 fundingIndexChange
  ) internal view returns (BI memory) {
    Currency underlying = assetGetUnderlying(assetID);
    Currency quote = assetGetQuote(assetID);

    uint64 uDec = _getBalanceDecimal(underlying);
    uint64 qDec = _getBalanceDecimal(quote);

    BI memory payment = BI(fundingIndexChange, PRICE_DECIMALS).mul(BI(perp.balance, uDec));

    if (payment.isPositive()) {
      BI memory paymentPad = BI(int(uint(_getBalanceMultiplier(quote))), 0);
      return payment.mul(paymentPad).roundUp().div(paymentPad).scale(qDec);
    }

    return payment.scale(qDec);
  }

  struct SettmentEntry {
    bytes32 assetID;
    uint64 settlePrice;
  }

  function _settleOptionsOrFutures(SubAccount storage sub, PositionsMap storage positions) internal {
    uint64 qdec = _getBalanceDecimal(sub.quoteCurrency);
    BI memory newSubBalance = BI(sub.spotBalances[sub.quoteCurrency], qdec);
    bytes32[] storage posKeys = positions.keys;
    mapping(bytes32 => Position) storage posValues = positions.values;
    uint posLen = posKeys.length;

    SettmentEntry[] memory settlements = new SettmentEntry[](posLen);
    uint settlementCount = 0;
    for (uint i; i < posLen; ++i) {
      bytes32 assetID = posKeys[i];
      (uint64 settlePrice, bool found) = _getAssetSettlementPrice(assetID);
      if (!found) {
        continue;
      }
      settlements[settlementCount] = SettmentEntry(assetID, settlePrice);
      settlementCount++;
    }

    for (uint i = 0; i < settlementCount; i++) {
      SettmentEntry memory entry = settlements[i];
      int64 positionBalance = posValues[entry.assetID].balance;
      remove(positions, entry.assetID);
      if (entry.settlePrice == 0) {
        continue;
      }

      BI memory posBalance = BI(positionBalance, _getBalanceDecimal(assetGetUnderlying(entry.assetID)));
      newSubBalance = newSubBalance.add(posBalance.mul(BI(int256(uint256(entry.settlePrice)), PRICE_DECIMALS)));
    }
    sub.spotBalances[sub.quoteCurrency] = newSubBalance.toInt64(qdec);
  }

  function _getAssetSettlementPrice(bytes32 assetID) private returns (uint64, bool) {
    SettlementPriceEntry storage entry = state.prices.settlement[assetID];

    if (entry.isSet) {
      return (entry.value, true);
    }

    (uint64 settlementPrice, bool found) = _getSettlementPrice9Dec(assetID);
    if (!found) {
      return (0, false);
    }
    state.prices.settlement[assetID] = SettlementPriceEntry(true, settlementPrice);
    return (settlementPrice, true);
  }

  function _getSettlementPrice9Dec(bytes32 assetID) internal view returns (uint64, bool) {
    Kind kind = assetGetKind(assetID);
    if (kind == Kind.SPOT || kind == Kind.PERPS) {
      return (0, false);
    }

    Asset memory asset = parseAssetID(assetID);
    (uint64 fPrice, bool found) = _getFutureSettlementPrice9Dec(asset.underlying, asset.quote, asset.expiration);
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

  function _getFutureSettlementPrice9Dec(
    Currency underlying,
    Currency quote,
    int64 expiry
  ) private view returns (uint64, bool) {
    (uint64 uPrice, bool underlyingFound) = _getCurrencySettlementPrice9Dec(underlying, expiry);
    if (!underlyingFound) {
      return (0, false);
    }
    (uint64 qPrice, bool quoteFound) = _getCurrencySettlementPrice9Dec(quote, expiry);
    if (!quoteFound) {
      return (0, false);
    }
    // Just panic when the quote price is 0
    return (
      BI(int(uint(uPrice)), PRICE_DECIMALS).div(BI(int(uint(qPrice)), PRICE_DECIMALS)).toUint64(PRICE_DECIMALS),
      true
    );
  }

  function _getCurrencySettlementPrice9Dec(Currency currency, int64 expiry) private view returns (uint64, bool) {
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
