pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./ConfigContract.sol";
import "./signature/generated/OracleSig.sol";
import "../types/DataStructure.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";
import "../interfaces/IOracle.sol";
import "../common/Error.sol";

contract OracleContract is IOracle, ConfigContract {
  using BIMath for BI;

  int64 private constant ONE_MINUTE_NANOS = 60_000_000_000; // 1 minute in nanos

  /// @dev The maximum signature expiry time for price ticks. Any signature with a longer expiry time will be rejected
  int64 private constant MAX_PRICE_TICK_SIG_EXPIRY = ONE_MINUTE_NANOS;
  uint8 private constant DEFAULT_FUNDING_INTERVAL_HOURS = 8;
  int32 private constant DEFAULT_FUNDING_RATE_HIGH_CENTIBEEPS = 3_00_00; // 3%
  int32 private constant DEFAULT_FUNDING_RATE_LOW_CENTIBEEPS = -3_00_00; // -3%

  /// @dev set the system timestamp and last transactionID.
  /// Require timestamp and the transactionID to increase
  /// This is in contrast to _setSequence in BaseContract, where the transactionID to be in sequence without any gap
  /// This is because a mark price tick can be skipped if superceded before being used.
  function _setSequenceMarkPriceTick(int64 timestamp, uint64 txID) private {
    require(timestamp >= state.timestamp, "Oracle: timestamp must not go backwards");
    require(txID > state.lastTxID, "Oracle: transaction ID must increase");
    state.timestamp = timestamp;
    state.lastTxID = txID;
  }

  /// @dev Update the oracle mark prices for spot, futures, and options
  ///
  /// @param timestamp the timestamp of the price tick
  /// @param txID the transaction ID of the price tick
  /// @param prices the prices of the assets
  /// @param sig the signature of the price tick
  function markPriceTick(
    int64 timestamp,
    uint64 txID,
    PriceEntry[] calldata prices,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequenceMarkPriceTick(timestamp, txID);

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
      require(uint(kind) > 0 && uint(kind) < 6, "Oracle: asset kind not supported for mark price");

      // Non-Spot assets must be quoted in USD
      require(kind == Kind.SPOT || assetGetQuote(assetID) == Currency.USD, "Oracle: non-spot asset must be USD quoted");

      // If instrument has expired, mark price should not be updated
      int64 expiry = assetGetExpiration(assetID);
      require(expiry == 0 || expiry >= timestamp, "Oracle: instrument already expired");

      marks[assetID] = SafeCast.toUint64(SafeCast.toUint256(prices[i].value));
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
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    // IMPT: This is important to prevent funding ticks from coming in at quick succession to manipulate funding index
    require(sig.expiration >= state.prices.fundingTime + ONE_MINUTE_NANOS, "Oracle: funding tick submitted too soon");

    // ---------- Signature Verification -----------
    bytes32 hash = hashOraclePrice(sig.expiration, prices);
    _verifyFundingTickSig(timestamp, hash, sig);
    // ------- End of Signature Verification -------

    mapping(bytes32 => int64) storage fundings = state.prices.fundingIndex;
    uint len = prices.length;
    for (uint i; i < len; ++i) {
      bytes32 assetID = prices[i].assetID;
      // Verify
      require(
        assetGetKind(assetID) == Kind.PERPS && assetGetQuote(assetID) != Currency.USD,
        "Oracle: invalid asset kind or quote for funding tick"
      );

      // Funding rate must be within the configured range
      // IMPT: This is important to prevent large funding rates from coming in, and quickly manipulating the funding index
      bytes32 subKey = bytes32(uint(assetGetUnderlying(assetID)));
      (int64 fundingHigh, bool highFound) = _getCentibeepConfig2D(ConfigID.FUNDING_RATE_HIGH, subKey);
      require(highFound, "Oracle: missing funding high configuration");
      (int64 fundingLow, bool lowFound) = _getCentibeepConfig2D(ConfigID.FUNDING_RATE_LOW, subKey);
      require(lowFound, "Oracle: missing funding low configuration");
      int64 newFunding = SafeCast.toInt64(prices[i].value);
      require(newFunding >= fundingLow && newFunding <= fundingHigh, "Oracle: funding index out of configured range");

      // Update
      // DO NOT USE MARK PRICE FROM FUNDING TICK, SINCE THAT IS MORE EASY TO MANIPULATE
      PriceEntry calldata entry = prices[i];
      BI memory markPrice = _requireAssetPriceBI(entry.assetID);
      // Funding (10 & 11.1): Computing the new funding index (a way to do lazy funding payments on-demand)
      int64 delta = markPrice.mul(BI(entry.value, CENTIBEEP_DECIMALS)).div(BI(TIME_FACTOR, 0)).toInt64(PRICE_DECIMALS);
      fundings[entry.assetID] += delta;
    }
    state.prices.fundingTime = sig.expiration;
  }

  /// @dev Update the funding prices for perpetuals
  ///
  /// @param timestamp the timestamp of the price tick
  /// @param txID the transaction ID of the price tick
  /// @param entries the funding tick values
  /// @param sig the signature of the price tick
  function fundingTickV2(
    int64 timestamp,
    uint64 txID,
    FundingRateEntry[] calldata entries,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashFundingTickV2(entries, sig.nonce, sig.expiration);
    _verifyFundingTickSig(timestamp, hash, sig);
    // ------- End of Signature Verification -------

    // Validation
    mapping(bytes32 => int64) storage fundings = state.prices.fundingIndex;
    uint len = entries.length;
    for (uint i; i < len; ++i) {
      FundingRateEntry calldata entry = entries[i];
      bytes32 assetID = entry.asset;
      // Verify
      require(
        assetGetKind(assetID) == Kind.PERPS && assetGetQuote(assetID) != Currency.USD,
        "Oracle: invalid asset kind or quote for funding tick"
      );

      // Funding rate must be within the configured range
      // IMPT: This is important to prevent large funding rates from coming in, and quickly manipulating the funding index
      FundingInfo storage cfg = state.fundingConfigs[assetID];
      bool hasFundingConfig = cfg.intervalHours > 0;
      int32 fundingRateHighCentiBeeps = hasFundingConfig
        ? cfg.fundingRateHighCentiBeeps
        : DEFAULT_FUNDING_RATE_HIGH_CENTIBEEPS;
      int32 fundingRateLowCentiBeeps = hasFundingConfig
        ? cfg.fundingRateLowCentiBeeps
        : DEFAULT_FUNDING_RATE_LOW_CENTIBEEPS;

      int64 expectedDuration = int64(uint64(entry.intervalHours)) * ONE_HOUR_NANOS;
      int64 actualDuration = entry.intervalEnd - entry.intervalStart;

      require(actualDuration >= expectedDuration, "IntervalDurationMismatch");
      require(
        entry.fundingRateCentiBeeps >= fundingRateLowCentiBeeps &&
          entry.fundingRateCentiBeeps <= fundingRateHighCentiBeeps,
        "FundingRateOutOfRange"
      );
      // actualDuration can >= expectedDuration because of clusterTick mechanics
      // if (actualDuration < expectedDuration) {
      //   revert IntervalDurationMismatch();
      // }
      // if (
      //   entry.fundingRateCentiBeeps < fundingRateLowCentiBeeps ||
      //   entry.fundingRateCentiBeeps > fundingRateHighCentiBeeps
      // ) {
      //   revert FundingRateOutOfRange();
      // }

      // Update
      // DO NOT USE MARK PRICE FROM FUNDING TICK, SINCE THAT IS MORE EASY TO MANIPULATE
      BI memory markPrice = _requireAssetPriceBI(assetID);

      // V2: Apply funding rate directly without 480 divisor
      // Rate already represents the full interval amount (1h/2h/4h/8h)
      BI memory fundingRatePct = BI(entry.fundingRateCentiBeeps, CENTIBEEP_DECIMALS);
      BI memory fundingIndexChange = markPrice.mul(fundingRatePct);
      fundings[assetID] += fundingIndexChange.toInt64(PRICE_DECIMALS);
    }
    state.prices.fundingTime = sig.expiration;
  }

  function _verifyPriceUpdateSig(int64 timestamp, bytes32 hash, Signature calldata sig) internal {
    require(
      _getBoolConfig2D(ConfigID.ORACLE_ADDRESS, _addressToConfig(sig.signer)),
      "Oracle: signer not authorized for price updates"
    );

    require(
      sig.expiration >= timestamp - MAX_PRICE_TICK_SIG_EXPIRY && sig.expiration <= timestamp,
      "Oracle: price tick signature expired"
    );

    // Prevent replay
    require(!state.replay.executed[hash], "Oracle: payload already executed");
    _requireValidNoExipry(hash, sig);
    state.replay.executed[hash] = true;
  }

  function _verifyFundingTickSig(int64 timestamp, bytes32 hash, Signature calldata sig) internal {
    require(
      _getBoolConfig2D(ConfigID.MARKET_DATA_ADDRESS, _addressToConfig(sig.signer)),
      "Oracle: signer not authorized for funding updates"
    );

    require(
      sig.expiration >= timestamp - MAX_PRICE_TICK_SIG_EXPIRY && sig.expiration <= timestamp,
      "Oracle: funding tick signature expired"
    );

    // Prevent replay
    require(!state.replay.executed[hash], "Oracle: payload already executed");
    _requireValidNoExipry(hash, sig);
    state.replay.executed[hash] = true;
  }
}
