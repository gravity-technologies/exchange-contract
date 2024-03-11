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
/// LSB                                                                                                            MSB
///     +--------------------------------------------------------------------------------------------------------+
///   0 | Kind (1B) | Underlying (1B) | Quote (1B) | Reserved (1B) | Expiration (8B) | Strike (8B)| Zero Padding | 255
///     +-----------------------------------------------------------------------------------------+--------------+
function parseAssetID(bytes32 assetID) pure returns (Asset memory) {
  uint id = uint(assetID);
  return
    Asset(
      Kind(id & 0xFF),
      Currency((id >> 8) & 0xFF), // Underlying
      Currency((id >> 16) & 0xFF), // Quote
      uint64((id >> 32) & 0xFFFFFFFFFFFFFFFF), // Expiration
      uint64((id >> 96) & 0xFFFFFFFFFFFFFFFF) // Strike Price
    );
}

function assetToID(Asset memory asset) pure returns (uint) {
  return
    uint(asset.kind) |
    (uint(asset.underlying) << 8) |
    (uint(asset.quote) << 16) |
    (uint(asset.expiration) << 32) |
    (uint(asset.strikePrice) << 96);
}

function assetGetKind(bytes32 assetID) pure returns (Kind) {
  return Kind(uint(assetID) & 0xFF);
}

function assetGetUnderlying(bytes32 assetID) pure returns (Currency) {
  return Currency((uint(assetID) >> 8) & 0xFF);
}

function assetGetQuote(bytes32 assetID) pure returns (Currency) {
  return Currency((uint(assetID) >> 16) & 0xFF);
}

function assetGetExpiration(bytes32 assetID) pure returns (uint64) {
  return uint64((uint(assetID) >> 32) & 0xFFFFFFFFFFFFFFFF);
}

function assetGetStrikePrice(bytes32 assetID) pure returns (uint64) {
  return uint64((uint(assetID) >> 96) & 0xFFFFFFFFFFFFFFFF);
}
