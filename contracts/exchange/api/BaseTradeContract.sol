// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "../types/DataStructure.sol";

contract BaseTradeContract is BaseContract {
  error InvalidTotalValue(uint64 subAccountID, int256 value);

  /// @dev return the total value of a sub account with 18 decimal places
  // function _getSubAccountUsdValue(SubAccount storage sub) internal view returns (int128) {
  //   uint256 currencyID = _getCurrencyAssetID(sub.quoteCurrency);
  //   // upcasting price from int64 -> int128 is safe
  //   int128 balanceUsd = sub.balanceE9 * int128(state.prices.mark[currencyID]);
  //   return
  //     balanceUsd +
  //     _getPositionsUsdValue(sub.perps) +
  //     _getPositionsUsdValue(sub.futures) +
  //     _getPositionsUsdValue(sub.options);
  // }

  // FIXME: return the correct asset encoding of quote currency
  function _getCurrencyAssetID(Currency c) internal pure returns (uint256) {
    if (c == Currency.ETH) return 0x0;
    if (c == Currency.BTC) return 0x0;
    if (c == Currency.USDC) return 0x0;
    if (c == Currency.USDT) return 0x0;
    require(false, "invalid currency");
    return 0;
  }

  // function _requireValidSubAccountUsdValue(SubAccount storage sub) internal view {
  //   int128 val = _getSubAccountUsdValue(sub);
  //   if (val < 0) revert InvalidTotalValue(sub.id, val);
  // }

  function _getPositionsUsdValue(PositionsMap storage positions) internal view returns (int128) {
    int128 total;
    uint256[] storage keys = positions.keys;
    mapping(uint256 => Position) storage values = positions.values;
    mapping(uint256 => uint64) storage assetPrices = state.prices.mark;

    uint count = keys.length;
    for (uint i; i < count; ++i) {
      Position storage pos = values[keys[i]];
      total += int128(uint128(assetPrices[pos.id])) * int128(pos.balance);
    }
    return total;
  }

  // TODO
  function _getInterestRate(uint128 id) internal view returns (int64) {
    return state.prices.interest[id];
  }

  // ------------------------------------------------------
  // Funding and Settlement
  // ------------------------------------------------------
  function _fundAndSettle(SubAccount storage sub) internal {
    _fundPerp(sub);
    _settleOptionsOrFutures(sub, sub.options);
    _settleOptionsOrFutures(sub, sub.futures);
  }

  function _fundPerp(SubAccount storage sub) internal {
    // uint256[] storage keys = sub.perps.keys;
    // mapping(uint256 => Position) storage values = sub.perps.values;
    // uint count = keys.length;
    // int128 balanceDelta;
    // for (uint i; i < count; ++i) {
    //   Position storage perp = values[keys[i]];
    //   // Upcasting from uint64 -> int128 is safe
    //   int128 currentPrice = state.prices.mark[perp.id];
    //   // Upcasting from uint64 -> int128 is safe
    //   int128 lastPrice = int128(uint128(perp.lastAppliedFundingIndex));
    //   balanceDelta += (currentPrice - lastPrice) * perp.balance;
    // }
    // sub.balanceE9 += balanceDelta;
  }

  function _settleOptionsOrFutures(SubAccount storage sub, PositionsMap storage positions) internal {
    // uint256[] storage keys = positions.keys;
    // mapping(uint256 => Position) storage values = positions.values;
    // uint count = keys.length;
    // uint256[] memory expiredOptionIDs = new uint256[](count);
    // uint expiredCount = 0;
    // mapping(uint256 => uint64) storage settlePrice = state.prices.settled;
    // // Update the balance after settling option/future
    // // Use balanceDelta to avoid updating state directly, which is gas expensive
    // int128 balanceDelta = 0;
    // for (uint i; i < count; ++i) {
    //   uint256 assetID = keys[i];
    //   Asset memory deriv = _parseAssetID(assetID);
    //   if (uint64(deriv.expiration) <= state.timestamp) {
    //     expiredOptionIDs[expiredCount++] = keys[i];
    //     int128 priceDelta = int128(uint128(settlePrice[assetID]));
    //     bool isOption = deriv.instrument == Kind.CALL || deriv.instrument == Kind.PUT;
    //     int128 fee = 0;
    //     if (isOption) {
    //       priceDelta -= int128(uint128(deriv.strikePrice));
    //       Position storage pos = values[assetID];
    //       bool nonDaily = deriv.expiration > pos.createdAt + 1 days;
    //       // Charge a settlement fee for non-daily option
    //       // if (nonDaily) fee = _getSettlementFee(deriv, pos.balance);
    //     }
    //     balanceDelta += priceDelta * values[assetID].balance - fee;
    //   }
    // }
    // // Remove the expired derivative
    // for (uint i; i < expiredCount; ++i) {
    //   remove(positions, expiredOptionIDs[expiredOptionIDs[i]]);
    // }
    // // Update total balance
    // sub.balanceE9 += balanceDelta;
  }

  // settlement_fee = min(underlying_charge, premium_cap)
  // function _getSettlementFee(Asset memory deriv, int64 size) internal view returns (int128) {
  //   mapping(uint256 => int64) storage prices = state.prices.mark;
  //   int128 underlyingCharge = (size * prices[deriv.underlyingAssetID] * SETTLEMENT_UNDERLYING_CHARGE_PCT) / 1e9;
  //   int128 premiumCap = (size * prices[deriv.quoteAssetID] * SETTLEMENT_TRADE_PRICE_PCT) / 1e9;
  //   return underlyingCharge < premiumCap ? underlyingCharge : premiumCap;
  // }

  // ------------------------------------------------------
  // End of Funding and Settlement
  // ------------------------------------------------------

  // FIXME: change when we finalize the asset ID encoding
  function _parseAssetID(uint256 assetID) internal pure returns (Asset memory) {
    Kind instr = Kind(assetID & 0xF);
    Currency underlying = Currency.ETH;
    Currency quote = Currency.USDC;
    uint32 expiry = 0;
    uint64 strike = 0;
    return Asset(instr, underlying, _getCurrencyAssetID(underlying), quote, _getCurrencyAssetID(quote), expiry, strike);
  }
}
