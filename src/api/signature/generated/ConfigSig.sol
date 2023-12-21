// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.19;

import "../../../types/DataStructure.sol";

// keccak256("ScheduleConfig(uint8 key,bytes32 value,uint32 nonce)");
bytes32 constant _SCHEDULE_CONFIG_H = bytes32(0xd2e4668a3738dc6aaf9b47c7bf3eecfd828c00addb19327a393673d4581550d0);

function hashScheduleConfig(ConfigID key, bytes32 value, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_SCHEDULE_CONFIG_H, uint8(key), value, nonce));
}

// keccak256("SetConfig(uint8 key,bytes32 value,uint32 nonce)");
bytes32 constant _SET_CONFIG_H = bytes32(0xea2d826fce92032df776220a3f4f9a8403256b3a6338e412a34aa728a1c6eb5a);

function hashSetConfig(ConfigID key, bytes32 value, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_SET_CONFIG_H, uint8(key), value, nonce));
}
