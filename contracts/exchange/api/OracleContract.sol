// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./BaseContract.sol";
import "./ConfigContract.sol";
import "../types/DataStructure.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";

contract OracleContract is ConfigContract {
  using BIMath for BI;

  int64 private constant ONE_MINUTE_NANOS = 60 * 1e9; // 1 minute in nanos

  /// @dev The maximum signature expiry time for price ticks. Any signature with a longer expiry time will be rejected
  int64 private constant MAX_PRICE_TICK_SIG_EXPIRY = ONE_MINUTE_NANOS;

  bytes32 constant _SETTLEMENT_PRICE_H = keccak256("Data(int256 sid,int256 v,int256 timestamp,bool is_final)");
  bytes32 constant _ORACLE_H = keccak256("Data(Values[] values,int256 timestamp)Values(int256 sid,int256 v)");
  bytes32 constant _ORACLE_VALUE_H = keccak256("Values(int256 sid,int256 v)");

  /// @dev Update the oracle mark prices for spot, futures, and options
  ///
  /// @param timestamp the timestamp of the price tick
  /// @param txID the transaction ID of the price tick
  /// @param prices the prices of the assets
  /// @param sig the signature of the price tick
  function markPriceTick(int64 timestamp, uint64 txID, PriceEntry[] calldata prices, Signature calldata sig) external {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashOraclePrice(sig.expiration, prices);
    _verifyPriceUpdateSig(timestamp, hash, sig);
    // ------- End of Signature Verification -------

    mapping(bytes32 => uint64) storage marks = state.prices.mark;
    uint256 len = prices.length;

    for (uint256 i; i < len; ++i) {
      bytes32 assetID = prices[i].assetID;
      Kind kind = assetGetKind(assetID);

      // Only spot, futures, and options are allowed to have mark prices
      require(uint256(kind) > 0 && uint256(kind) < 6, "wrong kind");

      // Non-Spot assets must be quoted in USD
      require(kind == Kind.SPOT || assetGetQuote(assetID) == Currency.USD, "spot price must be quoted in USD");

      // If instrument has expired, mark price should not be updated
      int64 expiry = assetGetExpiration(assetID);
      require(expiry == 0 || expiry >= timestamp, "invalid expiry");

      marks[assetID] = uint64(uint256(prices[i].value));
    }
  }

  /// @dev Update the settlement prices
  ///
  /// @param timestamp the timestamp of the price tick
  /// @param txID the transaction ID of the price tick
  /// @param prices the settlement prices
  function settlementPriceTick(int64 timestamp, uint64 txID, SettlementTick[] calldata prices) external {
    _setSequence(timestamp, txID);
    mapping(bytes32 => SettlementPriceEntry) storage settlements = state.prices.settlement;
    uint256 len = prices.length;
    for (uint256 i; i < len; ++i) {
      SettlementTick calldata entry = prices[i];
      bytes32 assetID = bytes32(uint256(entry.assetID));
      // Asset kind must be settlement and quoted in USD
      require(
        assetGetKind(assetID) == Kind.SETTLEMENT && assetGetQuote(assetID) == Currency.USD,
        "must be settlement kind in USD"
      );
      // Only instruments with expiry can have settlement price
      // If instrument has not expired, settlement price should not be updated
      int64 expiry = assetGetExpiration(assetID);
      require(expiry > 0 && expiry <= timestamp, "invalid settlement expiry");
      // IMPT: This is an extremely important check to prevent settlement price from being updated
      // Given that we do lazy settlement, we need to ensure that the settlement price is not updated
      // Otherwise, we can end up in scenarios where everyone's settlements don't check out.
      uint64 newPrice = uint64(uint256(entry.value));
      SettlementPriceEntry storage oldSettlementPrice = settlements[assetID];
      require(!oldSettlementPrice.isSet || newPrice == oldSettlementPrice.value, "settlemente price changed");
      require(entry.isFinal, "settlement price not final");
      // Update the settlement price
      settlements[assetID] = SettlementPriceEntry(true, newPrice);
      // ---------- Signature Verification -----------
      bytes32 hash = keccak256(abi.encode(_SETTLEMENT_PRICE_H, entry.assetID, entry.value, timestamp, entry.isFinal));
      _verifyPriceUpdateSig(timestamp, hash, entry.signature);
      // ------- End of Signature Verification -------
    }
  }

  /// @dev Update the funding prices for perpetuals
  ///
  /// @param timestamp the timestamp of the price tick
  /// @param txID the transaction ID of the price tick
  /// @param prices the funding tick values
  /// @param sig the signature of the price tick
  function fundingPriceTick(
    int64 timestamp,
    uint64 txID,
    PriceEntry[] calldata prices,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashOraclePrice(sig.expiration, prices);
    _verifyFundingTickSig(timestamp, hash, sig);
    // ------- End of Signature Verification -------

    mapping(bytes32 => int64) storage fundings = state.prices.fundingIndex;
    uint256 len = prices.length;
    for (uint256 i; i < len; ++i) {
      bytes32 assetID = prices[i].assetID;
      // Verify
      require(assetGetKind(assetID) == Kind.PERPS && assetGetQuote(assetID) != Currency.USD, "wrong kind or quote");

      // Funding rate must be within the configured range
      // IMPT: This is important to prevent large funding rates from coming in, and quickly manipulating the funding index
      // Funding (9.2): Applying a cap (or floor)
      // Applying in both MD and SM: MD for reporting clamped rate, SM for trustless guarantees
      // Funding Rate = Max( Min(Funding Rate, 5%), -5%)
      bytes32 subKey = bytes32(uint256(assetGetUnderlying(assetID)));
      (int64 fundingHigh, bool highFound) = _getCentibeepConfig2D(ConfigID.FUNDING_RATE_HIGH, subKey);
      require(highFound, "fundingHigh not found");
      (int64 fundingLow, bool lowFound) = _getCentibeepConfig2D(ConfigID.FUNDING_RATE_LOW, subKey);
      require(lowFound, "fundingLow not found");
      int64 newFunding = int64(prices[i].value);
      require(newFunding >= fundingLow && newFunding <= fundingHigh, "price out of range");

      // Update
      // DO NOT USE MARK PRICE FROM FUNDING TICK, SINCE THAT IS MORE EASY TO MANIPULATE
      PriceEntry calldata entry = prices[i];
      (uint64 markPrice, bool found) = _getMarkPrice9Decimals(entry.assetID);
      require(found, "no mark price");
      // Funding (10 & 11.1): Computing the new funding index (a way to do lazy funding payments on-demand)
      int64 delta = BI(int256(uint256(markPrice)), PRICE_DECIMALS)
        .mul(BI(entry.value, CENTIBEEP_DECIMALS))
        .div(BI(TIME_FACTOR, 0))
        .toInt64(PRICE_DECIMALS);
      fundings[entry.assetID] += delta;
    }
    state.prices.fundingTime = sig.expiration;
  }

  /// @dev Update the interest rates
  ///
  /// @param timestamp the timestamp of the price tick
  /// @param txID the transaction ID of the price tick
  /// @param rates the interest rate values
  /// @param sig the signature of the price tick
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
    uint256 len = rates.length;
    for (uint256 i; i < len; ++i) {
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
    require(_getBoolConfig2D(ConfigID.ORACLE_ADDRESS, _addressToConfig(sig.signer)), "signer is not oracle");

    require(
      sig.expiration >= timestamp - MAX_PRICE_TICK_SIG_EXPIRY && sig.expiration <= timestamp,
      "price tick expired"
    );

    // Prevent replay
    require(!state.replay.executed[hash], "replayed payload");
    _requireValidNoExipry(hash, sig);
    state.replay.executed[hash] = true;
  }

  function _verifyFundingTickSig(int64 timestamp, bytes32 hash, Signature calldata sig) internal {
    // IMPT: This is important to prevent funding ticks from coming in at quick succession to manipulate funding index
    require(sig.expiration >= state.prices.fundingTime + ONE_MINUTE_NANOS, "funding reate less than 1 minute apart");

    require(_getBoolConfig2D(ConfigID.MARKET_DATA_ADDRESS, _addressToConfig(sig.signer)), "signer is not market data");

    require(
      sig.expiration >= timestamp - MAX_PRICE_TICK_SIG_EXPIRY && sig.expiration <= timestamp,
      "signature expired"
    );

    // Prevent replay
    require(!state.replay.executed[hash], "replayed payload");
    _requireValidNoExipry(hash, sig);
    state.replay.executed[hash] = true;
  }

  function hashOraclePrice(int64 timestamp, PriceEntry[] calldata prices) private pure returns (bytes32) {
    bytes memory pricesEncoded;
    uint256 numValues = prices.length;
    for (uint256 i; i < numValues; ++i) {
      pricesEncoded = abi.encodePacked(
        pricesEncoded,
        keccak256(abi.encode(_ORACLE_VALUE_H, prices[i].assetID, prices[i].value))
      );
    }
    return keccak256(abi.encode(_ORACLE_H, keccak256(pricesEncoded), timestamp));
  }
}
