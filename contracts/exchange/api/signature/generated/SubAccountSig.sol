// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _CREATE_SUBACCOUNT_H = keccak256(
  "CreateSubAccount(address accountID,uint64 subAccountID,uint8 quoteCurrency,uint8 marginType,uint32 nonce,int64 expiration)"
);

function hashCreateSubAccount(
  address accID,
  uint64 subID,
  Currency currency,
  MarginType margin,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_CREATE_SUBACCOUNT_H, accID, subID, uint8(currency), uint8(margin), nonce, expiration));
}

bytes32 constant _SET_SUB_MARGIN_H = keccak256(
  "SetSubAccountMarginType(uint64 subAccountID,uint8 marginType,uint32 nonce,int64 expiration)"
);

function hashSetMarginType(uint64 subID, MarginType margin, uint32 nonce, int64 expiration) pure returns (bytes32) {
  return keccak256(abi.encode(_SET_SUB_MARGIN_H, subID, margin, nonce, expiration));
}

bytes32 constant _ADD_SUB_SIGNER_H = keccak256(
  "AddSubAccountSigner(uint64 subAccountID,address signer,uint64 permissions,uint32 nonce,int64 expiration)"
);

function hashAddSubAccountSigner(
  uint64 subID,
  address signer,
  uint64 perms,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_SUB_SIGNER_H, subID, signer, perms, nonce, expiration));
}

bytes32 constant _SET_SIGNER_PERM_H = keccak256(
  "SetSubAccountSignerPermissions(uint64 subAccountID,address signer,uint64 permissions,uint32 nonce,int64 expiration)"
);

function hashSetSignerPermissions(
  uint64 subID,
  address signer,
  uint64 perms,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_SET_SIGNER_PERM_H, subID, signer, perms, nonce, expiration));
}

bytes32 constant _DEL_SIGNER_H = keccak256(
  "RemoveSubAccountSigner(uint64 subAccountID,address signer,uint32 nonce,int64 expiration)"
);

function hashRemoveSigner(uint64 subID, address signer, uint32 nonce, int64 expiration) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_SIGNER_H, subID, signer, nonce, expiration));
}

bytes32 constant _ADD_SESSION_KEY_H = keccak256("AddSessionKey(address sessionKey,int64 keyExpiry)");

function hashAddSessionKey(address key, int64 keyExpiry) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_SESSION_KEY_H, key, keyExpiry));
}
