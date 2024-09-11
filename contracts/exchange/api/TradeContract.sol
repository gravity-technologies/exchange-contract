// SPDX-License-Identifier: UNLICENSED
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

  function tradeDeriv(int64 timestamp, uint64 txID, Trade calldata trade) external {
    _setSequence(timestamp, txID);

    _verifyMatch(trade);

    Order calldata takerOrder = trade.takerOrder;
    OrderLeg[] calldata takerLegs = takerOrder.legs;
    uint64[] memory takerMatchedSizes = new uint64[](takerLegs.length);
    BI memory takerTradeNotional;
    BI memory takerOptionIndexNotional;
    BI memory takerSpotDelta;

    ///////////////////////////////////////////////////////////////////////////
    /// Maker order verification and execution
    ///
    /// We aggregate the notional values and matched sizes for taker in this
    /// loop here since we need the before we can verify / execute the taker order
    ///////////////////////////////////////////////////////////////////////////
    MakerTradeMatch[] calldata makerMatches = trade.makerOrders;
    uint matchesLen = makerMatches.length;
    SubAccount storage takerSub = _requireSubAccount(trade.takerOrder.subAccountID);

    for (uint i; i < matchesLen; ++i) {
      MakerTradeMatch calldata makerMatch = makerMatches[i];

      // Compute maker notional
      BI memory makerSpotDelta;
      BI memory makerTradeNotional;
      BI memory makerOptionIndexNotional;

      uint64[] calldata matchSizes = makerMatch.matchedSize;
      Order calldata makerOrder = makerMatch.makerOrder;
      uint makerLegsLen = makerOrder.legs.length;
      for (uint legIdx; legIdx < makerLegsLen; ++legIdx) {
        uint64 size = matchSizes[legIdx];
        if (size == 0) {
          continue;
        }

        OrderLeg calldata leg = makerOrder.legs[legIdx];
        uint udec = _getBalanceDecimal(assetGetUnderlying(leg.assetID));
        BI memory tradeSize = BI(int256(uint256(size)), udec);
        BI memory notional = tradeSize.mul(BI(int256(uint256(leg.limitPrice)), PRICE_DECIMALS));

        // Here we agregate the maker's spot delta, maker's notional, taker spot delta and taker's matched sizes
        if (leg.isBuyingAsset) {
          makerSpotDelta = makerSpotDelta.sub(notional);
          takerSpotDelta = takerSpotDelta.add(notional);
        } else {
          makerSpotDelta = makerSpotDelta.add(notional);
          takerSpotDelta = takerSpotDelta.sub(notional);
        }
        if (_isOption(leg.assetID)) {
          (uint64 indexPrice, bool found) = _getIndexPrice9Decimals(leg.assetID);
          require(found, ERR_NOT_FOUND);

          BI memory indexNotional = tradeSize.mul(BI(int(uint(indexPrice)), PRICE_DECIMALS));
          makerOptionIndexNotional = makerOptionIndexNotional.add(indexNotional);
        }
        makerTradeNotional = makerTradeNotional.add(notional);

        takerMatchedSizes[_findLegIndex(takerLegs, leg.assetID)] += size;
      }

      // Aggregate taker notional accross all makers
      takerTradeNotional = takerTradeNotional.add(makerTradeNotional);
      takerOptionIndexNotional = takerOptionIndexNotional.add(makerOptionIndexNotional);

      _verifyAndExecuteOrder(
        timestamp,
        makerMatch.makerOrder,
        makerMatch.matchedSize,
        true,
        makerSpotDelta,
        makerTradeNotional,
        makerOptionIndexNotional,
        makerMatch.feeCharged,
        takerSub
      );
    }

    ///////////////////////////////////////////////////////////////////
    /// Taker order verification and execution
    ///////////////////////////////////////////////////////////////////
    _verifyAndExecuteOrder(
      timestamp,
      takerOrder,
      takerMatchedSizes,
      false,
      takerSpotDelta,
      takerTradeNotional,
      takerOptionIndexNotional,
      trade.feeCharged,
      takerSub
    );
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

        require(takerLeg.isSet || matchedSizes[j] == 0, "matched against non-existent taker leg");
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
    uint64[] memory tradeSizes,
    bool isMakerOrder,
    BI memory spotDelta,
    BI memory tradeNotional,
    BI memory optionIndexNotional,
    int64[] memory feePerLegs,
    SubAccount storage takerSub
  ) private {
    SubAccount storage sub = isMakerOrder ? _requireSubAccount(order.subAccountID) : takerSub;
    int64 totalFee = _getTotalFee(feePerLegs);

    _verifyOrderFull(
      timestamp,
      sub,
      takerSub,
      order,
      tradeSizes,
      isMakerOrder,
      tradeNotional,
      optionIndexNotional,
      totalFee
    );

    // Fund and settle the subaccount before checking total value
    _fundAndSettle(sub);

    // Execute the order, ensuring sufficient balance pre and post trade
    _requireValidMargin(sub, order.isLiquidation, true);
    _executeOrder(sub, order, tradeSizes, spotDelta, totalFee);
    _requireValidMargin(sub, order.isLiquidation, false);
  }

  function _verifyOrderFull(
    int64 timestamp,
    SubAccount storage sub, // the sub account that created the order
    SubAccount storage takerSub,
    Order calldata order,
    uint64[] memory tradeSizes,
    bool isMakerOrder,
    BI memory tradeNotional,
    BI memory optionIndexNotional,
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
      require(assetQuote == subQuote, ERR_MISMATCH_QUOTE_CURRENCY);
      require(assetGetKind(leg.assetID) == Kind.PERPS, ERR_NOT_SUPPORTED);
      require(assetQuote == Currency.USDT, ERR_NOT_SUPPORTED);
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
      uint64 total = executedSize[leg.assetID] + tradeSizes[i];
      require(isWholeOrder ? total == leg.size : total <= leg.size, ERR_INVALID_MATCHED_SIZE);
      executedSize[leg.assetID] = total;
    }

    bool isOption = false;
    for (uint i; i < legsLen; ++i) {
      if (_isOption(legs[i].assetID)) {
        isOption = true;
        break;
      }
    }

    // Check that the fee paid is within the cap
    int32 feeCapRate = isMakerOrder ? order.makerFeePercentageCap : order.takerFeePercentageCap;
    if (order.isLiquidation) {
      // Liquidation Fee:
      // 0.25% = 25 bps on option index notional
      // 0.70% = 70 bps otherwise
      int32 liquidationFee = isOption ? int32(2500) : int32(7000);
      if (feeCapRate < liquidationFee) {
        feeCapRate = liquidationFee;
      }
    }
    BI memory feeCapRateBI = _bpsToDecimal(feeCapRate);

    int64 totalFeeCap;

    if (isOption) {
      totalFeeCap = _calculateBaseFee(optionIndexNotional, feeCapRateBI, qDec);
      BI memory premiumCapFee = bpsToDecimal(125000); // 12.5% premium cap

      if (totalFeeCap > 0) {
        totalFeeCap = _min(totalFeeCap, _calculateBaseFee(tradeNotional, premiumCapFee, qDec));
      } else {
        totalFeeCap = _max(totalFeeCap, _calculateBaseFee(tradeNotional, premiumCapFee.neg(), qDec));
      }
    } else {
      totalFeeCap = _calculateBaseFee(tradeNotional, feeCapRateBI, qDec);
    }

    require(totalFee <= totalFeeCap, ERR_FEE_CAP_EXCEEDED);
  }

  function _calculateBaseFee(BI memory notional, BI memory fee, uint qDec) private pure returns (int64) {
    if (notional.val == 0) return 0;
    return notional.mul(fee).toInt64(qDec);
  }

  function _getFeeSubAccount(bool isLiquidation) private view returns (SubAccount storage, bool) {
    if (isLiquidation) {
      return _getSubAccountFromUintConfig(ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID);
    } else {
      return _getSubAccountFromUintConfig(ConfigID.ADMIN_FEE_SUB_ACCOUNT_ID);
    }
  }

  function _executeOrder(
    SubAccount storage sub,
    Order calldata order,
    uint64[] memory matchSizes,
    BI memory spotDelta,
    int64 fee
  ) private {
    Currency subQuote = sub.quoteCurrency;
    uint qDec = _getBalanceDecimal(subQuote);

    uint legsLen = order.legs.length;
    for (uint i; i < legsLen; ++i) {
      if (matchSizes[i] == 0) continue;
      OrderLeg calldata leg = order.legs[i];

      // Step 1: Retrieve position
      Position storage pos = _getOrCreatePosition(sub, leg.assetID);
      int64 posBalance = pos.balance;

      if (order.reduceOnly) {
        require(posBalance != 0, "failed reduce only: no position");
        // If the position is in the same direction as the trade, return an error
        bool isLong = posBalance > 0;
        // Require the trade side must be opposite to the current position side
        require(leg.isBuyingAsset != isLong, "failed reduce only");
        uint64 posBalanceAbs = uint64(posBalance < 0 ? -posBalance : posBalance);
        // Trade shouldn't reduce the position size by more than the current position size (ie crossing 0)
        require(matchSizes[i] <= posBalanceAbs, "failed reduce only");
      }

      // Step 2: Update subaccount balances
      if (leg.isBuyingAsset) {
        pos.balance += int64(matchSizes[i]);
      } else {
        pos.balance -= int64(matchSizes[i]);
      }

      // Step 3: Remove position if empty
      if (pos.balance == 0) {
        removePos(sub, leg.assetID);
      }
    }

    // Step 4: Update subaccount spot balance, deducting fees
    int64 newSpotBalance = sub.spotBalances[subQuote] + spotDelta.toInt64(qDec);
    (SubAccount storage feeSub, bool isFeeCharged) = _getFeeSubAccount(order.isLiquidation);
    if (isFeeCharged) {
      newSpotBalance -= fee;
      feeSub.spotBalances[subQuote] += fee;
    }
    sub.spotBalances[subQuote] = newSpotBalance;
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
    for (uint i; i < len; ++i) totalFee += int64(feePerLegs[i]);
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
    return BI(int256(bps), 6);
  }
}
