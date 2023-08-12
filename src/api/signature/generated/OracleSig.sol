// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.19;

import "../../../DataStructure.sol";

bytes32 constant _PRICE_TICK_H = keccak256(
  "PriceTickPayload(AssetPriceEntry[] priceTick,uint32 nonce)AssetPriceEntry(uint128 id,uint128 price)"
);

bytes32 constant _ASSET_PRICE_ENTRY_H = keccak256("AssetPriceEntry(uint128 id,uint128 price)");

function hashAssetPriceEntry(AssetPriceEntry[] calldata _input) pure returns (bytes32) {
  bytes memory encoded;
  for (uint i = 0; i < _input.length; i++) encoded = abi.encodePacked(encoded, hashAssetPriceEntry(_input[i]));
  return keccak256(encoded);
}

function hashPriceTick(AssetPriceEntry[] calldata prices, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_PRICE_TICK_H, hashAssetPriceEntry(prices), nonce));
}

function hashAssetPriceEntry(AssetPriceEntry calldata price) pure returns (bytes32) {
  return keccak256(abi.encode(_ASSET_PRICE_ENTRY_H, price.id, price.price));
}

bytes32 constant _RATE_TICK_H = keccak256(
  "RateTickPayload(RiskFreeRateEntry[] rateTick,uint32 nonce)RiskFreeRateEntry(uint128 id,uint128 rate)"
);

bytes32 constant _RISK_FREE_RATE_ENTRY_H = keccak256("RiskFreeRateEntry(uint128 id,uint128 rate)");

function hashRiskFreeRateEntry(RiskFreeRateEntry[] calldata _input) pure returns (bytes32) {
  bytes memory encoded;
  for (uint i = 0; i < _input.length; i++) encoded = abi.encodePacked(encoded, hashRiskFreeRateEntry(_input[i]));
  return keccak256(encoded);
}

function hashRateTick(RiskFreeRateEntry[] calldata entries, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_RATE_TICK_H, hashRiskFreeRateEntry(entries), nonce));
}

function hashRiskFreeRateEntry(RiskFreeRateEntry calldata _input) pure returns (bytes32) {
  return keccak256(abi.encode(_RISK_FREE_RATE_ENTRY_H, _input.id, _input.rate));
}

bytes32 constant _FUNDING_TICK_PAYLOAD_H = keccak256(
  "FundingTickPayload(FundingTick funding,uint32 nonce)FundingTick(uint128 id)"
);

function hashFundingTickPayload(FundingTick calldata tick, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_FUNDING_TICK_PAYLOAD_H, hashFundingTick(tick), nonce));
}

bytes32 constant _FUNDING_TICK_H = keccak256("FundingTick(uint128 id)");

function hashFundingTick(FundingTick calldata tick) pure returns (bytes32) {
  return keccak256(abi.encode(_FUNDING_TICK_PAYLOAD_H, tick.id));
}

bytes32 constant _SETTLEMENT_TICK_PAYLOAD_H = keccak256(
  "SettlementTickPayload(SettlementTick settlement,uint32 nonce)SettlementTick(uint128 id)"
);

function hashSettlementTickPayload(SettlementTick calldata tick, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_SETTLEMENT_TICK_PAYLOAD_H, hashSettlementTick(tick), nonce));
}

bytes32 constant _SETTLEMENT_TICK_H = keccak256("SettlementTick(uint128 id)");

function hashSettlementTick(SettlementTick calldata tick) pure returns (bytes32) {
  return keccak256(abi.encode(_SETTLEMENT_TICK_H, tick.id));
}
