// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

bytes32 constant _ADD_RECOVERY_WALLET_H = keccak256(
  "AddRecoveryWallet(address accountID,address signer,address recoverySigner,uint32 nonce)"
);

function hashAddRecoveryWallet(
  address accID,
  address signer,
  address recoverySigner,
  uint32 nonce
) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_RECOVERY_WALLET_H, accID, signer, recoverySigner, nonce));
}

bytes32 constant _DEL_RECOVERY_WALLET_H = keccak256(
  "RemoveRecoveryWallet(address accountID,address signer,address recoverySigner,uint32 nonce)"
);

function hashRemoveRecoveryWallet(
  address accID,
  address signer,
  address recoverySigner,
  uint32 nonce
) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_RECOVERY_WALLET_H, accID, signer, recoverySigner, nonce));
}

bytes32 constant _RECOVER_WALLET_H = keccak256(
  "RecoverWallet(address accountID,address oldSigner,address recoverySigner,address newSigner,uint32 nonce)"
);

function hashRecoverWallet(
  address accID,
  address oldSigner,
  address recoverySigner,
  address newSigner,
  uint32 nonce
) pure returns (bytes32) {
  return keccak256(abi.encode(_RECOVER_WALLET_H, accID, oldSigner, recoverySigner, newSigner, nonce));
}
