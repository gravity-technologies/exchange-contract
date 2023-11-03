// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.19;

import {AccountRecoveryType as Recovery} from "../../../DataStructure.sol";

// keccak256("AddAccountGuardian(uint32 accountID,address signer,uint32 nonce)");
bytes32 constant _ADD_GUARDIAN_H = bytes32(0xfa60a1fcd920572ddfb19818360dd471bfd34008d635d67640de725583efa10b);

function hashAddGuardian(uint32 accID, address signer, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_GUARDIAN_H, accID, signer, nonce));
}

// keccak256("RemoveAccountGuardian(uint32 accountID,address signer,uint32 nonce)");
bytes32 constant _DEL_GUARDIAN_H = bytes32(0xba1639bd5b83296895cec80afd343ea7c4c8def60cd5e50c29ec20c6a85648a5);

function hashRemoveGuardian(uint32 accID, address signer, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_GUARDIAN_H, accID, signer, nonce));
}

// keccak256("RecoverAccountAdmin(uint32 accountID,uint8 recoveryType,address oldAdmin,address recoveryAdmin,uint32 nonce)");
bytes32 constant _RECOVER_ADMIN_H = bytes32(0x172b9cadc30752a2b2fa5b30c58d75fa112339b91739a34ef8055ec6a5f405e0);

function hashRecoverAdmin(
  uint32 accID,
  Recovery typ,
  address oldAdmin,
  address newAdmin,
  uint32 nonce
) pure returns (bytes32) {
  return keccak256(abi.encode(_RECOVER_ADMIN_H, accID, uint8(typ), oldAdmin, newAdmin, nonce));
}
