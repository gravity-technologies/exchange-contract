// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import {AccountRecoveryType as Recovery} from "../../../types/DataStructure.sol";

bytes32 constant _ADD_GUARDIAN_H = keccak256("AddAccountGuardian(address accountID,address signer,uint32 nonce)");

function hashAddGuardian(address accID, address signer, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_GUARDIAN_H, accID, signer, nonce));
}

bytes32 constant _DEL_GUARDIAN_H = keccak256("RemoveAccountGuardian(address accountID,address signer,uint32 nonce)");

function hashRemoveGuardian(address accID, address signer, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_GUARDIAN_H, accID, signer, nonce));
}

bytes32 constant _RECOVER_ADMIN_H = keccak256(
  "RecoverAccountAdmin(address accountID,uint8 recoveryType,address oldAdmin,address recoveryAdmin,uint32 nonce)"
);

function hashRecoverAdmin(
  address accID,
  Recovery typ,
  address oldAdmin,
  address newAdmin,
  uint32 nonce
) pure returns (bytes32) {
  return keccak256(abi.encode(_RECOVER_ADMIN_H, accID, uint8(typ), oldAdmin, newAdmin, nonce));
}
