// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.19;

import "../../../DataStructure.sol";

// keccak256("SetSubAccountMarginTypePayload(address subAccountID,uint8 marginType,uint32 nonce)");
bytes32 constant _SET_SUB_MARGIN_H = bytes32(0x178137bbe59243e5e269559ce483e30e48a0774adcfddd1c8ce0a894d1f7838a);

function hashSetMarginType(address subID, MarginType margin, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_SET_SUB_MARGIN_H, subID, margin, nonce));
}

// keccak256("AddSubAccountSignerPayload(address subAccountID,address signer,uint16 permissions,uint32 nonce)");
bytes32 constant _ADD_SIGNER_H = bytes32(0xd59e1ab6cca3d74ebce727c2bf03bb77eb784e098e96eade280dc9d53db70ef8);

function hashAddSigner(address subID, address signer, uint64 perms, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_SIGNER_H, subID, signer, perms, nonce));
}

// keccak256("SetSubAccountSignerPermissionsPayload(address subAccountID,address signer,uint64 permissions,uint32 nonce)");
bytes32 constant _SET_SIGNER_PERM_H = bytes32(0x856d9fa4fec1fe28e7cd92cd884864064a9142f1f5a9989b4dd210eec18f80c7);

function hashSetSignerPermissions(address subID, address signer, uint64 perms, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_SET_SIGNER_PERM_H, subID, signer, perms, nonce));
}

// keccak256("RemoveSubAccountSignerPayload(address subAccountID,address signer,uint32 nonce)");
bytes32 constant _DEL_SIGNER_H = bytes32(0x8e6a492465a061fb8dec2b243e58fbcdf0be6d2f9b133ada4e7b9e1acae6f18f);

function hashRemoveSigner(address subID, address signer, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_SIGNER_H, subID, signer, nonce));
}

// keccak256("AddSessionKeyPayload(address sessionKey,uint64 keyExpiry)");
bytes32 constant _ADD_SESSION_KEY_H = bytes32(0x0b69f852130d50178374c92a4a2fffb7b2febbf99ad113833de090bc8489f493);

function hashAddSessionKey(address key, uint64 keyExpiry) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_SESSION_KEY_H, key, keyExpiry));
}
