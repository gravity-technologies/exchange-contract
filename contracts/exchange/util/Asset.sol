// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

struct Asset {
  Kind kind;
  Currency underlying;
  Currency quote;
  uint64 expiration;
  uint64 strikePrice;
}

/// @dev Parse the assetID into its components
///
/// LSB                                                                                           MSB
///    ------------------------------------------------------------------------------------------
/// 0 | Kind (1B) | Underlying (1B) | Quote (1B) | Reserved (1B) | Expiration (8B) | Strike (8B)|
///   ------------------------------------------------------------------------------------------
function parseAssetID(bytes32 assetID) pure returns (Asset memory) {
  uint id = uint256(assetID);
  return
    Asset(
      Kind(id & 0xFF),
      Currency((id >> 8) & 0xFF), // Underlying
      Currency((id >> 16) & 0xFF), // Quote
      uint64((id >> 32) & 0xFFFFFFFF), // Expiration
      uint64((id >> 64) & 0xFFFFFFFF) // Strike Price
    );
}

function assetToID(Asset memory asset) pure returns (uint256) {
  return
    uint256(asset.kind) |
    (uint256(asset.underlying) << 8) |
    (uint256(asset.quote) << 16) |
    (uint256(asset.expiration) << 32) |
    (uint256(asset.strikePrice) << 64);
}

function assetGetKind(bytes32 assetID) pure returns (Kind) {
  return Kind(uint256(assetID) & 0xFF);
}

function assetGetUnderlying(bytes32 assetID) pure returns (Currency) {
  return Currency((uint256(assetID) >> 8) & 0xFF);
}

function assetGetQuote(bytes32 assetID) pure returns (Currency) {
  return Currency((uint256(assetID) >> 16) & 0xFF);
}

function assetGetExpiration(bytes32 assetID) pure returns (uint64) {
  return uint64((uint256(assetID) >> 32) & 0xFFFFFFFF);
}

function assetGetStrikePrice(bytes32 assetID) pure returns (uint64) {
  return uint64((uint256(assetID) >> 64) & 0xFFFFFFFF);
}
