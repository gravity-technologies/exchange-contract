// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseTradeContract.sol";
import "./ConfigContract.sol";
import "./signature/generated/TradeSig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";
import "../util/Trade.sol";
import "../util/Asset.sol";

struct MatchedSize {
  uint256 assetID;
  uint64[] matchedSizes;
}

abstract contract TradeContract is ConfigContract, BaseTradeContract {
  /// FIXME: this currently has a few deficiencies:
  /// 1. Assuming that both are transacting USDT. For now, we only support USDT, it is fine.
  /// However, we should account for the fact that maker and taker subaccount currency might be different
  /// 2. For AON/IOC order, we assumed that the quote currency is USDT
  function tradeDeriv(int64 timestamp, uint64 txID, Trade calldata trade) external nonReentrant {
    _updatePricesFromTradeContext(trade.tradeContext);

    // TODO perp funding and settlement

    // TODO update position and spot balances
    mapping(bytes32 => mapping(uint256 => uint64)) storage matchedSizes = state.replay.sizeMatched;
    SubAccount storage taker = _requireSubAccount(trade.takerOrder.subAccountID);
    Order calldata takerOrder = trade.takerOrder;
    bytes32 takerHash = hashOrder(takerOrder);
    uint makerCount = trade.makerOrders.length;
    for (uint i; i < makerCount; ++i) {
      uint256 takerSpotDelta;
      uint256 makerSpotDelta;
      OrderMatch calldata makerMatch = trade.makerOrders[i];
      Order calldata makerOrder = makerMatch.makerOrder;
      bytes32 makerHash = hashOrder(makerOrder);
      SubAccount storage maker = _requireSubAccount(makerOrder.subAccountID);

      bool isWholeOrder = makerOrder.timeInForce == TimeInForce.ALL_OR_NONE ||
        makerOrder.timeInForce == TimeInForce.IMMEDIATE_OR_CANCEL;
      if (isWholeOrder) {
        uint256 orderPrice = makerOrder.limitPrice;
        if (makerOrder.isPayingBaseCurrency) {
          makerSpotDelta -= orderPrice;
          takerSpotDelta += orderPrice;
        } else {
          makerSpotDelta += orderPrice;
          takerSpotDelta -= orderPrice;
        }
      }

      uint legCount = makerOrder.legs.length;
      for (uint j; j < legCount; ++j) {
        int64 curSz = int64(makerMatch.matchedSize[j]);
        OrderLeg calldata leg = makerOrder.legs[j];
        uint64 preSz = matchedSizes[makerHash][leg.assetID];
        uint64 totalSz = preSz + uint64(curSz);

        // validate
        require((isWholeOrder && totalSz == leg.size) || (!isWholeOrder && totalSz <= leg.size), "invalid maker size");
        if (curSz == 0) {
          continue;
        }

        // FIXME fixed point math
        // update taker and maker size
        matchedSizes[takerHash][leg.assetID] += uint64(curSz);
        matchedSizes[makerHash][leg.assetID] = totalSz;
        AssetDTO memory asset = assetIDtoDTO(leg.assetID);
        uint64 legQuoteDecimals = _getCurrencyDecimal(asset.quote);
        uint64 legUnderlyingDecimals = _getCurrencyDecimal(asset.underlying);
        uint64 legPrice = leg.limitPrice;
        uint256 legValue = legPrice * uint64(curSz);

        // FIXME
        Position storage takerPos = taker.perps.values[leg.assetID];
        Position storage makerPos = maker.perps.values[leg.assetID];
        if (leg.isBuyingAsset) {
          takerPos.balance -= curSz;
          makerPos.balance += curSz;
          if (!isWholeOrder) {
            takerSpotDelta += legValue;
            makerSpotDelta -= legValue;
          }
        } else {
          takerPos.balance += curSz;
          makerPos.balance -= curSz;
          if (!isWholeOrder) {
            takerSpotDelta -= legValue;
            makerSpotDelta += legValue;
          }
        }

        if (takerPos.balance == 0) {
          removePos(taker, takerPos.id);
        }
        if (makerPos.balance == 0) {
          removePos(taker, takerPos.id);
        }
      }

      // Update spot balances for taker and maker
      uint64 decimals = _getCurrencyDecimal(taker.quoteCurrency);
      uint64 oldTakerSpot = taker.spotBalances[taker.quoteCurrency];
      uint64 newTakerSpot = oldTakerSpot + uint64(takerSpotDelta);
      taker.spotBalances[taker.quoteCurrency] = newTakerSpot;

      uint64 oldMakerSpot = maker.spotBalances[maker.quoteCurrency];
      uint64 newMakerSpot = oldMakerSpot + uint64(makerSpotDelta);
      maker.spotBalances[maker.quoteCurrency] = newMakerSpot;
    }

    // Verify taker matched sizes
    uint takerLegCount = takerOrder.legs.length;
    bool isTakerWholeOrder = takerOrder.timeInForce == TimeInForce.ALL_OR_NONE ||
      trade.takerOrder.timeInForce == TimeInForce.IMMEDIATE_OR_CANCEL;
    for (uint i; i < takerLegCount; ++i) {
      OrderLeg calldata leg = takerOrder.legs[i];
      uint64 matchedSize = matchedSizes[takerHash][leg.assetID];
      require(
        (isTakerWholeOrder && matchedSize == leg.size) || (!isTakerWholeOrder && matchedSize <= leg.size),
        "invalid taker size"
      );
    }

    // deposit fees
    uint64 fee = 0;
    _depositFee(fee);
  }

  function _depositFee(uint64 fee) private {}

  function removePos(SubAccount storage sub, uint256 assetID) internal {
    Kind kind = assetGetKind(assetID);
    if (kind == Kind.PERPS) {
      remove(sub.perps, assetID);
    } else if (kind == Kind.FUTURES) {
      remove(sub.futures, assetID);
    } else if (kind == Kind.CALL || kind == Kind.PUT) {
      remove(sub.options, assetID);
    }
  }

  function _updatePricesFromTradeContext(AssetTradeContext[] calldata tradeContext) internal {
    uint count = tradeContext.length;
    PriceState storage prices = state.prices;
    for (uint i; i < count; ++i) {
      AssetTradeContext calldata ctx = tradeContext[i];
      prices.mark[ctx.assetID] = ctx.markPrice;
      // FIXME: update the correct mark price and interest rate for underlying
      // prices.mark[ctx.assetID] = ctx.underlyingPrice;
      // prices.interest[ctx.assetID] = ctx.riskFreeRate;
    }
  }

  function _getCurrencyDecimal(Currency currency) internal pure returns (uint64) {
    if (currency == Currency.ETH || currency == Currency.BTC) {
      return 9;
    } else if (currency == Currency.USDC || currency == Currency.USDT) {
      return 6;
    } else {
      revert("unsupported currency");
    }
  }
}
