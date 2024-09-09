// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _SCHEDULE_CONFIG_H = keccak256(
  "ScheduleConfig(uint8 key,bytes32 subKey,bytes32 value,uint32 nonce,int64 expiration)"
);

function hashScheduleConfig(
  ConfigID key,
  bytes32 subKey,
  bytes32 value,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_SCHEDULE_CONFIG_H, uint8(key), subKey, value, nonce, expiration));
}

bytes32 constant _SET_CONFIG_H = keccak256(
  "SetConfig(uint8 key,bytes32 subKey,bytes32 value,uint32 nonce,int64 expiration)"
);

function hashSetConfig(
  ConfigID key,
  bytes32 subKey,
  bytes32 value,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_SET_CONFIG_H, uint8(key), subKey, value, nonce, expiration));
}

bytes32 constant _SCHEDULE_CURRENCY_MARGIN_TIERS_H = keccak256(
  "ScheduleCurrencyMarginTiers(uint8 currency,MarginTier[] marginTiers,uint32 nonce,int64 expiration)MarginTier(uint32 bracketStart,uint32 maintenanceMarginRate)"
);

function hashScheduleCurrencyMarginTiers(
  Currency currency,
  MarginTier[] calldata marginTiers,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(
        _SCHEDULE_CURRENCY_MARGIN_TIERS_H,
        uint8(currency),
        hashCurrencyMarginTiers(marginTiers),
        nonce,
        expiration
      )
    );
}

bytes32 constant _SET_CURRENCY_MARGIN_TIERS_H = keccak256(
  "SetCurrencyMarginTiers(uint8 currency,MarginTier[] marginTiers,uint32 nonce,int64 expiration)MarginTier(uint32 bracketStart,uint32 maintenanceMarginRate)"
);

function hashSetCurrencyMarginTiers(
  Currency currency,
  MarginTier[] calldata marginTiers,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(_SET_CURRENCY_MARGIN_TIERS_H, uint8(currency), hashCurrencyMarginTiers(marginTiers), nonce, expiration)
    );
}

bytes32 constant _CURRENCY_MARGIN_TIER_H = keccak256("MarginTier(uint32 bracketStart,uint32 maintenanceMarginRate)");

function hashCurrencyMarginTiers(MarginTier[] calldata tiers) pure returns (bytes32) {
  uint numTiers = tiers.length;
  bytes32[] memory hashedTiers = new bytes32[](numTiers);
  for (uint i; i < numTiers; ++i) {
    MarginTier calldata tier = tiers[i];
    hashedTiers[i] = keccak256(abi.encode(_CURRENCY_MARGIN_TIER_H, tier.bracketStart, tier.maintenanceMarginRate));
  }
  return keccak256(abi.encodePacked(hashedTiers));
}
