// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _SCHEDULE_SIMPLE_CROSS_MAINTENANCE_MARGIN_TIERS_H = keccak256(
  "ScheduleSimpleCrossMaintenanceMarginTiers(bytes32 assetKUQ,MarginTier[] tiers,uint32 nonce,int64 expiration)MarginTier(uint64 bracketStart,uint32 rate)"
);

function hashScheduleSimpleCrossMaintenanceMarginTiers(
  bytes32 kud,
  MarginTier[] calldata marginTiers,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(
        _SCHEDULE_SIMPLE_CROSS_MAINTENANCE_MARGIN_TIERS_H,
        kud,
        hashSimpleCrossMaintenanceMarginTiers(marginTiers),
        nonce,
        expiration
      )
    );
}

bytes32 constant _SET_SIMPLE_CROSS_MAINTENANCE_MARGIN_TIERS_H = keccak256(
  "SetSimpleCrossMaintenanceMarginTiers(bytes32 assetKUQ,MarginTier[] tiers,uint32 nonce,int64 expiration)MarginTier(uint64 bracketStart,uint32 rate)"
);

function hashSetSimpleCrossMaintenanceMarginTiers(
  bytes32 kud,
  MarginTier[] calldata marginTiers,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(
        _SET_SIMPLE_CROSS_MAINTENANCE_MARGIN_TIERS_H,
        kud,
        hashSimpleCrossMaintenanceMarginTiers(marginTiers),
        nonce,
        expiration
      )
    );
}

bytes32 constant _CURRENCY_MARGIN_TIER_H = keccak256("MarginTier(uint64 bracketStart,uint32 rate)");

function hashSimpleCrossMaintenanceMarginTiers(MarginTier[] calldata tiers) pure returns (bytes32) {
  uint numTiers = tiers.length;
  bytes32[] memory hashedTiers = new bytes32[](numTiers);
  for (uint i; i < numTiers; ++i) {
    MarginTier calldata tier = tiers[i];
    hashedTiers[i] = keccak256(abi.encode(_CURRENCY_MARGIN_TIER_H, tier.bracketStart, tier.rate));
  }
  return keccak256(abi.encodePacked(hashedTiers));
}
