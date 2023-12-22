// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

bytes32 constant _DEPOSIT_H = keccak256(
  "DepositPayload(address fromEthAddress,uint64 toSubAccount,uint64 numTokens,uint32 nonce)"
);

function hashDeposit(
  address fromEthAddress,
  uint64 toSubAccount,
  uint64 numTokens,
  uint32 salt
) pure returns (bytes32) {
  return keccak256(abi.encode(_DEPOSIT_H, fromEthAddress, toSubAccount, numTokens, salt));
}

bytes32 constant _WITHDRAWAL_H = keccak256(
  "WithdrawalPayload(uint64 fromSubAccount,address toEthAddress,uint64 numTokens,uint32 nonce)"
);

function hashWithdrawal(
  uint64 fromSubAccount,
  address toEthAddress,
  uint64 numTokens,
  uint32 salt
) pure returns (bytes32) {
  return keccak256(abi.encode(_WITHDRAWAL_H, fromSubAccount, toEthAddress, numTokens, salt));
}

bytes32 constant _TRANSFER_H = keccak256(
  "TransferPayload(uint64 fromSubAccount,uint64 toSubAccount,uint64 numTokens, uint32 nonce)"
);

function hashTransfer(
  uint64 fromSubAccount,
  uint64 toSubAccount,
  uint64 numTokens,
  uint32 salt
) pure returns (bytes32) {
  return keccak256(abi.encode(_TRANSFER_H, fromSubAccount, toSubAccount, numTokens, salt));
}
