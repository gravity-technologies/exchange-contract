// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseTradeContract.sol";
import "./ConfigContract.sol";
import "./signature/generated/TradeSig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";
import "../util/Trade.sol";

abstract contract TradeContract is ConfigContract, BaseTradeContract {
  /**
   * @notice Trade derivatives between 2 subaccounts
   * 1.	Verify signature
   * 2.	Verify trade info
   * 3. Verify that taker and maker have permission to trade on the subaccount
   * 4. Lazily perform perpetual funding to update balances of both taker and makers
   * 5. Update position balances involved in the trade
   * 6. Update collateral balances for each subaccount
   * 7. Collect fees from taker and makers into the GRVT subaccount
   * 8. Prevent replay and update order fulfillment status
   * 9. Perform total value check for taker and makers. If it fails, revert all changes.
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param trade the trade payload
   */
  function derivativeTrade(uint64 timestamp, uint64 txID, Trade calldata trade) public nonReentrant {
    _setSequence(timestamp, txID);

    // Validation
    _verifySignatureAndPermissions(trade);
    _verifyOrders(trade);
    _verifyOrderFulfilment(trade);
    _verifyFees(trade);

    SubAccount storage taker = _requireSubAccount(trade.takerOrder.subAccountID);
    _updatePositionAndCollateralBalance(trade, taker);

    // TODO: deduct fees from taker and makers. Deposit fees into GRVT subaccount.
    // Revisit after we finalized fee validation method
    uint128 fee = 0;
    _depositFee(fee);

    // Run total value check for taker and each maker
    _verifyValidTotalValue(taker, trade.makerOrders);
  }

  function _updatePositionAndCollateralBalance(Trade calldata trade, SubAccount storage taker) private {
    _fundAndSettle(taker);
    uint numLegs = trade.takerOrder.legs.length;
    for (uint i = 0; i < trade.makerOrders.length; ++i) {
      OrderMatch calldata matching = trade.makerOrders[i];
      Order calldata order = matching.makerOrder;
      SubAccount storage maker = _requireSubAccount(order.subAccountID);
      _fundAndSettle(maker);

      uint64[] calldata numAssetsMatched = matching.numAssetsMatched;
      for (uint j = 0; j < numLegs; ++j) {
        OrderLeg calldata leg = order.legs[j];
        // TODO: check if numAssetMatched should be limited to 2^63, because need downcasting from uint64 -> int64
        int64 positionDelta = int64(numAssetsMatched[j]);
        int128 legPriceE9 = int128(uint128(leg.limitPrice));
        int128 assetQty = int128(uint128(numAssetsMatched[j]));
        int128 balanceDeltaE9 = legPriceE9 * assetQty;
        // deduct collateral and increase asset balance
        taker.balanceE9 -= balanceDeltaE9;
        maker.balanceE9 += balanceDeltaE9;
        getPosition(taker, leg.assetID).balance += positionDelta;
        getPosition(maker, leg.assetID).balance -= positionDelta;
      }
    }
  }

  /**
   * @dev Update balance of each leg
   * 1. Go through the list of maker orders to match
   * 2. For each maker match, iterate through each leg
   * 3. For each leg, update the balance of the maker and taker's corresponding position
   */
  // function _updateMakerFee(
  //   OrderMatch[] calldata matches,
  //   uint numLegs,
  //   Instrument instrument
  // ) internal returns (uint128) {
  //   uint128 fees;

  //   // uint128 takerMinLegFee = 1e30;
  //   // int128 takerFee = 0;

  //   // Maker:
  //   // compute fee for each maker leg, then find smallest fee.
  //   // give a discount of 50% (for future) or 100% (for option)
  //   //
  //   // Taker:
  //   // aggregate the taker fee for each leg. Update the smallest fee.
  //   // give a discount of 50% (for future) or 100% (for option)

  //   // Go through each makerOrderMatch
  //   for (uint i = 0; i < matches.length; i++) {
  //     int128 makerFee = 0;
  //     // Go through each leg matched qty
  //     // uint64[] calldata matchedAmounts = matches[i].numContractsMatched;
  //     int128 makerMinLegFee;
  //     // int128 takerMinLegFee;
  //     for (uint j = 0; j < numLegs; j++) {
  //       OrderLeg calldata leg = matches[i].makerOrder.legs[j];
  //       int128 legFee = _getLegFee(leg, matches[i].makerFeePercentageCharged);
  //       if (legFee < makerMinLegFee) makerMinLegFee = legFee;
  //       makerFee += legFee;

  //       // takerFee += _getLegFee(leg.assetID, int128(uint128(leg.size)), matches[i].takerFeePercentageCharged);
  //       // Update position balances
  //       // (int128 takerCollDelta, int128 makerCollDelta) = _updatePositionBalances(
  //       //   leg,
  //       //   _getPosition(taker, leg.assetID),
  //       //   _getPosition(maker, leg.assetID),
  //       //   qty
  //       // );

  //       // taker.balance += takerCollDelta - int128(takerFee);
  //       // maker.balance += makerCollDelta - int128(makerFee);
  //       // fees += takerFee + makerFee;
  //     }
  //     if (numLegs > 1 && makerMinLegFee > 0) {
  //       // give discount for the cheapest leg (unless that less receive maker rebate, then we give 100% maker rebate (ie no discount since the fee is negative))
  //       // if future/perp give 50% discount
  //       if (instrument == Instrument.PERPS || instrument == Instrument.FUTURES) makerFee -= makerMinLegFee / 2;
  //       else if (instrument == Instrument.CALL || instrument == Instrument.PUT) makerFee -= makerMinLegFee;
  //     }
  //     _requireSubAccount(matches[i].makerOrder.subAccountID).balance -= makerFee;
  //   }
  //   // if (numLegs > 1) {
  //   //   // give discount for the cheapest leg (unless that less receive maker rebate, then we give 100% maker rebate (ie no discount since the fee is negative))
  //   //   // if future/perp give 50% discount
  //   //   if (instrument == Instrument.PERPS || instrument == Instrument.FUTURES) takerFee -= takerMinLegFee / 2;
  //   //   else if (instrument == Instrument.CALL || instrument == Instrument.PUT) takerFee -= takerMinLegFee;
  //   // }

  //   return fees;
  // }

  // function _getLegFee(OrderLeg calldata leg, uint64 feePercent) internal view returns (int128) {
  //   Derivative memory deriv = _parseAssetID(leg.assetID);
  //   mapping(uint => int64) storage prices = state.prices.assets;
  //   int128 feePct = int128(uint128(feePercent));
  //   int128 assetPrice = int128(prices[leg.assetID]);
  //   int128 size = int128(uint128(leg.size));
  //   if (deriv.instrument == Instrument.PERPS || deriv.instrument == Instrument.FUTURES) {
  //     return (size * assetPrice * feePct) / 1e9;
  //   } else if (deriv.instrument == Instrument.CALL || deriv.instrument == Instrument.PUT) {
  //     int128 underlyingCharge = (size * prices[deriv.underlyingAssetID] * feePct) / 1e9;
  //     int128 premiumCap = size * assetPrice * 125e8;
  //     return underlyingCharge < premiumCap ? underlyingCharge : premiumCap;
  //   }
  //   require(false, "invalid instrument");
  //   return 0;
  // }

  function _depositFee(uint128 fee) private {
    _requireSubAccount(_getAddressCfg(CfgID.FEE_SUB_ACCOUNT_ID)).balanceE9 += int128(fee);
  }

  // ------------------------------------------------------
  // Verification
  // ------------------------------------------------------

  // Verify that the signatures are valid and that the taker and maker has permission to trade
  function _verifySignatureAndPermissions(Trade calldata trade) private view {
    Order calldata takerOrder = trade.takerOrder;
    uint64 timestamp = state.timestamp;
    _requireValidSig(timestamp, hashOrder(takerOrder), takerOrder.signature);

    // check that taker has permission to trade
    _requireTradePermission(takerOrder.signature.signer, takerOrder.subAccountID);

    uint numMakerOrders = trade.makerOrders.length;
    for (uint i = 0; i < numMakerOrders; i++) {
      Order calldata order = trade.makerOrders[i].makerOrder;
      _requireValidSig(timestamp, hashOrder(order), order.signature);

      // check that maker has permission to trade
      _requireTradePermission(order.signature.signer, order.subAccountID);
    }
  }

  function _requireTradePermission(address signer, address orderSubAccountID) private view {
    // If there's an existing session, the signer of the signature is a session key. We get the user from the session data
    // Otherwise the signer of the signature is an actual user
    address user;
    Session storage session = state.sessionToUser[signer];
    if (session.user == address(0)) user = signer;
    else {
      require(session.expiry < state.timestamp, "session expired");
      user = session.user;
    }

    _requirePermission(_requireSubAccount(orderSubAccountID), signer, SubAccountPermTrade);
  }

  function _verifyOrders(Trade calldata trade) private view {
    Order calldata takerOrder = trade.takerOrder;
    OrderMatch[] calldata matches = trade.makerOrders;
    uint numMakers = matches.length;
    require(numMakers > 0, "no maker orders");

    SubAccount storage taker = _requireSubAccount(takerOrder.subAccountID);

    _verifyOrder(taker, takerOrder, false);
    uint numLegs = takerOrder.legs.length;
    for (uint j = 0; j < numMakers; ++j) {
      OrderMatch calldata matching = matches[j];
      Order calldata makerOrder = matching.makerOrder;
      require(makerOrder.legs.length == numLegs, "inconsistent num legs");
      require(makerOrder.subAccountID != takerOrder.subAccountID, "self-trade");
      require(matching.makerFeePercentageCharged < makerOrder.makerFeePercentageCap, "invalid maker fee");
      require(matching.takerFeePercentageCharged < takerOrder.takerFeePercentageCap, "invalid taker fee");
      for (uint k = 0; k < numLegs; k++) require(matching.numAssetsMatched[k] > 0, "invalid qty");
      SubAccount storage maker = _requireSubAccount(makerOrder.subAccountID);
      _verifyOrder(maker, makerOrder, true);
    }
  }

  // TODO: optimization: precompute the signature and pass those around to save gas
  /// @dev If an order must be matched fully, verifies that the order can be only executed once
  /// If order can be partially matched, verifies that the order has not been fully matched (matchedQtySoFar < numMatchedAssets)
  function _verifyOrderFulfilment(Trade calldata trade) private {
    // 1. Each derivative must have a price
    Order calldata takerOrder = trade.takerOrder;
    OrderLeg[] calldata takerLegs = takerOrder.legs;
    uint numLegs = takerLegs.length;
    for (uint i = 0; i < numLegs; ++i)
      require(state.prices.assets[takerLegs[i].assetID] > 0, "invalid derivative price");

    // Store the total matched quantity for each leg. This is used to update the taker fulfilment status
    uint64[] memory totalQtyMatchedPerLeg = new uint64[](numLegs);

    // For maker: validate each maker leg qty and aggregate the total qty per leg (to be used later to compare with taker's)
    for (uint i = 0; i < trade.makerOrders.length; ++i) {
      OrderMatch calldata matched = trade.makerOrders[i];
      Order calldata makerOrder = matched.makerOrder;
      bytes32 matchedOrderID = hashOrder(makerOrder);
      uint64[] storage makerPreMatchedQty = _getOrInitMatchedOrderQty(matchedOrderID, numLegs);
      for (uint j = 0; j < numLegs; ++j) {
        uint64 curMatchedQty = matched.numAssetsMatched[j];
        uint64 totalMatchedQty = makerPreMatchedQty[j] + curMatchedQty;
        _verifyMatchedQty(makerOrder.timeInForce, totalMatchedQty, makerOrder.legs[j].size);
        totalQtyMatchedPerLeg[j] += curMatchedQty;

        // Update the matched qty for each maker order. It's safe to pre-update
        // the matched quantity here because if there's any error during trade,
        // all state updates will be rolled back
        makerPreMatchedQty[j] += curMatchedQty;
      }
    }

    // For taker
    bytes32 takerOrderID = hashOrder(takerOrder);
    uint64[] storage takerPreMatchedQty = _getOrInitMatchedOrderQty(takerOrderID, numLegs);
    for (uint i = 0; i < numLegs; ++i) {
      uint64 curMatchedQty = totalQtyMatchedPerLeg[i];
      uint64 totalMatchedQty = takerPreMatchedQty[i] + curMatchedQty;
      _verifyMatchedQty(takerOrder.timeInForce, totalMatchedQty, takerOrder.legs[i].size);
      // Pre-update the matched quantity
      takerPreMatchedQty[i] += curMatchedQty;
    }
  }

  function _getOrInitMatchedOrderQty(bytes32 orderID, uint numLegs) private returns (uint64[] storage) {
    uint64[] storage allLegsPreMatchedQty = state.signatures.orderMatched[orderID];
    // TODO: change this to a mapping to avoid pushing to storage
    if (allLegsPreMatchedQty.length == 0) {
      for (uint j = 0; j < numLegs; ++j) allLegsPreMatchedQty.push(0);
    }
    return allLegsPreMatchedQty;
  }

  function _verifyMatchedQty(TimeInForce tif, uint64 totalMatchedQty, uint64 maxLegQty) private pure {
    if (tif == TimeInForce.FILL_OR_KILL || tif == TimeInForce.ALL_OR_NONE)
      require(totalMatchedQty == maxLegQty, "expect full match");
    if (tif == TimeInForce.GOOD_TILL_TIME || tif == TimeInForce.IMMEDIATE_OR_CANCEL)
      require(totalMatchedQty <= maxLegQty, "insufficient qty");
    require(false, "tif not supported");
  }

  // Run total value check for taker and each maker
  function _verifyValidTotalValue(SubAccount storage taker, OrderMatch[] calldata matches) private view {
    _requireValidSubAccountUsdValue(taker);
    uint numMakerOrders = matches.length;
    for (uint i = 0; i < numMakerOrders; ++i)
      _requireValidSubAccountUsdValue(_requireSubAccount(matches[i].makerOrder.subAccountID));
  }

  // TODO: after we finalize fee verification method
  function _verifyFees(Trade calldata trade) private pure {}
}
