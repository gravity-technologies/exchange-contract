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

  uint constant priceDecimal = 9;

  function tradeDeriv(int64 timestamp, uint64 txID, Trade calldata trade) external {
    _setSequence(timestamp, txID);

    // Verify and execute the maker matches
    MakerTradeMatch[] calldata makerMatches = trade.makerOrders;
    uint matchesLen = makerMatches.length;
    for (uint i; i < matchesLen; ++i) {
      MakerTradeMatch calldata makerMatch = makerMatches[i];
      Order calldata makerOrder = makerMatch.makerOrder;
      _verifyAndExecuteOrder(timestamp, makerOrder, makerMatch.matchedSize, true, makerMatch.feeCharged);
    }

    // Verify and execute the taker matches
    Order calldata takerOrder = trade.takerOrder;
    OrderLeg[] calldata takerLegs = takerOrder.legs;
    uint legsLen = takerOrder.legs.length;
    uint64[] memory takerMatchedSizes = new uint64[](legsLen);
    for (uint i; i < legsLen; ++i) {
      takerMatchedSizes[i] = state.transientTakerMatchedSizes[takerLegs[i].assetID];
    }
    _verifyAndExecuteOrder(timestamp, takerOrder, takerMatchedSizes, false, trade.feeCharged);

    // Clean up transient data
    delete state.transientTakerNotionals;
    for (uint i; i < legsLen; ++i) {
      delete state.transientTakerMatchedSizes[takerLegs[i].assetID];
    }
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

  function _getCurrencyDecimal(Currency currency) internal pure returns (uint64) {
    uint idx = uint(currency);

    require(idx != 0, ERR_UNSUPPORTED_CURRENCY);

    // USDT, USDC, USD
    if (idx < 4) return 6;

    // ETH, BTC
    return 9;
  }

  function _verifyAndExecuteOrder(
    int64 timestamp,
    Order calldata order,
    uint64[] memory tradeSizes,
    bool isMakerOrder,
    int64[] calldata feePerLegs
  ) internal {
    // Arrange from cheapest to most expensive verification

    // Check that the sub account exists
    SubAccount storage sub = _requireSubAccount(order.subAccountID);

    // Check that the order is valid
    _verifyOrder(sub, order, isMakerOrder);

    // Check that quote asset is the same as subaccount quote asset
    Currency subQuote = sub.quoteCurrency;
    uint legsLen = order.legs.length;
    for (uint i; i < legsLen; ++i) {
      require(assetGetQuote(order.legs[i].assetID) == subQuote, ERR_MISMATCH_QUOTE_CURRENCY);
    }

    // Check that the signer has trade permission
    address subAccountSigner = order.signature.signer;
    Session storage session = state.sessions[subAccountSigner];
    if (session.expiry != 0) {
      require(session.expiry >= timestamp, ERR_SESSION_EXPIRED);
      subAccountSigner = session.subAccountSigner;
    }
    Account storage acc = _requireAccount(sub.accountID);
    _requirePermission(sub, subAccountSigner, SubAccountPermTrade);

    // Verify the order signature
    bytes32 orderHash = hashOrder(order);
    _requireValidSig(timestamp, orderHash, order.signature);

    // Check that the order's total matched size after this trade does not exceed the order size
    mapping(bytes32 => uint64) storage sizeMatched = state.replay.sizeMatched[orderHash];
    TimeInForce tif = order.timeInForce;
    bool isWholeOrder = tif == TimeInForce.ALL_OR_NONE || tif == TimeInForce.FILL_OR_KILL;
    for (uint i; i < legsLen; ++i) {
      OrderLeg calldata leg = order.legs[i];
      uint64 total = sizeMatched[leg.assetID] + tradeSizes[i];

      if (isWholeOrder) {
        require(total == leg.size, ERR_INVALID_MATCHED_SIZE);
      } else {
        require(total <= leg.size, ERR_INVALID_MATCHED_SIZE);
      }
      sizeMatched[leg.assetID] = total;
    }

    // Check the fee charged percentage for this order is not greater than the signed fee percentage cap
    // check if total Fee <= order.makerFeePercentageCap * notional
    uint64 totalFee;
    for (uint i; i < legsLen; ++i) {
      totalFee += uint64(feePerLegs[i]);
    }
    BI[] memory tradeNotionals = new BI[](legsLen);
    if (isMakerOrder) {
      uint64 totalNotional;
      if (isWholeOrder) {
        totalNotional = order.limitPrice;
        // For whole orders, use the first entry of tradeNotionals to store the notional of the whole order. The rest of the entries are zero value, which will not affect calculation
        tradeNotionals[0] = BI(int256(uint256(order.limitPrice)), priceDecimal);
      } else {
        for (uint i; i < legsLen; ++i) {
          OrderLeg calldata leg = order.legs[i];
          BI memory tradeSize = BI(
            int256(uint256(tradeSizes[i])),
            _getCurrencyDecimal(assetGetUnderlying(leg.assetID))
          );
          BI memory limitPrice = BI(int256(uint256(leg.limitPrice)), priceDecimal);
          BI memory notional = tradeSize.mul(limitPrice);
          uint64 notionalU64 = notional.toUint64(priceDecimal);
          totalNotional += notionalU64;
          state.transientTakerMatchedSizes[leg.assetID] += tradeSizes[i];
          tradeNotionals[i] = notional;
        }
      }
      // FIXME what is the decimal places of fee cap
      // This comparison is currently out of whack now. Should be fixed once we know the correct decimal places
      require(totalFee <= order.makerFeePercentageCap * totalNotional);
      state.transientTakerNotionals += totalNotional;
    } else {
      require(totalFee <= state.transientTakerNotionals * order.takerFeePercentageCap, ERR_FEE_CAP_EXCEEDED);
    }

    _requireValidSubAccountUsdValue(sub);

    executeOrder(timestamp, sub, order, tradeSizes, tradeNotionals, totalFee);

    _requireValidSubAccountUsdValue(sub);
  }

  function executeOrder(
    int64 timestamp,
    SubAccount storage sub,
    Order calldata order,
    uint64[] memory tradeSizes,
    BI[] memory tradeNotionals,
    uint64 totalFee
  ) internal {
    _fundAndSettle(timestamp, sub);

    // Get fee sub account
    (uint64 feeSubID, bool ok) = _getUintConfig(ConfigID.ADMIN_FEE_SUB_ACCOUNT_ID);
    require(ok, ERR_MISISNG_FEE_SUB_ACCOUNT);
    SubAccount storage feeSubAccount = _requireSubAccount(feeSubID);

    Currency subQuote = sub.quoteCurrency;
    uint64 qDec = _getCurrencyDecimal(subQuote);
    BI memory spotBalance = BI(int64(sub.spotBalances[sub.quoteCurrency]), qDec);

    uint legsLen = order.legs.length;
    for (uint legIdx; legIdx < legsLen; ++legIdx) {
      if (tradeSizes[legIdx] == 0) continue;
      OrderLeg calldata leg = order.legs[legIdx];

      // Step 1: Retrieve position
      Position storage pos = _getOrCreatePosition(sub, leg.assetID);

      // Step 2: Update subaccount balances
      int64 oldBal = pos.balance;
      if (leg.isBuyingAsset) {
        spotBalance = spotBalance.sub(tradeNotionals[legIdx]);
        pos.balance += int64(tradeSizes[legIdx]);
      } else {
        spotBalance = spotBalance.add(tradeNotionals[legIdx]);
        pos.balance -= int64(tradeSizes[legIdx]);
      }

      // Step 3: Remove position if empty
      if (pos.balance == 0) removePos(sub, leg.assetID);
    }

    // Step 4: Pay trading fees (if there's a fee account)
    require(totalFee <= sub.spotBalances[subQuote], ERR_INSUFFICIENT_SPOT_BALANCE);
    sub.spotBalances[subQuote] = spotBalance.sub(BI(int256(uint256(totalFee)), qDec)).toUint64(qDec);
    feeSubAccount.spotBalances[subQuote] += uint64(totalFee);
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
      pos.lastAppliedFundingIndex = state.prices.fundingIndex[assetGetUnderlying(assetID)];
    }

    return pos;
  }
}
