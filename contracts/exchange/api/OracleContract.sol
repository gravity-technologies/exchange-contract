pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./ConfigContract.sol";
import "./signature/generated/OracleSig.sol";
import "../types/DataStructure.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";
import "../interfaces/IOracle.sol";

contract OracleContract is IOracle, ConfigContract {
  using BIMath for BI;

  int64 private constant ONE_MINUTE_NANOS = 60_000_000_000; // 1 minute in nanos

  /// @dev The maximum signature expiry time for price ticks. Any signature with a longer expiry time will be rejected
  int64 private constant MAX_PRICE_TICK_SIG_EXPIRY = ONE_MINUTE_NANOS;

  /// @dev set the system timestamp and last transactionID.
  /// Require timestamp and the transactionID to increase
  /// This is in contrast to _setSequence in BaseContract, where the transactionID to be in sequence without any gap
  /// This is because a mark price tick can be skipped if superceded before being used.
  function _setSequenceMarkPriceTick(int64 timestamp, uint64 txID) private {
    require(timestamp >= state.timestamp, "invalid timestamp");
    require(txID > state.lastTxID, "invalid txID");
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
      require(uint(kind) > 0 && uint(kind) < 6, "wrong kind");

      // Non-Spot assets must be quoted in USD
      require(kind == Kind.SPOT || assetGetQuote(assetID) == Currency.USD, "spot price must be quoted in USD");

      // If instrument has expired, mark price should not be updated
      int64 expiry = assetGetExpiration(assetID);
      require(expiry == 0 || expiry >= timestamp, "invalid expiry");

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

    // ---------- Signature Verification -----------
    bytes32 hash = hashOraclePrice(sig.expiration, prices);
    _verifyFundingTickSig(timestamp, hash, sig);
    // ------- End of Signature Verification -------

    mapping(bytes32 => int64) storage fundings = state.prices.fundingIndex;
    uint len = prices.length;
    for (uint i; i < len; ++i) {
      bytes32 assetID = prices[i].assetID;
      // Verify
      require(assetGetKind(assetID) == Kind.PERPS && assetGetQuote(assetID) != Currency.USD, "wrong kind or quote");

      // Funding rate must be within the configured range
      // IMPT: This is important to prevent large funding rates from coming in, and quickly manipulating the funding index
      bytes32 subKey = bytes32(uint(assetGetUnderlying(assetID)));
      (int64 fundingHigh, bool highFound) = _getCentibeepConfig2D(ConfigID.FUNDING_RATE_HIGH, subKey);
      require(highFound, "fundingHigh not found");
      (int64 fundingLow, bool lowFound) = _getCentibeepConfig2D(ConfigID.FUNDING_RATE_LOW, subKey);
      require(lowFound, "fundingLow not found");
      int64 newFunding = SafeCast.toInt64(prices[i].value);
      require(newFunding >= fundingLow && newFunding <= fundingHigh, "funding index out of range");

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
}
