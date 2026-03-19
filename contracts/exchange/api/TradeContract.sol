pragma solidity ^0.8.20;

import "./FundingAndSettlement.sol";
import "./RiskCheck.sol";
import "./ConfigContract.sol";
import "./signature/generated/TradeSig.sol";
import "../types/DataStructure.sol";
import "../common/Error.sol";
import "../util/BIMath.sol";
import "../util/Asset.sol";
import "../interfaces/ITrade.sol";

abstract contract TradeContract is ITrade, ConfigContract, FundingAndSettlement, RiskCheck {
  using BIMath for BI;

  int32 internal constant TRADE_FEE_CAP_RATE_BPS = 2000;
  // Liquidation Fee:
  // 0.25% = 25 bps on option index notional
  // 0.70% = 70 bps otherwise
  int32 internal constant LIQUIDATION_FEE_CAP_RATE_BPS_OPTION = 2500;
  int32 internal constant LIQUIDATION_FEE_CAP_RATE_BPS_OTHER = 7000;
  int32 internal constant PREMIUM_CAP_RATE_BPS = 125000; // 12.5% premium cap

  /// @dev The maximum signature expiry time for orders. This is deliberately laxer than the expiry for order in risk
  /// In risk normal orders have a 30 day expiry, and TPSL orders have a 180 day expiry.
  /// Orders passing risk expiry validation also pass contract expiry validation
  int64 private constant ONE_HUNDRED_EIGHTY_DAY_EXPIRY = 180 * 24 * ONE_HOUR_NANOS;

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

    _verifyAndExecuteOrder(
      timestamp,
      trade.takerOrder,
      takerCalcResult,
      false,
      trade.feeCharged,
      trade.builderFees,
      takerSub
    );
  }

  function _verifyAndExecuteMakerOrders(
    int64 timestamp,
    Trade calldata trade,
    SubAccount storage takerSub
  ) private returns (OrderCalculationResult memory) {
    OrderCalculationResult memory takerCalcResult;
    uint takerLegsLen = trade.takerOrder.legs.length;
    takerCalcResult.matchedSizes = new uint64[](takerLegsLen);
    takerCalcResult.legSpotDelta = new BI[](takerLegsLen);
    uint64[] memory takerLegDecimals = _getLegUnderlyingDecimals(trade.takerOrder.legs);
    MakerTradeMatch[] calldata makerMatches = trade.makerOrders;
    uint matchesLen = makerMatches.length;

    for (uint i; i < matchesLen; ) {
      MakerTradeMatch calldata makerMatch = makerMatches[i];
      OrderCalculationResult memory makerCalcResult = _calculateMakerOrder(
        trade,
        makerMatch,
        takerCalcResult,
        takerLegDecimals
      );
      _verifyAndExecuteOrder(
        timestamp,
        makerMatch.makerOrder,
        makerCalcResult,
        true,
        makerMatch.feeCharged,
        makerMatch.builderFees,
        takerSub
      );
      unchecked { ++i; }
    }

    return takerCalcResult;
  }

  function _calculateMakerOrder(
    Trade calldata trade,
    MakerTradeMatch calldata makerMatch,
    OrderCalculationResult memory takerCalcResult,
    uint64[] memory takerLegDecimals
  ) private pure returns (OrderCalculationResult memory makerCalcResult) {
    makerCalcResult.matchedSizes = makerMatch.matchedSize;
    makerCalcResult.legSpotDelta = new BI[](makerMatch.makerOrder.legs.length);

    for (uint legIdx; legIdx < makerMatch.makerOrder.legs.length; ) {
      uint64 size = makerCalcResult.matchedSizes[legIdx];
      if (size == 0) {
        unchecked { ++legIdx; }
        continue;
      }

      OrderLeg calldata leg = makerMatch.makerOrder.legs[legIdx];
      uint takerLegIdx = _findLegIndex(trade.takerOrder.legs, leg.assetID);
      uint udec = takerLegDecimals[takerLegIdx];
      BI memory tradeSize = BI(int256(uint256(size)), uint64(udec));
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

      takerCalcResult.matchedSizes[takerLegIdx] += size;
      unchecked { ++legIdx; }
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
    OrderLeg[] calldata takerLegs = takerOrder.legs;
    uint takerLegsLen = takerLegs.length;

    for (uint i = 0; i < trade.makerOrders.length; ) {
      MakerTradeMatch calldata tradeMatch = trade.makerOrders[i];
      Order calldata makerOrder = tradeMatch.makerOrder;
      uint numLegs = makerOrder.legs.length;
      uint64[] calldata matchedSizes = tradeMatch.matchedSize;
      require(matchedSizes.length == numLegs, ERR_INVALID_MATCHED_SIZE);
      for (uint j = 0; j < numLegs; ) {
        OrderLeg calldata makerLeg = makerOrder.legs[j];
        (bool found, uint64 takerLimitPrice, bool takerIsBuying) = _findTakerLeg(takerLegs, takerLegsLen, makerLeg.assetID);

        if (!found) {
          require(matchedSizes[j] == 0, "matched against non-existent taker leg");
          unchecked { ++j; }
          continue;
        }
        require(takerIsBuying != makerLeg.isBuyingAsset, "matched same side");

        if (!takerOrder.isMarket) {
          require(
            (takerIsBuying && takerLimitPrice >= makerLeg.limitPrice) ||
              (!takerIsBuying && takerLimitPrice <= makerLeg.limitPrice),
            "taker matched with bad price"
          );
        }
        unchecked { ++j; }
      }
      unchecked { ++i; }
    }
  }

  function _findTakerLeg(OrderLeg[] calldata legs, uint len, bytes32 assetID) private pure returns (bool, uint64, bool) {
    for (uint i; i < len; ) {
      if (legs[i].assetID == assetID) {
        return (true, legs[i].limitPrice, legs[i].isBuyingAsset);
      }
      unchecked { ++i; }
    }
    return (false, 0, false);
  }

  /// @dev Verifies and executes an order, applying checks based on order type and account status.
  /// Validation spec: https://grvt.atlassian.net/wiki/spaces/TRADE/pages/142803008/De-risking+tech+design
  function _verifyAndExecuteOrder(
    int64 timestamp,
    Order calldata order,
    OrderCalculationResult memory calcResult,
    bool isMakerOrder,
    int64[] memory feePerLegs,
    int64[] memory builderFeePerLegs,
    SubAccount storage takerSub
  ) private {
    // 1. Resolve active sub-account and calculate total fee
    SubAccount storage sub = isMakerOrder ? _requireSubAccount(order.subAccountID) : takerSub;
    int64 totalFee = _getTotalFee(feePerLegs);
    int64 totalBuilderFee = _getTotalFee(builderFeePerLegs);

    // 2. Order validation
    _verifyOrderFull(timestamp, sub, takerSub, order, calcResult, isMakerOrder, totalFee);

    // 3. Apply funding and settlement before margin checks
    _fundAndSettle(sub);

    // 4. Pre-check for reduceOnly orders
    // A reduce-only order must actually reduce the position size.
    bool isReducingOrder = _isReducingOrder(sub, order, calcResult.matchedSizes);
    require(!order.reduceOnly || isReducingOrder, "invalid reduce order");
    _checkVaultOrder(sub, isReducingOrder);
    bytes32 isolatedAssetID = _getOrderIsolatedLegAssetID(order, sub);

    // ---------- Early Exits for Special Order Types ----------

    // Path 1: Insurance Fund orders have special execution privileges.
    (uint64 insuranceFundSubID, bool isInsuranceFundSet) = _getUintConfig(ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID);
    bool isInsuranceFund = isInsuranceFundSet && sub.id == insuranceFundSubID;
    if (isInsuranceFund) {
      _executeOrder(timestamp, sub, order, calcResult, isolatedAssetID, totalFee, totalBuilderFee);
      return;
    }

    // Path 2: Non-liquidation, non-derisk orders that reduce position size.
    // These are generally preferred and can bypass some stricter checks.
    bool isPlainOrder = !order.isLiquidation && !order.isDerisk;
    if (isPlainOrder && isReducingOrder) {
      _executeOrder(timestamp, sub, order, calcResult, isolatedAssetID, totalFee, totalBuilderFee);
      return;
    }

    // ---------- Derisk Flow ----------
    if (order.isDerisk) {
      if (!isDeriskable(timestamp, sub, isolatedAssetID)) {
        revert ErrNotDeriskable();
      }
      _executeOrder(timestamp, sub, order, calcResult, isolatedAssetID, totalFee, totalBuilderFee);
      return;
    }

    // ---------- Liquidation / Standard Execution Fallback ----------
    bool isIsolated = isolatedAssetID != bytes32(0);
    if (order.isLiquidation) {
      // Pre-trade: Liquidation orders require the subaccount equity to be below maintennce margin beforehand.
      if (!isBelowMaintenanceMargin(sub, isolatedAssetID)) {
        revert ErrNotLiquidatable();
      }
    }

    BI memory crossTEBefore;
    if (order.isLiquidation && isIsolated) {
      crossTEBefore = _getTotalEquityCrossInQuote(sub);
    }

    _executeOrder(timestamp, sub, order, calcResult, isolatedAssetID, totalFee, totalBuilderFee);

    if (order.isLiquidation) {
      BI memory crossTEAfter = _getTotalEquityCrossInQuote(sub);
      // Post-trade check
      if (isIsolated) {
        // if ISOLATED: requires crossTE_After >= crossTE_Before
        if (crossTEAfter.cmp(crossTEBefore) < 0) {
          revert ErrFailedMarginCheck();
        }
      } else {
        // if CROSS order: requires TE >= 0
        if (crossTEAfter.val < 0) {
          revert ErrFailedMarginCheck();
        }
      }
    } else {
      // Post-trade: regular (non-liquidation) orders require positive cross total equity.
      if (_getTotalEquityCrossInQuote(sub).val < 0) {
        revert ErrNonPositiveCrossTotalEquity();
      }
    }
  }

  function _checkVaultOrder(SubAccount storage sub, bool isReducingOrder) private view {
    if (!sub.isVault) {
      return;
    }

    require(sub.vaultInfo.status != VaultStatus.DELISTED || isReducingOrder, "delisted vault can only reduce position");
    require(sub.vaultInfo.status != VaultStatus.CLOSED, "closed vault cannot trade");
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
    require(legsLen > 0, "order must have at least 1 leg");
    bool shouldValidateBuilderFee = order.builder != address(0) && order.builderFee > 0;
    uint32 builderMaxFutureFeeRate;
    uint32 builderMaxSpotFeeRate;

    if (shouldValidateBuilderFee) {
      Account storage acc = _requireAccount(sub.accountID);
      BuilderFeeConfig storage builderConfig = acc.builders[order.builder];
      builderMaxFutureFeeRate = builderConfig.maxFutureFeeRate;
      builderMaxSpotFeeRate = builderConfig.maxSpotFeeRate;
    }

    for (uint i; i < legsLen; ) {
      OrderLeg calldata leg = legs[i];
      Currency assetQuote = assetGetQuote(leg.assetID);
      Currency underlying = assetGetUnderlying(leg.assetID);
      Kind kind = assetGetKind(leg.assetID);
      require(assetQuote == subQuote, ERR_MISMATCH_QUOTE_CURRENCY);
      require(kind == Kind.PERPS, ERR_NOT_SUPPORTED);
      require(currencyCanHoldSpotBalance(assetQuote), ERR_NOT_SUPPORTED);
      require(currencyIsValid(underlying), ERR_NOT_SUPPORTED);
      if (shouldValidateBuilderFee) {
        _validateBuilderFee(order.builderFee, kind, builderMaxSpotFeeRate, builderMaxFutureFeeRate);
      }
      unchecked { ++i; }
    }

    // Check the order signature
    bytes32 orderHash = hashOrder(order);
    Signature calldata sig = order.signature;
    require(sig.expiration >= timestamp && sig.expiration <= (timestamp + ONE_HUNDRED_EIGHTY_DAY_EXPIRY), "expired");
    _requireValidNoExipry(orderHash, sig);

    // Check that the signer has trade permission
    Session storage session = state.sessions[sig.signer];

    // The signer is considered to have trade permission if any of the following is true:
    // - order's signer is in the session key map, and session hasn't expired, and the sessionKey's signer has trade permission
    // - order's signer has trade permission
    SubAccount storage permSub = sub;
    if (order.isLiquidation || order.isDerisk) {
      (permSub, ) = _getSubAccountFromUintConfig(ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID);
    } else if (sub.isVault && sub.vaultInfo.status == VaultStatus.DELISTED) {
      (SubAccount storage ifSub, bool ifSubFound) = _getSubAccountFromUintConfig(
        ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID
      );
      if (ifSubFound && hasSubAccountPermission(ifSub, sig.signer, SubAccountPermTrade)) {
        permSub = ifSub;
      }
    }

    require(
      (hasSubAccountPermission(permSub, session.subAccountSigner, SubAccountPermTrade)) ||
        hasSubAccountPermission(permSub, sig.signer, SubAccountPermTrade),
      ERR_NO_TRADE_PERMISSION
    );

    // Check that the order's total matched size after this trade does not exceed the order size
    mapping(bytes32 => uint64) storage executedSize = state.replay.sizeMatched[orderHash];

    bool isWholeOrder = order.timeInForce == TimeInForce.ALL_OR_NONE || order.timeInForce == TimeInForce.FILL_OR_KILL;

    if (legsLen > 1) {
      bytes32[] memory seenAssetIDs = new bytes32[](legsLen);
      uint seenCount = 0;

      for (uint i; i < legsLen; ) {
        OrderLeg calldata leg = legs[i];

        for (uint j = 0; j < seenCount; ) {
          require(seenAssetIDs[j] != leg.assetID, "Duplicate assetID in legs");
          unchecked { ++j; }
        }
        seenAssetIDs[seenCount] = leg.assetID;
        seenCount++;
        unchecked { ++i; }
      }
    }

    for (uint i; i < legsLen; ) {
      OrderLeg calldata leg = legs[i];
      uint64 legExecutedSize = executedSize[leg.assetID];
      if (order.timeInForce == TimeInForce.IMMEDIATE_OR_CANCEL) {
        require(legExecutedSize == 0, "prior match for IOC order");
      }
      uint64 total = legExecutedSize + calcResult.matchedSizes[i];
      require(isWholeOrder ? total == leg.size : total <= leg.size, ERR_INVALID_MATCHED_SIZE);
      executedSize[leg.assetID] = total;
      unchecked { ++i; }
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

  function _validateBuilderFee(
    uint32 orderBuilderFeeRate,
    Kind kind,
    uint32 maxSpotFeeRate,
    uint32 maxFutureFeeRate
  ) private pure {
    if (kind == Kind.SPOT) {
      if (orderBuilderFeeRate > maxSpotFeeRate) revert ErrBuilderFeeExceedMax();
      return;
    }

    if (kind == Kind.PERPS || kind == Kind.FUTURES) {
      if (orderBuilderFeeRate > maxFutureFeeRate) {
        revert ErrBuilderFeeExceedMax();
      }
    }
  }

  function _calculateBaseFee(BI memory notional, BI memory fee, uint qDec) private pure returns (int64) {
    if (notional.val == 0) return 0;
    return notional.mul(fee).toInt64(qDec);
  }

  /// @notice Executes a validated order, handling isolated vs cross flows, fees, and auto-rebalance.
  /// @dev Assumes all risk/signature checks already passed; may mutate positions, spot balances, and fee accounts.
  /// @param timestamp Sequencing timestamp for side effects (derisk window update).
  /// @param sub The sub-account executing the order (maker or taker).
  /// @param order The order being filled.
  /// @param calcResult Matched sizes, leg deltas, and trade notional for this fill.
  /// @param isolatedAssetID Non-zero if the order is isolated; zero for cross-margin orders.
  /// @param fee Total trading fee in quote units (1e6 scaling).
  /// @param builderFee Builder fee in USDT units (1e6 scaling) if applicable.
  function _executeOrder(
    int64 timestamp,
    SubAccount storage sub,
    Order calldata order,
    OrderCalculationResult memory calcResult,
    bytes32 isolatedAssetID,
    int64 fee,
    int64 builderFee
  ) private {
    Currency subQuote = sub.quoteCurrency;
    bool isIsolatedOrder = isolatedAssetID != bytes32(0);
    (SubAccount storage feeSub, bool isFeeCharged) = _getTradingFeeSubAccount(order.isLiquidation);

    int64 spotDelta;
    if (isIsolatedOrder) {
      spotDelta = _executeIsolatedOrder(sub, order, calcResult, isolatedAssetID);
    } else {
      spotDelta = _executeCrossOrder(sub, order, calcResult, subQuote);
    }

    _applyFees(sub, feeSub, subQuote, fee, spotDelta, isFeeCharged);
    _applyBuilderFee(sub, order.builder, builderFee);
    _maybeUpdateDeriskTimestamp(sub, order.isDerisk, timestamp);
  }

  function _executeIsolatedOrder(
    SubAccount storage sub,
    Order calldata order,
    OrderCalculationResult memory calcResult,
    bytes32 isolatedAssetID
  ) private returns (int64) {
    // By definition, isolated-margin orders must have exactly one leg.
    OrderLeg calldata leg = order.legs[0];
    uint64 matchedSize = calcResult.matchedSizes[0];
    if (matchedSize == 0) {
      return 0;
    }

    uint isolatedQDec = _getBalanceDecimal(assetGetQuote(isolatedAssetID));

    // Step 1: Retrieve position and snapshot pre-trade state for auto-rebalance.
    Position storage pos = _getOrCreatePosition(sub, isolatedAssetID);
    int64 positionSizeBegin = pos.balance;
    int64 positionBalanceBegin = pos.marginBalance;
    int64 positionBalance = positionBalanceBegin;

    // Step 2: Apply quote notional cashflow to isolated position balance (instead of cross spot balance).
    positionBalance += calcResult.legSpotDelta[0].toInt64(isolatedQDec);

    // Step 3: Update position size.
    int64 deltaSize = SafeCast.toInt64(int(uint256(matchedSize)));
    if (leg.isBuyingAsset) {
      pos.balance += deltaSize;
    } else {
      pos.balance -= deltaSize;
    }

    // Step 4: Remove position if empty, else apply isolated margin auto-rebalance.
    if (pos.balance == 0) {
      pos.marginBalance = positionBalance;
      removePos(sub, isolatedAssetID);
      return 0;
    }

    pos.marginBalance = _applyIsolatedMarginAutoRebalance(
      sub,
      pos,
      isolatedAssetID,
      leg.isBuyingAsset,
      matchedSize,
      calcResult.tradeNotional,
      positionSizeBegin,
      positionBalanceBegin,
      positionBalance
    );

    return 0;
  }

  function _executeCrossOrder(
    SubAccount storage sub,
    Order calldata order,
    OrderCalculationResult memory calcResult,
    Currency subQuote
  ) private returns (int64 spotDelta) {
    uint legsLen = order.legs.length;
    for (uint i; i < legsLen; ) {
      uint64 matchedSize = calcResult.matchedSizes[i];
      if (matchedSize == 0) {
        unchecked { ++i; }
        continue;
      }
      OrderLeg calldata leg = order.legs[i];

      // Step 1: Retrieve position
      Position storage pos = _getOrCreatePosition(sub, leg.assetID);

      // Step 2: Update subaccount balances
      int64 delta = SafeCast.toInt64(int(uint(matchedSize)));
      if (leg.isBuyingAsset) {
        pos.balance += delta;
      } else {
        pos.balance -= delta;
      }

      // Step 3: Remove position if empty
      if (pos.balance == 0) {
        removePos(sub, leg.assetID);
      }
      unchecked { ++i; }
    }

    uint subQDec = _getBalanceDecimal(subQuote);
    for (uint j; j < legsLen; ) {
      spotDelta += calcResult.legSpotDelta[j].toInt64(subQDec);
      unchecked { ++j; }
    }
  }

  function _applyFees(
    SubAccount storage sub,
    SubAccount storage feeSub,
    Currency quote,
    int64 fee,
    int64 spotDelta,
    bool isFeeCharged
  ) private {
    if (isFeeCharged) {
      feeSub.futuresWalletBalances[quote] += fee;
      sub.futuresWalletBalances[quote] += spotDelta - fee;
      return;
    }

    if (spotDelta != 0) {
      sub.futuresWalletBalances[quote] += spotDelta;
    }
  }

  function _applyBuilderFee(SubAccount storage sub, address builder, int64 builderFee) private {
    if (builder == address(0x0) || builderFee <= 0) {
      return;
    }

    sub.futuresWalletBalances[Currency.USDT] -= builderFee; // FIXME: once there's spot trading, need to fix this
    _requireAccount(builder).fundingWalletBalances[Currency.USDT] += builderFee; // FIXME: once there's spot trading, need to fix this
  }

  function _maybeUpdateDeriskTimestamp(SubAccount storage sub, bool isDerisk, int64 timestamp) private {
    if (isDerisk) {
      sub.lastDeriskTimestamp = timestamp;
    }
  }

  enum PositionDirection {
    INCREASED,
    DECREASED,
    FLIPPED
  }

  /// @notice Classifies how an isolated position moved after a trade.
  /// @dev Combines pre/post signed size with trade side to decide increase, decrease, or flip.
  /// @param positionSizeBegin Position size before the trade (signed).
  /// @param positionSizeEnd Position size after the trade (signed).
  /// @param isBuying True if the trade direction is buy; false if sell.
  /// @return PositionDirection enum indicating the movement type.
  function _getPositionDirection(
    int64 positionSizeBegin,
    int64 positionSizeEnd,
    bool isBuying
  ) private pure returns (PositionDirection) {
    if (isBuying) {
      if (positionSizeBegin >= 0) {
        return PositionDirection.INCREASED;
      }
      if (positionSizeEnd <= 0) {
        return PositionDirection.DECREASED;
      }
      return PositionDirection.FLIPPED;
    }

    if (positionSizeBegin <= 0) {
      return PositionDirection.INCREASED;
    }
    if (positionSizeEnd >= 0) {
      return PositionDirection.DECREASED;
    }
    return PositionDirection.FLIPPED;
  }

  /// @notice Performs isolated auto-rebalance based on how the position moved after a trade.
  /// @dev Routes to increase/decrease/flip handlers and returns the new isolated margin balance.
  /// @param sub Sub-account that owns the position.
  /// @param posEnd Position after size was updated for the trade.
  /// @param assetID Asset whose position is being rebalanced.
  /// @param isBuying True if the trade direction is buy; false if sell.
  /// @param tradeSize Matched size for the isolated leg (underlying decimals).
  /// @param tradeNotional Quote notional for the isolated leg (uDec + PRICE_DECIMALS scaling).
  /// @param positionSizeBegin Position size before the trade.
  /// @param positionBalanceBegin Isolated margin balance before the trade.
  /// @param positionBalanceNow Isolated margin balance after applying trade cashflow, before rebalance.
  /// @return Updated isolated margin balance to persist.
  function _applyIsolatedMarginAutoRebalance(
    SubAccount storage sub,
    Position storage posEnd,
    bytes32 assetID,
    bool isBuying,
    uint64 tradeSize,
    BI memory tradeNotional,
    int64 positionSizeBegin,
    int64 positionBalanceBegin,
    int64 positionBalanceNow
  ) private returns (int64) {
    // Step 1: Determine the position direction.
    PositionDirection positionDirection = _getPositionDirection(positionSizeBegin, posEnd.balance, isBuying);

    // Step 2: Handle each position direction.
    if (positionDirection == PositionDirection.INCREASED) {
      return _handleIsolatedPositionIncreasing(sub, assetID, isBuying, tradeSize, tradeNotional, positionBalanceNow);
    }

    if (positionDirection == PositionDirection.DECREASED) {
      return
        _handleIsolatedPositionDecreasing(
          sub,
          assetID,
          positionSizeBegin,
          positionBalanceBegin,
          posEnd.balance,
          positionBalanceNow
        );
    }

    return
      _handleIsolatedPositionFlipping(
        sub,
        assetID,
        isBuying,
        tradeSize,
        tradeNotional,
        posEnd.balance,
        positionBalanceNow
      );
  }

  /// @notice Handles auto-rebalance when the isolated position increases in size.
  /// @dev Computes additional margin needed at entry price and debits spot accordingly.
  /// @param sub Sub-account that owns the position.
  /// @param assetID Asset whose position is being increased.
  /// @param isBuying True if the trade direction is buy; false if sell.
  /// @param tradeSize Matched size for this fill (underlying decimals).
  /// @param tradeNotional Quote notional for this fill (uDec + PRICE_DECIMALS scaling).
  /// @param positionBalanceNow Isolated margin balance after trade cashflow, before rebalance.
  /// @return New isolated margin balance after the transfer.
  function _handleIsolatedPositionIncreasing(
    SubAccount storage sub,
    bytes32 assetID,
    bool isBuying,
    uint64 tradeSize,
    BI memory tradeNotional,
    int64 positionBalanceNow
  ) private returns (int64) {
    // AmountToAdd (Buy)  = AbsPosIncrease * [MarkPrice / Leverage + max(0, TradePrice - MarkPrice)]
    // AmountToAdd (Sell) = AbsPosIncrease * [MarkPrice / Leverage + max(0, MarkPrice - TradePrice)]
    uint64 uDec = _getBalanceDecimal(assetGetUnderlying(assetID));
    BI memory absPosIncrease = BI(int256(uint256(tradeSize)), uDec);
    BI memory tradePrice = _getTradePriceBI(tradeNotional, tradeSize, uDec);
    BI memory markPrice = _requireAssetPriceInQuoteBI(assetID);
    BI memory leverage = _getLeverageBI(sub, assetID);

    BI memory amountToAdd = absPosIncrease.mul(_getIsolatedMarginPerUnit(markPrice, leverage, tradePrice, isBuying));
    int64 amountToAddInt64 = amountToAdd.toInt64(6);
    if (amountToAddInt64 < 0) revert ErrInvalidOrder();

    return positionBalanceNow + _transferFromSpotToPosition(sub, assetGetQuote(assetID), amountToAddInt64);
  }

  /// @notice Handles auto-rebalance when the isolated position decreases in size.
  /// @dev Scales margin down proportionally and returns excess to spot.
  /// @param sub Sub-account that owns the position.
  /// @param assetID Asset whose position is being reduced.
  /// @param positionSizeBegin Position size before the trade.
  /// @param positionBalanceBegin Isolated margin balance before the trade.
  /// @param positionSizeEnd Position size after the trade.
  /// @param positionBalanceNow Isolated margin balance after trade cashflow, before rebalance.
  /// @return New isolated margin balance after the transfer.
  function _handleIsolatedPositionDecreasing(
    SubAccount storage sub,
    bytes32 assetID,
    int64 positionSizeBegin,
    int64 positionBalanceBegin,
    int64 positionSizeEnd,
    int64 positionBalanceNow
  ) private returns (int64) {
    // ReductionRatio = Abs(PositionSizeEnd) / Abs(PositionSizeStart) - must always < 1 and >= 0
    // PositionBalanceEnd = PositionBalanceStart * ReductionRatio
    uint64 uDec = _getBalanceDecimal(assetGetUnderlying(assetID));
    BI memory absPositionSizeStart = _absInt64ToBI(positionSizeBegin, uDec);
    BI memory absPositionSizeEnd = _absInt64ToBI(positionSizeEnd, uDec);
    BI memory reductionRatio = absPositionSizeEnd.div(absPositionSizeStart);

    BI memory positionBalanceEnd = BI(positionBalanceBegin, 6).mul(reductionRatio);
    BI memory positionBalanceCurrent = BI(positionBalanceNow, 6);

    BI memory amountToRemoveFromPosition = positionBalanceCurrent.sub(positionBalanceEnd);
    int64 amountToRemoveInt64 = amountToRemoveFromPosition.toInt64(6);

    return positionBalanceNow + _transferFromIsolatedToSpot(sub, assetGetQuote(assetID), amountToRemoveInt64);
  }

  /// @notice Handles auto-rebalance when the isolated position flips direction.
  /// @dev Treats flip as close-then-open at trade price and adjusts margin to new entry.
  /// @param sub Sub-account that owns the position.
  /// @param assetID Asset whose position is flipping.
  /// @param isBuying True if the new position is long; false if short.
  /// @param tradeSize Matched size for this fill (underlying decimals).
  /// @param tradeNotional Quote notional for this fill (uDec + PRICE_DECIMALS scaling).
  /// @param positionSizeEnd Position size after the trade (signed).
  /// @param positionBalanceNow Isolated margin balance after trade cashflow, before rebalance.
  /// @return New isolated margin balance after the transfer.
  function _handleIsolatedPositionFlipping(
    SubAccount storage sub,
    bytes32 assetID,
    bool isBuying,
    uint64 tradeSize,
    BI memory tradeNotional,
    int64 positionSizeEnd,
    int64 positionBalanceNow
  ) private returns (int64) {
    // Flipping the position = Close current position then open a new position
    // Isolated Balance after flipping =
    // If Buying: AbsNewPositionSize * [MarkPrice / Leverage + max(0, TradePrice - MarkPrice)]
    // If Selling: AbsNewPositionSize * [MarkPrice / Leverage + max(0, MarkPrice - TradePrice)]
    uint64 uDec = _getBalanceDecimal(assetGetUnderlying(assetID));
    BI memory absNewPositionSize = _absInt64ToBI(positionSizeEnd, uDec);
    BI memory tradePrice = _getTradePriceBI(tradeNotional, tradeSize, uDec);
    BI memory markPrice = _requireAssetPriceInQuoteBI(assetID);
    BI memory leverage = _getLeverageBI(sub, assetID);

    BI memory isolatedBalanceEnd = absNewPositionSize.mul(
      _getIsolatedMarginPerUnit(markPrice, leverage, tradePrice, isBuying)
    );

    // In risk, entry price is reset to trade price at this point, so:
    // isolatedBalanceNow = positionBalance + positionSize * tradePrice
    BI memory positionSize = BI(positionSizeEnd, uDec);
    BI memory positionSizeTimesTradePrice = positionSize.mul(tradePrice);
    BI memory positionBalanceBI = BI(positionBalanceNow, 6);
    // Add with full precision - the add function will handle decimal alignment
    BI memory isolatedBalanceNow = positionBalanceBI.add(positionSizeTimesTradePrice);

    BI memory amountToAddToPosition = isolatedBalanceEnd.sub(isolatedBalanceNow);
    // Convert to int64 with truncation, matching statemachine's ToInt(assetQDec).Int64()
    int64 amountToAddToPositionInt64 = amountToAddToPosition.toInt64(6);

    return positionBalanceNow + _transferFromSpotToPosition(sub, assetGetQuote(assetID), amountToAddToPositionInt64);
  }

  /// @notice Moves value between cross spot and isolated position, returning the position-side delta.
  /// @dev Positive `amount` pulls from spot into the isolated position; negative does the reverse.
  /// @param sub Sub-account whose spot balance is debited/credited.
  /// @param quote Quote currency of the isolated position.
  /// @param amount Signed amount to move (quote units, 1e6 decimals).
  /// @return Delta to apply to `pos.marginBalance` after spot is updated.
  function _transferFromSpotToPosition(SubAccount storage sub, Currency quote, int64 amount) private returns (int64) {
    // amount > 0: remove from spot and add to position
    // amount < 0: remove from position and add to spot
    sub.futuresWalletBalances[quote] -= amount;
    return amount;
  }

  /// @notice Moves value from isolated position back to cross spot, returning the position-side delta.
  /// @dev Positive `amount` credits spot and reduces isolated balance; negative does the reverse.
  /// @param sub Sub-account whose spot balance is credited/debited.
  /// @param quote Quote currency of the isolated position.
  /// @param amount Signed amount to move (quote units, 1e6 decimals).
  /// @return Delta to apply to `pos.marginBalance` after spot is updated.
  function _transferFromIsolatedToSpot(SubAccount storage sub, Currency quote, int64 amount) private returns (int64) {
    // amount > 0: remove from position and add to spot
    // amount < 0: remove from spot and add to position
    sub.futuresWalletBalances[quote] += amount;
    return -amount;
  }

  function _getTradePriceBI(BI memory tradeNotional, uint64 tradeSize, uint64 uDec) private pure returns (BI memory) {
    // tradeNotional is scaled in (uDec + PRICE_DECIMALS)
    // tradePrice is scaled in PRICE_DECIMALS
    return tradeNotional.div(BI(int256(uint256(tradeSize)), uDec)).scale(PRICE_DECIMALS);
  }

  function _getLeverageBI(SubAccount storage sub, bytes32 assetID) private view returns (BI memory) {
    int32 leverage = sub.positionMarginConfigs[assetID].leverage;
    if (leverage <= 0) revert ErrInvalidOrder();
    return BI(leverage, 6);
  }

  /// @notice Computes per-unit isolated margin requirement at entry for a trade.
  /// @dev markPrice/leverage plus positive slippage between trade price and mark (directional).
  /// @param markPrice Current mark price of the asset (PRICE_DECIMALS scaling).
  /// @param leverage Leverage config for the position (1e6 scaling).
  /// @param tradePrice Execution price for the trade (PRICE_DECIMALS scaling).
  /// @param isBuying True if the trade opens/increases a long; false if short.
  /// @return Margin per unit of position size (PRICE_DECIMALS scaling).
  function _getIsolatedMarginPerUnit(
    BI memory markPrice,
    BI memory leverage,
    BI memory tradePrice,
    bool isBuying
  ) private pure returns (BI memory) {
    BI memory markPriceDivLeverage = markPrice.div(leverage);
    BI memory extra;
    if (isBuying) {
      extra = tradePrice.sub(markPrice);
    } else {
      extra = markPrice.sub(tradePrice);
    }
    if (extra.val < 0) {
      extra = BI(0, PRICE_DECIMALS);
    }
    return markPriceDivLeverage.add(extra);
  }

  function _absInt64ToBI(int64 v, uint64 dec) private pure returns (BI memory) {
    int256 iv = int256(v);
    return BI(iv < 0 ? -iv : iv, dec);
  }

  function removePos(SubAccount storage sub, bytes32 assetID) private {
    Kind kind = assetGetKind(assetID);
    if (kind == Kind.PERPS) {
      // For isolated-margin positions, transfer any outstanding position balance back to spot before deletion.
      if (sub.positionMarginConfigs[assetID].marginType == PositionMarginType.ISOLATED) {
        Position storage pos = sub.perps.values[assetID];
        Currency quote = assetGetQuote(assetID);
        sub.futuresWalletBalances[quote] += pos.marginBalance;
        pos.marginBalance = 0;
      }
      remove(sub.perps, assetID);
    } else if (kind == Kind.FUTURES) {
      remove(sub.futures, assetID);
    } else if (_isOption(kind)) {
      remove(sub.options, assetID);
    }
  }

  function _getTotalFee(int64[] memory feePerLegs) private pure returns (int64) {
    int64 totalFee;
    uint len = feePerLegs.length;
    for (uint i; i < len; ) {
      totalFee += feePerLegs[i];
      unchecked { ++i; }
    }
    return totalFee;
  }

  function _getLegUnderlyingDecimals(OrderLeg[] calldata legs) private pure returns (uint64[] memory) {
    uint len = legs.length;
    uint64[] memory decimals = new uint64[](len);
    for (uint i; i < len; ) {
      decimals[i] = _getBalanceDecimal(assetGetUnderlying(legs[i].assetID));
      unchecked { ++i; }
    }
    return decimals;
  }

  function _findLegIndex(OrderLeg[] calldata legs, bytes32 assetID) private pure returns (uint) {
    uint len = legs.length;
    for (uint i; i < len; ) {
      if (legs[i].assetID == assetID) return i;
      unchecked { ++i; }
    }
    revert(ERR_NOT_FOUND);
  }

  function _isOption(Kind kind) private pure returns (bool) {
    return kind == Kind.CALL || kind == Kind.PUT;
  }

  function _bpsToDecimal(int32 bps) private pure returns (BI memory) {
    return BI(bps, 6);
  }

  function addIsolatedPositionMargin(
    int64 timestamp,
    uint64 txID,
    uint64 subAccountID,
    bytes32 assetID,
    int64 amount,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    SubAccount storage sub = _requireSubAccount(subAccountID);
    _requireSignerOrSessionKeySubAccountPerm(sub, sig.signer, SubAccountPermTrade, timestamp);

    PositionsMap storage posmap = _getPositionCollection(sub, assetGetKind(assetID));
    Position storage pos = posmap.values[assetID];

    PositionMarginConfig storage posConfig = sub.positionMarginConfigs[assetID];
    if (pos.id == 0 || posConfig.marginType != PositionMarginType.ISOLATED) {
      revert ErrAddMarginToNonIsolatedPosition();
    }

    if (_getTotalEquityCrossInQuote(sub).val < 0) {
      revert ErrAddIsolatedMarginTENegative();
    }

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddIsolatedPositionMargin(subAccountID, assetID, amount, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    // amount > 0: add margin to the position
    // amount < 0: remove margin from the position
    pos.marginBalance += amount;
    sub.futuresWalletBalances[assetGetQuote(assetID)] -= amount;
  }

  /// @dev Determines whether `order` is an isolated-margin order for `sub`.
  ///      - An order is considered isolated iff it has exactly 1 leg and that leg's `PositionMarginConfig.marginType`
  ///        is `PositionMarginType.ISOLATED`.
  ///      - Multi-leg orders are not allowed to include any isolated-margin legs; if they do, this reverts.
  /// @param order The order to classify.
  /// @param sub The sub-account whose position margin configs are used to classify the order's legs.
  /// @return isolatedAssetID If the order is isolated, returns the single leg's `assetID`; otherwise returns `0x0`.
  function _getOrderIsolatedLegAssetID(Order calldata order, SubAccount storage sub) private view returns (bytes32) {
    mapping(bytes32 => PositionMarginConfig) storage posConfigs = sub.positionMarginConfigs;
    uint256 len = order.legs.length;
    if (len == 0) revert ErrInvalidOrder();

    if (len == 1) {
      bytes32 assetID = order.legs[0].assetID;
      if (posConfigs[assetID].marginType == PositionMarginType.ISOLATED) {
        return assetID;
      }
      return bytes32(0);
    }

    for (uint256 i; i < len; ) {
      if (posConfigs[order.legs[i].assetID].marginType == PositionMarginType.ISOLATED) {
        revert ErrInvalidOrder();
      }
      unchecked { ++i; }
    }

    return bytes32(0);
  }
}
