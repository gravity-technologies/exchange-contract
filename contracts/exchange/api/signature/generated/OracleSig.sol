// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _ORACLE_H = keccak256("FundingTick(int256 timestamp,Values[] Values)Values(int256 sid, int256 v)");

function hashOraclePrice(int64 timestamp, PriceEntry[] calldata prices) pure returns (bytes32) {
  bytes memory pricesEncoded;
  uint numValues = prices.length;
  for (uint i; i < numValues; ++i) {
    pricesEncoded = abi.encodePacked(pricesEncoded, prices[i].assetID, prices[i].value);
  }
  return keccak256(abi.encode(_ORACLE_H, int256(timestamp), keccak256(abi.encode(_ORACLE_H, pricesEncoded))));
}
