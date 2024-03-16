// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./FundingAndSettlement.sol";
import "./RiskCheck.sol";
import "./ConfigContract.sol";
import "./signature/generated/TradeSig.sol";
import "../types/DataStructure.sol";
import "../common/Error.sol";
import "../util/Address.sol";
import "../util/BIMath.sol";
import "../util/Trade.sol";
import "../util/Asset.sol";

abstract contract TradeContract is ConfigContract, FundingAndSettlement, RiskCheck {
  using BIMath for BI;

  function tradeDeriv(int64 timestamp, uint64 txID, Trade calldata trade) external {
    _setSequence(timestamp, txID);

    Order calldata takerOrder = trade.takerOrder;
    OrderLeg[] calldata takerLegs = takerOrder.legs;
    uint64[] memory takerMatchedSizes = new uint64[](takerLegs.length);
    BI memory takerNotionals;
    BI memory takerSpotDelta;

    ///////////////////////////////////////////////////////////////////////////
    /// Maker order verification and execution
    ///
    /// We aggregate the notional values and matched sizes for taker in this
    /// loop here since we need the before we can verify / execute the taker order
    ///////////////////////////////////////////////////////////////////////////
    MakerTradeMatch[] calldata makerMatches = trade.makerOrders;
    uint matchesLen = makerMatches.length;
    uint64 totalMakersFee;

    for (uint i; i < matchesLen; ++i) {
      MakerTradeMatch calldata makerMatch = makerMatches[i];

      // Compute maker notionals
      BI memory makerSpotDelta;
      BI memory makerNotionals;
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
        uint64 notionalU64 = notional.toUint64(PRICE_DECIMALS);

        // Here we agregate the maker's spot delta, maker's notional, taker spot delta and taker's matched sizes
        if (leg.isBuyingAsset) {
          makerSpotDelta = makerSpotDelta.sub(notional);
          takerSpotDelta = takerSpotDelta.add(notional);
        } else {
          makerSpotDelta = makerSpotDelta.add(notional);
          takerSpotDelta = takerSpotDelta.sub(notional);
        }
        makerNotionals = makerNotionals.add(notional);
        takerMatchedSizes[_findLegIndex(takerLegs, leg.assetID)] += size;
      }

      // Aggregate taker notional accross all makers
      takerNotionals = takerNotionals.add(makerNotionals);
      uint64 makerFee = _getTotalFee(makerMatch.feeCharged);
      totalMakersFee += makerFee;

      _verifyAndExecuteOrder(
        timestamp,
        makerMatch.makerOrder,
        makerMatch.matchedSize,
        true,
        makerSpotDelta,
        makerNotionals,
        makerFee
      );
    }

    ///////////////////////////////////////////////////////////////////
    /// Taker order verification and execution
    ///////////////////////////////////////////////////////////////////
    uint64 takerFee = _getTotalFee(trade.feeCharged);
    _verifyAndExecuteOrder(timestamp, takerOrder, takerMatchedSizes, false, takerSpotDelta, takerNotionals, takerFee);

    // Deposit the trading fees, only once
    (uint64 feeSubID, bool ok) = _getUintConfig(ConfigID.ADMIN_FEE_SUB_ACCOUNT_ID);
    if (ok) {
      Currency quoteCurrency = _requireSubAccount(takerOrder.subAccountID).quoteCurrency;
      _requireSubAccount(feeSubID).spotBalances[quoteCurrency] += int64(totalMakersFee + takerFee);
    }
  }

  function _verifyAndExecuteOrder(
    int64 timestamp,
    Order calldata order,
    uint64[] memory tradeSizes,
    bool isMakerOrder,
    BI memory spotDelta,
    BI memory notional,
    uint64 totalFee
  ) internal {
    SubAccount storage sub = _requireSubAccount(order.subAccountID);

    _verifyOrderFull(timestamp, sub, order, tradeSizes, isMakerOrder, notional, totalFee);

    // Execute the order, ensuring sufficient balance pre and post trade
    _requireValidSubAccountUsdValue(sub);
    _executeOrder(timestamp, sub, order, tradeSizes, spotDelta, int64(totalFee));
    _requireValidSubAccountUsdValue(sub);
  }

  function _verifyOrderFull(
    int64 timestamp,
    SubAccount storage sub,
    Order calldata order,
    uint64[] memory tradeSizes,
    bool isMakerOrder,
    BI memory notional,
    uint64 totalFee
  ) internal {
    // Arrange from cheapest to most expensive verification

    // Check that quote asset is the same as subaccount quote asset
    Currency subQuote = sub.quoteCurrency;
    OrderLeg[] calldata legs = order.legs;
    uint legsLen = legs.length;
    for (uint i; i < legsLen; ++i) {
      require(assetGetQuote(legs[i].assetID) == subQuote, ERR_MISMATCH_QUOTE_CURRENCY);
    }

    // Check that the signer has trade permission
    address subAccountSigner = order.signature.signer;
    Session storage session = state.sessions[subAccountSigner];
    if (session.expiry != 0) {
      require(session.expiry >= timestamp, ERR_SESSION_EXPIRED);
      subAccountSigner = session.subAccountSigner;
    }
    _requireSubAccountPermission(sub, subAccountSigner, SubAccountPermTrade);

    // Check the order signature
    bytes32 orderHash = hashOrder(order);
    _requireValidSig(timestamp, orderHash, order.signature);

    // Check that the order's total matched size after this trade does not exceed the order size
    mapping(bytes32 => uint64) storage executedSize = state.replay.sizeMatched[orderHash];

    bool isWholeOrder = order.timeInForce == TimeInForce.ALL_OR_NONE || order.timeInForce == TimeInForce.FILL_OR_KILL;
    for (uint i; i < legsLen; ++i) {
      OrderLeg calldata leg = legs[i];
      uint64 total = executedSize[leg.assetID] + tradeSizes[i];
      require(isWholeOrder ? total == leg.size : total <= leg.size, ERR_INVALID_MATCHED_SIZE);
      executedSize[leg.assetID] = total;
    }

    // Check that the fee paid is within the cap
    uint32 feeCap = isMakerOrder ? order.makerFeePercentageCap : order.takerFeePercentageCap;
    require(totalFee <= feeCap * notional.toUint64(_getBalanceDecimal(subQuote)), ERR_FEE_CAP_EXCEEDED);
  }

  function _executeOrder(
    int64 timestamp,
    SubAccount storage sub,
    Order calldata order,
    uint64[] memory matchSizes,
    BI memory spotDelta,
    int64 fee
  ) internal {
    _fundAndSettle(timestamp, sub);

    Currency subQuote = sub.quoteCurrency;
    uint qdec = _getBalanceDecimal(subQuote);

    uint legsLen = order.legs.length;
    for (uint i; i < legsLen; ++i) {
      if (matchSizes[i] == 0) continue;
      OrderLeg calldata leg = order.legs[i];

      // Step 1: Retrieve position
      Position storage pos = _getOrCreatePosition(sub, leg.assetID);

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

    // FIXME: Step 4: Update subaccount spot balance, deducting fees
    int64 newSpotBalance = BI(sub.spotBalances[subQuote], qdec).add(spotDelta).sub(BI(fee, qdec)).toInt64(qdec);
    sub.spotBalances[subQuote] = newSpotBalance;
  }

  function _getPositionCollection(SubAccount storage sub, Kind kind) internal view returns (PositionsMap storage) {
    if (kind == Kind.PERPS) return sub.perps;
    if (kind == Kind.FUTURES) return sub.futures;
    return sub.options;
  }

  function _getOrCreatePosition(SubAccount storage sub, bytes32 assetID) internal returns (Position storage) {
    Kind kind = assetGetKind(assetID);
    PositionsMap storage posmap = _getPositionCollection(sub, kind);

    // If the position already exists, return it
    if (posmap.values[assetID].id != 0x0) {
      return posmap.values[assetID];
    }

    // Otherwise, create a new position
    Position storage pos = getOrNew(posmap, assetID);

    if (kind == Kind.PERPS) {
      // IMPT: Perpetual positions MUST have LastAppliedFundingIndex set to the current funding index
      // to avoid mis-calculation of funding payment (leads to improper accounting of on-chain assets)
      pos.lastAppliedFundingIndex = state.prices.fundingIndex[assetID];
    }

    return pos;
  }

  function removePos(SubAccount storage sub, bytes32 assetID) internal {
    Kind kind = assetGetKind(assetID);
    if (kind == Kind.PERPS) {
      remove(sub.perps, assetID);
    } else if (kind == Kind.FUTURES) {
      remove(sub.futures, assetID);
    } else if (kind == Kind.CALL || kind == Kind.PUT) {
      remove(sub.options, assetID);
    }
  }

  // FIXME: Our BE disables charging fees for now. To enable back afterwards
  function _getTotalFee(int64[] memory feePerLegs) private pure returns (uint64) {
    return 0;
    // uint64 totalFee;
    // uint len = feePerLegs.length;
    // for (uint i; i < len; ++i) totalFee += uint64(feePerLegs[i]);
    // return totalFee;
  }

  function _findLegIndex(OrderLeg[] calldata legs, bytes32 assetID) private pure returns (uint) {
    uint len = legs.length;
    for (uint i; i < len; ++i) if (legs[i].assetID == assetID) return i;
    revert(ERR_NOT_FOUND);
  }
}
