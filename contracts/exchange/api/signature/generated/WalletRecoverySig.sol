// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

bytes32 constant _ADD_RECOVERY_ADDRESS_H = keccak256(
  "AddRecoveryAddress(address accountID,address recoverySigner,uint32 nonce)"
);

function hashAddRecoveryAddress(address accID, address recoverySigner, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_RECOVERY_ADDRESS_H, accID, recoverySigner, nonce));
}

bytes32 constant _DEL_RECOVERY_ADDRESS_H = keccak256(
  "RemoveRecoveryAddress(address accountID,address recoverySigner,uint32 nonce)"
);

function hashRemoveRecoveryAddress(address accID, address recoverySigner, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_RECOVERY_ADDRESS_H, accID, recoverySigner, nonce));
}

bytes32 constant _RECOVER_ADDRESS_H = keccak256(
  "RecoverAddress(address accountID,address oldSigner,address newSigner,uint32 nonce)"
);

function hashRecoverAddress(address accID, address oldSigner, address newSigner, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_RECOVER_ADDRESS_H, accID, oldSigner, newSigner, nonce));
}
