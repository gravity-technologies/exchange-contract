// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./signature/generated/OracleSig.sol";
import "../types/DataStructure.sol";
import "../util/Asset.sol";

contract OracleContract is BaseContract {
  function markPriceTick(int64 timestamp, uint64 txID, PriceEntry[] calldata prices) external {
    _setSequence(timestamp, txID);
    mapping(bytes32 => uint64) storage marks = state.prices.mark;
    uint len = prices.length;
    for (uint i; i < len; ++i) marks[prices[i].assetID] = uint64(uint256(prices[i].value));
  }

  function settlementPriceTick(int64 timestamp, uint64 txID, PriceEntry[] calldata prices) external {
    _setSequence(timestamp, txID);
    mapping(bytes32 => uint64) storage settlements = state.prices.settlement;
    uint len = prices.length;
    for (uint i; i < len; ++i) settlements[prices[i].assetID] = uint64(uint256(prices[i].value));
  }

  function fundingPriceTick(
    int64 timestamp,
    uint64 txID,
    int64 fundingTime,
    PriceEntry[] calldata prices,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    _preventReplay(hashOraclePrice(fundingTime, prices), sig);
    // ------- End of Signature Verification -------

    // FIXME
    mapping(bytes32 => int64) storage fundings = state.prices.fundingIndex;
    uint len = prices.length;
    for (uint i; i < len; ++i) fundings[prices[i].assetID] = int64(prices[i].value);
    state.prices.fundingTime = fundingTime;
  }

  function interestRateTick(int64 timestamp, uint64 txID, PriceEntry[] calldata rates) external {
    _setSequence(timestamp, txID);
    mapping(bytes32 => int32) storage interest = state.prices.interest;
    uint len = rates.length;
    for (uint i; i < len; ++i) interest[rates[i].assetID] = int32(rates[i].value);
  }
}
