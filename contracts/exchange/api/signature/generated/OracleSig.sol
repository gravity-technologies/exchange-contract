// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _ORACLE_H = keccak256("Data(Values[] values,int256 timestamp)Values(int256 sid,int256 v)");
bytes32 constant _ORACLE_VALUE_H = keccak256("Values(int256 sid,int256 v)");

function hashOraclePrice(int64 timestamp, PriceEntry[] calldata prices) pure returns (bytes32) {
  bytes memory pricesEncoded;
  uint numValues = prices.length;
  for (uint i; i < numValues; ++i) {
    pricesEncoded = abi.encodePacked(
      pricesEncoded,
      keccak256(abi.encode(_ORACLE_VALUE_H, prices[i].assetID, prices[i].value))
    );
  }
  return keccak256(abi.encode(_ORACLE_H, keccak256(pricesEncoded), timestamp));
}

function hashOraclePriceEIP191(int64 timestamp, bytes calldata prices) pure returns (bytes32) {
  bytes memory dataEncoded;
  uint numValues = prices.length;
  for (uint i; i < numValues; ++i) {
    dataEncoded = abi.encodePacked(dataEncoded, prices[i].assetID, prices[i].value);
  }
  dataEncoded = abi.encodePacked(dataEncoded, timestamp);

  return keccak256(abi.encode("\x19Ethereum Signed Message:\n%v", dataEncoded));
}

function hashOracleFastHash(int64 timestamp, PriceEntry[] calldata prices) pure returns (bytes32) {
  bytes32 data;
  uint numValues = prices.length;
  for (uint i; i < numValues; ++i) {
    data = data ^ prices[i].assetID ^ bytes32(uint(prices[i].value));
  }

  return keccak256(abi.encode("\x19Ethereum Signed Message:\n", data));
}

bytes32 constant _SETTLEMENT_PRICE_H = keccak256("Data(int256 sid,int256 v,int256 timestamp,bool is_final)");

function hashSettlementTick(int64 timestamp, SettlementTick calldata entry) pure returns (bytes32) {
  return keccak256(abi.encode(_SETTLEMENT_PRICE_H, entry.assetID, entry.value, timestamp, entry.isFinal));
}
