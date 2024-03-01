// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "../types/DataStructure.sol";
import "../util/Asset.sol";

struct PriceEntry {
  bytes32 assetID;
  uint64 price;
}

struct RateEntry {
  bytes32 assetID;
  int32 rate;
}

contract OracleContract is BaseContract {
  function markPriceTick(int64 timestamp, uint64 txID, PriceEntry[] calldata prices) external {
    _setSequence(timestamp, txID);
    mapping(bytes32 => uint64) storage marks = state.prices.mark;
    uint len = prices.length;
    for (uint i; i < len; ++i) marks[prices[i].assetID] = prices[i].price;
  }

  function settlementPriceTick(int64 timestamp, uint64 txID, PriceEntry[] calldata prices) external {
    _setSequence(timestamp, txID);
    mapping(bytes32 => uint64) storage settlements = state.prices.settlement;
    uint len = prices.length;
    for (uint i; i < len; ++i) settlements[prices[i].assetID] = prices[i].price;
  }

  function fundingPriceTick(int64 timestamp, uint64 txID, int64 fundingTime, PriceEntry[] calldata prices) external {
    _setSequence(timestamp, txID);

    // FIXME
    mapping(Currency => int64) storage fundings = state.prices.fundingIndex;
    uint len = prices.length;
    for (uint i; i < len; ++i) fundings[assetGetUnderlying(prices[i].assetID)] = int64(prices[i].price);
    state.prices.fundingTime = fundingTime;
  }

  function interestRateTick(int64 timestamp, uint64 txID, RateEntry[] calldata rates) external {
    _setSequence(timestamp, txID);
    mapping(bytes32 => int32) storage interest = state.prices.interest;
    uint len = rates.length;
    for (uint i; i < len; ++i) interest[rates[i].assetID] = rates[i].rate;
  }
}
