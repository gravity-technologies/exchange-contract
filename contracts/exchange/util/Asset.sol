// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

struct Asset {
  Kind kind;
  Currency underlying;
  Currency quote;
  int64 expiration;
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
      int64(int(id >> 32)), // Expiration
      uint64(id >> 96) // Strike Price
    );
}

function assetToID(Asset memory asset) pure returns (bytes32) {
  uint id = uint(asset.kind) |
    (uint(asset.underlying) << 8) |
    (uint(asset.quote) << 16) |
    (uint(uint64(asset.expiration)) << 32) |
    (uint(asset.strikePrice) << 96);
  return bytes32(id);
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

function assetGetExpiration(bytes32 assetID) pure returns (int64) {
  return int64(int(uint(assetID >> 32)));
}

function assetGetStrikePrice(bytes32 assetID) pure returns (uint64) {
  return uint64(uint(assetID >> 96));
}

bytes32 constant quoteMask = bytes32(~(uint(0xFF) << 16));

function assetSetQuote(bytes32 assetID, Currency quote) pure returns (bytes32) {
  return (assetID & quoteMask) | (bytes32(uint(quote)) << 16);
}
