pragma solidity ^0.8.20;

import "./FundingAndSettlement.sol";
import "./RiskCheck.sol";
import "./ConfigContract.sol";
import "./signature/generated/TradeSig.sol";
import "../types/DataStructure.sol";
import "../common/Error.sol";
import "../util/BIMath.sol";
import "../util/Asset.sol";

abstract contract TradeContract is ConfigContract, FundingAndSettlement, RiskCheck {
  using BIMath for BI;

  int32 internal constant TRADE_FEE_CAP_RATE_BPS = 2000;
  // Liquidation Fee:
  // 0.25% = 25 bps on option index notional
  // 0.70% = 70 bps otherwise
  int32 internal constant LIQUIDATION_FEE_CAP_RATE_BPS_OPTION = 2500;
  int32 internal constant LIQUIDATION_FEE_CAP_RATE_BPS_OTHER = 7000;
  int32 internal constant PREMIUM_CAP_RATE_BPS = 125000; // 12.5% premium cap

  struct OrderCalculationResult {
    uint64[] matchedSizes;
    BI[] legSpotDelta;
    BI tradeNotional;
  }

  function tradeDeriv(
    int64 timestamp,
    uint64 txID,
    Trade calldata trade
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    _verifyMatch(trade);

    SubAccount storage takerSub = _requireSubAccount(trade.takerOrder.subAccountID);
    OrderCalculationResult memory takerCalcResult = _verifyAndExecuteMakerOrders(timestamp, trade, takerSub);

    _verifyAndExecuteOrder(timestamp, trade.takerOrder, takerCalcResult, false, trade.feeCharged, takerSub);
  }

  function _verifyAndExecuteMakerOrders(
    int64 timestamp,
    Trade calldata trade,
    SubAccount storage takerSub
  ) private returns (OrderCalculationResult memory) {
    OrderCalculationResult memory takerCalcResult;
    takerCalcResult.matchedSizes = new uint64[](trade.takerOrder.legs.length);
    takerCalcResult.legSpotDelta = new BI[](trade.takerOrder.legs.length);
    MakerTradeMatch[] calldata makerMatches = trade.makerOrders;
    uint matchesLen = makerMatches.length;

    for (uint i; i < matchesLen; ++i) {
      MakerTradeMatch calldata makerMatch = makerMatches[i];
      OrderCalculationResult memory makerCalcResult = _calculateMakerOrder(trade, makerMatch, takerCalcResult);
      _verifyAndExecuteOrder(timestamp, makerMatch.makerOrder, makerCalcResult, true, makerMatch.feeCharged, takerSub);
    }

    return takerCalcResult;
  }

  function _calculateMakerOrder(
    Trade calldata trade,
    MakerTradeMatch calldata makerMatch,
    OrderCalculationResult memory takerCalcResult
  ) private returns (OrderCalculationResult memory makerCalcResult) {
    makerCalcResult.matchedSizes = makerMatch.matchedSize;
    makerCalcResult.legSpotDelta = new BI[](makerMatch.makerOrder.legs.length);
    Order calldata makerOrder = makerMatch.makerOrder;

    for (uint legIdx; legIdx < makerMatch.makerOrder.legs.length; ++legIdx) {
      uint64 size = makerCalcResult.matchedSizes[legIdx];
      if (size == 0) {
        continue;
      }

      OrderLeg calldata leg = makerMatch.makerOrder.legs[legIdx];
      uint udec = _getBalanceDecimal(assetGetUnderlying(leg.assetID));
      uint qdec = _getBalanceDecimal(assetGetQuote(leg.assetID));
      BI memory tradeSize = BI(int256(uint256(size)), udec);
      BI memory notional = tradeSize.mul(BI(int256(uint256(leg.limitPrice)), PRICE_DECIMALS));

      // Here we agregate the maker's spot delta, maker's notional, taker spot delta and taker's matched sizes
      if (leg.isBuyingAsset) {
        makerCalcResult.legSpotDelta[legIdx] = makerCalcResult.legSpotDelta[legIdx].sub(notional);
        takerCalcResult.legSpotDelta[legIdx] = takerCalcResult.legSpotDelta[legIdx].add(notional);
      } else {
        makerCalcResult.legSpotDelta[legIdx] = makerCalcResult.legSpotDelta[legIdx].add(notional);
        takerCalcResult.legSpotDelta[legIdx] = takerCalcResult.legSpotDelta[legIdx].sub(notional);
      }

      makerCalcResult.tradeNotional = makerCalcResult.tradeNotional.add(notional);

      takerCalcResult.matchedSizes[_findLegIndex(trade.takerOrder.legs, leg.assetID)] += size;
    }

    // Aggregate taker notional accross all makers
    takerCalcResult.tradeNotional = takerCalcResult.tradeNotional.add(makerCalcResult.tradeNotional);

    return makerCalcResult;
  }

  /// @notice Verifies the match between 1 taker and multiple maker orders.
  /// @dev For individual order validation, see _verifyOrderFull.
  ///      This function only verifies the invariant of the trade.
  /// @param trade The trade details to be verified.
  function _verifyMatch(Trade calldata trade) private {
    Order calldata takerOrder = trade.takerOrder;

    // Store the temporary storage for trade validation. This should always be cleared after each trade
    uint takerLegsLen = takerOrder.legs.length;
    OrderLeg[] calldata takerLegs = takerOrder.legs;
    for (uint i = 0; i < takerLegsLen; ++i) {
      OrderLeg calldata leg = takerLegs[i];
      state._tmpTakerLegs[leg.assetID] = TmpLegData({
        limitPrice: leg.limitPrice,
        isBuyingAsset: leg.isBuyingAsset,
        isSet: true
      });
    }

    // Verify that the taker order legs are not matched to a worse price than the limit price
    for (uint i = 0; i < trade.makerOrders.length; ++i) {
      MakerTradeMatch calldata tradeMatch = trade.makerOrders[i];
      Order calldata makerOrder = tradeMatch.makerOrder;
      uint numLegs = makerOrder.legs.length;
      for (uint j = 0; j < numLegs; ++j) {
        OrderLeg calldata makerLeg = makerOrder.legs[j];
        uint64[] calldata matchedSizes = tradeMatch.matchedSize;
        require(matchedSizes.length == numLegs, ERR_INVALID_MATCHED_SIZE);
        TmpLegData storage takerLeg = state._tmpTakerLegs[makerLeg.assetID];

        if (!takerLeg.isSet) {
          require(matchedSizes[j] == 0, "matched against non-existent taker leg");
          continue;
        }
        require(takerLeg.isBuyingAsset != makerLeg.isBuyingAsset, "matched same side");

        if (!takerOrder.isMarket) {
          require(
            (takerLeg.isBuyingAsset && takerLeg.limitPrice >= makerLeg.limitPrice) ||
              (!takerLeg.isBuyingAsset && takerLeg.limitPrice <= makerLeg.limitPrice),
            "taker matched with bad price"
          );
        }
      }
    }

    // Clear the temporary storage
    for (uint i = 0; i < takerLegsLen; ++i) {
      delete (state._tmpTakerLegs[takerLegs[i].assetID]);
    }
  }

  function _verifyAndExecuteOrder(
    int64 timestamp,
    Order calldata order,
    OrderCalculationResult memory calcResult,
    bool isMakerOrder,
    int64[] memory feePerLegs,
    SubAccount storage takerSub
  ) private {
    SubAccount storage sub = isMakerOrder ? _requireSubAccount(order.subAccountID) : takerSub;
    int64 totalFee = _getTotalFee(feePerLegs);

    _verifyOrderFull(timestamp, sub, takerSub, order, calcResult, isMakerOrder, totalFee);

    // Fund and settle the subaccount before checking total value
    _fundAndSettle(sub);

    // Always allow non-liquidation orders that reduce position size
    // Liquidation orders must maintain subaccount above maintenance margin
    bool isReducingOrder = _isReducingOrder(sub, order);
    if (!order.isLiquidation && isReducingOrder) {
      _executeOrder(sub, order, calcResult, totalFee);
      return;
    }

    // Non-reducing order is subjected to margin check, ensuring sufficient balance pre and post trade
    _requireValidMargin(sub, order, true);
    // if reduce only flag is set, the order must be reducing size
    require(!order.reduceOnly || isReducingOrder, "invalid reduce order");
    _executeOrder(sub, order, calcResult, totalFee);
    _requireValidMargin(sub, order, false);
  }

  function _verifyOrderFull(
    int64 timestamp,
    SubAccount storage sub, // the sub account that created the order
    SubAccount storage takerSub,
    Order calldata order,
    OrderCalculationResult memory calcResult,
    bool isMakerOrder,
    int64 totalFee
  ) private {
    // Arrange from cheapest to most expensive verification
    Currency subQuote = sub.quoteCurrency;

    if (isMakerOrder) {
      require(subQuote == takerSub.quoteCurrency, ERR_MISMATCH_QUOTE_CURRENCY);
      require(sub.id != takerSub.id, "self trade");
      require(
        order.timeInForce != TimeInForce.IMMEDIATE_OR_CANCEL && order.timeInForce != TimeInForce.FILL_OR_KILL,
        "maker cannot be IOC/FOK"
      );
      require(!order.isMarket, "maker cannot be market order");
    } else {
      require(!order.postOnly, "taker cannot be post only");
    }

    // Check that quote asset is the same as subaccount quote asset
    uint qDec = _getBalanceDecimal(subQuote);

    OrderLeg[] calldata legs = order.legs;
    uint legsLen = legs.length;
    for (uint i; i < legsLen; ++i) {
      OrderLeg calldata leg = legs[i];
      Currency assetQuote = assetGetQuote(leg.assetID);
      Currency underlying = assetGetUnderlying(leg.assetID);
      Kind kind = assetGetKind(leg.assetID);
      require(assetQuote == subQuote, ERR_MISMATCH_QUOTE_CURRENCY);
      require(kind == Kind.PERPS, ERR_NOT_SUPPORTED);
      require(currencyCanHoldSpotBalance(assetQuote), ERR_NOT_SUPPORTED);
      require(currencyIsValid(underlying), ERR_NOT_SUPPORTED);
      int64 expiry = assetGetExpiration(leg.assetID);
    }

    // Check the order signature
    bytes32 orderHash = hashOrder(order);
    _requireValidSig(timestamp, orderHash, order.signature);

    // Check that the signer has trade permission
    Session storage session = state.sessions[order.signature.signer];

    // The signer is considered to have trade permission if any of the following is true:
    // - order's signer is in the session key map, and session hasn't expired, and the sessionKey's signer has trade permission
    // - order's signer has trade permission
    SubAccount storage permSub = sub;
    if (order.isLiquidation) {
      (permSub, ) = _getSubAccountFromUintConfig(ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID);
    }

    require(
      (session.expiry != 0 &&
        session.expiry >= timestamp &&
        hasSubAccountPermission(permSub, session.subAccountSigner, SubAccountPermTrade)) ||
        hasSubAccountPermission(permSub, order.signature.signer, SubAccountPermTrade),
      ERR_NO_TRADE_PERMISSION
    );

    // Check that the order's total matched size after this trade does not exceed the order size
    mapping(bytes32 => uint64) storage executedSize = state.replay.sizeMatched[orderHash];

    bool isWholeOrder = order.timeInForce == TimeInForce.ALL_OR_NONE || order.timeInForce == TimeInForce.FILL_OR_KILL;

    if (legsLen > 1) {
      bytes32[] memory seenAssetIDs = new bytes32[](legsLen);
      uint seenCount = 0;

      for (uint i; i < legsLen; ++i) {
        OrderLeg calldata leg = legs[i];

        for (uint j = 0; j < seenCount; ++j) {
          require(seenAssetIDs[j] != leg.assetID, "Duplicate assetID in legs");
        }
        seenAssetIDs[seenCount] = leg.assetID;
        seenCount++;
      }
    }

    for (uint i; i < legsLen; ++i) {
      OrderLeg calldata leg = legs[i];
      uint64 legExecutedSize = executedSize[leg.assetID];
      if (order.timeInForce == TimeInForce.IMMEDIATE_OR_CANCEL) {
        require(legExecutedSize == 0, "prior match for IOC order");
      }
      uint64 total = legExecutedSize + calcResult.matchedSizes[i];
      require(isWholeOrder ? total == leg.size : total <= leg.size, ERR_INVALID_MATCHED_SIZE);
      executedSize[leg.assetID] = total;
    }

    // Check that the fee paid is within the cap of 20 bps
    int32 feeCapRate = TRADE_FEE_CAP_RATE_BPS;
    if (order.isLiquidation) {
      feeCapRate = LIQUIDATION_FEE_CAP_RATE_BPS_OTHER;
    }
    BI memory feeCapRateBI = _bpsToDecimal(feeCapRate);
    int64 totalFeeCap = _calculateBaseFee(calcResult.tradeNotional, feeCapRateBI, qDec);

    require(totalFee <= totalFeeCap, ERR_FEE_CAP_EXCEEDED);
  }

  function _calculateBaseFee(BI memory notional, BI memory fee, uint qDec) private pure returns (int64) {
    if (notional.val == 0) return 0;
    return notional.mul(fee).toInt64(qDec);
  }

  function _executeOrder(
    SubAccount storage sub,
    Order calldata order,
    OrderCalculationResult memory calcResult,
    int64 fee
  ) private {
    Currency subQuote = sub.quoteCurrency;
    uint qDec = _getBalanceDecimal(subQuote);

    uint legsLen = order.legs.length;
    for (uint i; i < legsLen; ++i) {
      if (calcResult.matchedSizes[i] == 0) continue;
      OrderLeg calldata leg = order.legs[i];

      // Step 1: Retrieve position
      Position storage pos = _getOrCreatePosition(sub, leg.assetID);
      int64 posBalance = pos.balance;

      // Step 2: Update subaccount balances
      if (leg.isBuyingAsset) {
        pos.balance += SafeCast.toInt64(int(uint(calcResult.matchedSizes[i])));
      } else {
        pos.balance -= SafeCast.toInt64(int(uint(calcResult.matchedSizes[i])));
      }

      // Step 3: Remove position if empty
      if (pos.balance == 0) {
        removePos(sub, leg.assetID);
      }
    }

    int64 spotDelta = 0;
    for (uint i; i < legsLen; ++i) {
      spotDelta += calcResult.legSpotDelta[i].toInt64(qDec);
    }

    // Step 4: Update subaccount spot balance, deducting fees
    (SubAccount storage feeSub, bool isFeeCharged) = _getTradingFeeSubAccount(order.isLiquidation);
    if (isFeeCharged) {
      feeSub.spotBalances[subQuote] += fee;
      sub.spotBalances[subQuote] += spotDelta - fee;
    } else {
      sub.spotBalances[subQuote] += spotDelta;
    }
  }

  function removePos(SubAccount storage sub, bytes32 assetID) private {
    Kind kind = assetGetKind(assetID);
    if (kind == Kind.PERPS) {
      remove(sub.perps, assetID);
    } else if (kind == Kind.FUTURES) {
      remove(sub.futures, assetID);
    } else if (_isOption(kind)) {
      remove(sub.options, assetID);
    }
  }

  // FIXME: Our BE disables charging fees for now. To enable back afterwards
  function _getTotalFee(int64[] memory feePerLegs) private pure returns (int64) {
    int64 totalFee;
    uint len = feePerLegs.length;
    for (uint i; i < len; ++i) totalFee += feePerLegs[i];
    return totalFee;
  }

  function _findLegIndex(OrderLeg[] calldata legs, bytes32 assetID) private pure returns (uint) {
    uint len = legs.length;
    for (uint i; i < len; ++i) if (legs[i].assetID == assetID) return i;
    revert(ERR_NOT_FOUND);
  }

  function _isOption(Kind kind) private pure returns (bool) {
    return kind == Kind.CALL || kind == Kind.PUT;
  }

  function _isOption(bytes32 assetID) private pure returns (bool) {
    return _isOption(assetGetKind(assetID));
  }

  function _bpsToDecimal(int32 bps) private pure returns (BI memory) {
    return BI(bps, 6);
  }
}
