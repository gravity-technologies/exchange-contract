// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./ConfigContract.sol";
import "./signature/generated/OracleSig.sol";
import "../types/DataStructure.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";

contract OracleContract is ConfigContract {
  using BIMath for BI;

  int64 private constant maxPriceTickSigExpirationNs = 60_000_000_000; // 1 minute in nanos

  function markPriceTick(int64 timestamp, uint64 txID, PriceEntry[] calldata prices, Signature calldata sig) public {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashOraclePrice(sig.expiration, prices);
    _verifyPriceUpdateSig(timestamp, hash, sig);
    // ------- End of Signature Verification -------

    mapping(bytes32 => uint64) storage marks = state.prices.mark;
    uint len = prices.length;

    for (uint i; i < len; ++i) {
      bytes32 assetID = prices[i].assetID;
      Kind kind = assetGetKind(assetID);

      // Only spot, futures, and options are allowed to have mark prices
      require(uint(kind) > 0 && uint(kind) < 6, "wrong kind");

      // Non-Spot assets must be quoted in USD
      require(kind == Kind.SPOT || assetGetQuote(assetID) == Currency.USD, "spot price must be quoted in USD");

      // If instrument has expired, mark price should not be updated
      int64 expiry = assetGetExpiration(assetID);
      require(expiry == 0 || expiry >= timestamp, "invalid expiry");

      marks[assetID] = uint64(uint256(prices[i].value));
    }
  }

  function settlementPriceTick(
    int64 timestamp,
    uint64 txID,
    PriceEntry[] calldata prices,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashOraclePrice(sig.expiration, prices);
    _verifyPriceUpdateSig(timestamp, hash, sig);
    // ------- End of Signature Verification -------

    mapping(bytes32 => SettlementPriceEntry) storage settlements = state.prices.settlement;
    uint len = prices.length;
    for (uint i; i < len; ++i) {
      bytes32 assetID = prices[i].assetID;

      // Asset kind must be settlement and quoted in USD
      require(
        assetGetKind(assetID) == Kind.SETTLEMENT && assetGetQuote(assetID) == Currency.USD,
        "must be settlement kind in USD"
      );

      int64 expiry = assetGetExpiration(assetID);
      require(expiry > 0 && expiry <= timestamp, "invalid settlement expiry");

      uint64 newPrice = uint64(uint256(prices[i].value));
      SettlementPriceEntry storage oldSettlementPrice = settlements[assetID];
      require(!oldSettlementPrice.isSet || newPrice == oldSettlementPrice.value, "settlemente price changed");

      // Update the settlement price
      settlements[prices[i].assetID] = SettlementPriceEntry(true, newPrice);
    }
  }

  function fundingPriceTick(
    int64 timestamp,
    uint64 txID,
    PriceEntry[] calldata prices,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashOraclePrice(sig.expiration, prices);
    _requireValidNoExipry(hash, sig);
    // ------- End of Signature Verification -------

    mapping(bytes32 => int64) storage fundings = state.prices.fundingIndex;
    uint len = prices.length;
    for (uint i; i < len; ++i) {
      bytes32 assetID = prices[i].assetID;
      // Verify
      require(assetGetKind(assetID) == Kind.PERPS && assetGetQuote(assetID) != Currency.USD, "wrong kind or quote");

      bytes32 subKey = bytes32(uint(assetGetUnderlying(assetID)));
      (int64 fundingHigh, bool highFound) = _getCentibeepConfig2D(ConfigID.FUNDING_RATE_HIGH, subKey);
      require(highFound, "fundingHigh not found");
      (int64 fundingLow, bool lowFound) = _getCentibeepConfig2D(ConfigID.FUNDING_RATE_LOW, subKey);
      require(lowFound, "fundingLow not found");
      int64 newFunding = int64(prices[i].value);
      require(newFunding >= fundingLow && newFunding <= fundingHigh, "price out of range");

      // IMPT: This is important to prevent funding ticks from coming in at quick succession to manipulate funding index
      require(sig.expiration >= state.prices.fundingTime + 1 minutes);

      PriceEntry calldata entry = prices[i];
      (uint64 markPrice, bool found) = _getMarkPrice9Decimals(entry.assetID);
      require(found, "no mark price");
      // Funding (10 & 11.1): Computing the new funding index (a way to do lazy funding payments on-demand)
      int256 delta = BI(int(uint(markPrice)), PRICE_DECIMALS)
        .mul(BI(entry.value, CENTIBEEP_DECIMALS))
        .div(BI(TIME_FACTOR, 0))
        .toInt256(PRICE_DECIMALS);
      fundings[entry.assetID] += int64(delta);
    }
    state.prices.fundingTime = sig.expiration;
  }

  function interestRateTick(
    int64 timestamp,
    uint64 txID,
    PriceEntry[] calldata rates,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashOraclePrice(sig.expiration, rates);
    _verifyPriceUpdateSig(timestamp, hash, sig);
    // ------- End of Signature Verification -------

    mapping(bytes32 => int32) storage interest = state.prices.interest;
    uint len = rates.length;
    for (uint i; i < len; ++i) {
      bytes32 assetID = rates[i].assetID;

      // Asset kind must be rate and quoted in USD
      require(assetGetKind(assetID) == Kind.RATE && assetGetQuote(assetID) == Currency.USD, "wrong kind or quote");

      // If instrument has expired, interest rate should not be updated
      int64 expiry = assetGetExpiration(assetID);
      require(expiry == 0 || expiry >= timestamp, ERR_INVALID_PRICE_UPDATE);

      interest[rates[i].assetID] = int32(rates[i].value);
    }
  }

  function _verifyPriceUpdateSig(int64 timestamp, bytes32 hash, Signature calldata sig) internal {
    require(
      sig.expiration >= timestamp - maxPriceTickSigExpirationNs && sig.expiration <= timestamp,
      "price tick expired"
    );

    // Prevent replay
    require(!state.replay.executed[hash], "replayed payload");
    _requireValidNoExipry(hash, sig);
    state.replay.executed[hash] = true;
  }
}
