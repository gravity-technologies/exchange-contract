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

bytes32 constant _INITIALIZE_CONFIG_H = keccak256(
  "InitializeConfig(InitializeConfigItem[] items,uint32 nonce,int64 expiration)InitializeConfigItem(uint8 key,bytes32 subKey,bytes32 value)"
);

bytes32 constant _INITIALIZE_CONFIG_ITEM_H = keccak256("InitializeConfigItem(uint8 key,bytes32 subKey,bytes32 value)");

function hashInitializeConfig(
  InitializeConfigItem[] calldata items,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  bytes32[] memory hashedItems = new bytes32[](items.length);
  for (uint256 i = 0; i < items.length; i++) {
    hashedItems[i] = keccak256(abi.encode(_INITIALIZE_CONFIG_ITEM_H, items[i].key, items[i].subKey, items[i].value));
  }
  return keccak256(abi.encode(_INITIALIZE_CONFIG_H, keccak256(abi.encodePacked(hashedItems)), nonce, expiration));
}
