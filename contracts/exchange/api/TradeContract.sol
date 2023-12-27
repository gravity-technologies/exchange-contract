// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseTradeContract.sol";
import "./ConfigContract.sol";
import "./signature/generated/TradeSig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";
import "../util/Trade.sol";

abstract contract TradeContract is ConfigContract, BaseTradeContract {
  function tradeDeriv(int64 timestamp, uint64 txID, Trade calldata trade) external nonReentrant {
    _updateTradeContext(trade.tradeContext);

    // TODO perp funding and settlement

    // TODO update position and spot balances
    SubAccount storage taker = _requireSubAccount(trade.takerOrder.subAccountID);
    uint makerCount = trade.makerOrders.length;
    for (uint i = 0; i < makerCount; ++i) {
      uint256 takerSpotDelta = 0;
      uint256 makerSpotDelta = 0;
      OrderMatch calldata makerMatch = trade.makerOrders[i];
      Order calldata makerOrder = makerMatch.makerOrder;
      SubAccount storage maker = _requireSubAccount(makerOrder.subAccountID);

      if (
        makerOrder.timeInForce == TimeInForce.ALL_OR_NONE || makerOrder.timeInForce == TimeInForce.IMMEDIATE_OR_CANCEL
      ) {
        uint256 orderPrice = makerOrder.limitPrice;
        if (makerOrder.isPayingBaseCurrency) {
          makerSpotDelta -= orderPrice;
          takerSpotDelta += orderPrice;
        } else {
          makerSpotDelta += orderPrice;
          takerSpotDelta -= orderPrice;
        }
      }
    }

    // deposit fees
  }

  function _updateTradeContext(AssetTradeContext[] calldata tradeContext) internal {
    uint count = tradeContext.length;
    PriceState storage prices = state.prices;
    for (uint i = 0; i < count; ++i) {
      AssetTradeContext calldata ctx = tradeContext[i];
      prices.mark[ctx.assetID] = ctx.markPrice;
      // FIXME: update the correct mark price and interest rate for underlying
      // prices.mark[ctx.assetID] = ctx.underlyingPrice;
      // prices.interest[ctx.assetID] = ctx.riskFreeRate;
    }
  }
}
