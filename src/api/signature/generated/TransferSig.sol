// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.19;

// keccak256("DepositPayload(address fromEthAddress,address toSubAccount,uint64 numTokens,uint32 nonce)");
bytes32 constant _DEPOSIT_H = bytes32(0x3c06830c70447a8c52bfbd3575f08f7b015c665e9c5d92879b47bc3d0d86c55c);

function hashDeposit(
  address fromEthAddress,
  address toSubAccount,
  uint64 numTokens,
  uint32 salt
) pure returns (bytes32) {
  return keccak256(abi.encode(_DEPOSIT_H, fromEthAddress, toSubAccount, numTokens, salt));
}

// keccak256("WithdrawalPayload(address fromSubAccount,address toEthAddress,uint64 numTokens,uint32 nonce)");
bytes32 constant _WITHDRAWAL_H = bytes32(0x3b2fc78a24d18937b89fb6ed3c588b7ac173d98ceb62b553453f9d4ffa2dcb8f);

function hashWithdrawal(
  address fromSubAccount,
  address toEthAddress,
  uint64 numTokens,
  uint32 salt
) pure returns (bytes32) {
  return keccak256(abi.encode(_WITHDRAWAL_H, fromSubAccount, toEthAddress, numTokens, salt));
}

// keccak256("TransferPayload(address fromSubAccount,address toSubAccount,uint64 numTokens, uint32 nonce)");
bytes32 constant _TRANSFER_H = bytes32(0x4e55c2d33692b45cf96f58c425950674d73c9e33a46fc26c6b5375f3bf764a9c);

function hashTransfer(
  address fromSubAccount,
  address toSubAccount,
  uint64 numTokens,
  uint32 salt
) pure returns (bytes32) {
  return keccak256(abi.encode(_TRANSFER_H, fromSubAccount, toSubAccount, numTokens, salt));
}
