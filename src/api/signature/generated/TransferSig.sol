// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.19;

bytes32 constant _DEPOSIT_PAYLOAD_TYPE_HASH = keccak256("DepositPayload(address fromEthAddress,address toSubAccount,uint64 numTokens)");

function getDepositPayloadPacketHash(address fromEthAddress, address toSubAccount, uint64 numTokens) pure returns (bytes32) {
  return keccak256(abi.encode(_DEPOSIT_PAYLOAD_TYPE_HASH, fromEthAddress, toSubAccount, numTokens));
}

bytes32 constant _WITHDRAWAL_PAYLOAD_TYPE_HASH = keccak256("WithdrawalPayload(address fromSubAccount,address toEthAddress,uint64 numTokens)");

function getWithdrawalPayloadPacketHash(address fromSubAccount, address toEthAddress, uint64 numTokens) pure returns (bytes32) {
  return keccak256(abi.encode(_WITHDRAWAL_PAYLOAD_TYPE_HASH, fromSubAccount, toEthAddress, numTokens));
}

bytes32 constant _TRANSFER_PAYLOAD_TYPE_HASH = keccak256("TransferPayload(address fromSubAccount,address toSubAccount,uint64 numTokens)");

function getTransferPayloadPacketHash(address fromSubAccount, address toSubAccount, uint64 numTokens) pure returns (bytes32) {
  return keccak256(abi.encode( _TRANSFER_PAYLOAD_TYPE_HASH, fromSubAccount, toSubAccount, numTokens));
}
