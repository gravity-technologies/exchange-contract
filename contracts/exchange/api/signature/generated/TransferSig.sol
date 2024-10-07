// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _WITHDRAWAL_H = keccak256(
  "Withdrawal(address fromAccount,address toEthAddress,uint8 tokenCurrency,uint64 numTokens,uint32 nonce,int64 expiration)"
);

function hashWithdrawal(
  address fromAccountID,
  address toEthAddress,
  Currency currency,
  uint64 numTokens,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(abi.encode(_WITHDRAWAL_H, fromAccountID, toEthAddress, uint8(currency), numTokens, nonce, expiration));
}

bytes32 constant _TRANSFER_H = keccak256(
  "Transfer(address fromAccount,uint64 fromSubAccount,address toAccount,uint64 toSubAccount,uint8 tokenCurrency,uint64 numTokens,uint32 nonce,int64 expiration)"
);

function hashTransfer(
  address fromAccount,
  uint64 fromSubID,
  address toAccount,
  uint64 toSubID,
  Currency currency,
  uint64 numTokens,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(_TRANSFER_H, fromAccount, fromSubID, toAccount, toSubID, uint8(currency), numTokens, nonce, expiration)
    );
}
