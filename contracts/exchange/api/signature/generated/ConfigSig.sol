// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _SCHEDULE_CONFIG_H = keccak256("ScheduleConfig(uint8 key,bytes32 subKey,bytes32 value,uint32 nonce)");

function hashScheduleConfig(ConfigID key, bytes32 subKey, bytes32 value, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_SCHEDULE_CONFIG_H, uint8(key), subKey, value, nonce));
}

bytes32 constant _SET_CONFIG_H = keccak256("SetConfig(uint8 key,bytes32 subKey,bytes32 value,uint32 nonce)");

function hashSetConfig(ConfigID key, bytes32 subKey, bytes32 value, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_SET_CONFIG_H, uint8(key), subKey, value, nonce));
}
