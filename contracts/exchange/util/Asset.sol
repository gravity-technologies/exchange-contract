// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

struct AssetDTO {
  Kind kind;
  Currency underlying;
  Currency quote;
  uint64 expiration;
  uint64 strikePrice;
}

function assetIDtoDTO(uint256 assetID) pure returns (AssetDTO memory) {
  // TODO
  return AssetDTO({kind: Kind.PERPS, underlying: Currency.BTC, quote: Currency.USDT, expiration: 0, strikePrice: 0});
}

function assetDTOToID(AssetDTO memory asset) pure returns (uint256) {
  // TODO
  return 0;
}

function assetGetUnderlying(uint256 assetID) pure returns (Currency) {
  return Currency.BTC;
}

function assetGetQuote(uint256 assetID) pure returns (Currency) {
  return Currency.BTC;
}

function assetGetKind(uint256 assetID) pure returns (Kind) {
  return Kind.PERPS;
}

function assetGetStrikePrice(uint256 assetID) pure returns (uint64) {
  return 0;
}

function assetGetExpiration(uint256 assetID) pure returns (uint64) {
  return 0;
}
