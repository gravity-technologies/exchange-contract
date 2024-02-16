// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _CREATE_ACCOUNT_H = keccak256("CreateAccount(address accountID,uint32 nonce)");

function hashCreateAccount(address accID, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_CREATE_ACCOUNT_H, accID, nonce));
}

bytes32 constant _ADD_ACC_SIGNER_H = keccak256(
  "AddAccountSigner(address accountID,address signer,uint64 permissions,uint32 nonce)"
);

function hashAddAccountSigner(address accID, address signer, uint64 permissions, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_ACC_SIGNER_H, accID, signer, permissions, nonce));
}

bytes32 constant _DEL_ACC_SIGNER_H = keccak256("RemoveAccountSigner(address accountID,address signer,uint32 nonce)");

function hashRemoveAccountSigner(address accID, address signer, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_ACC_SIGNER_H, accID, signer, nonce));
}

bytes32 constant _SET_ACC_MULTISIG_THRESHOLD_H = keccak256(
  "SetAccountMultiSigThreshold(address accountID,uint8 multiSigThreshold,uint32 nonce)"
);

function hashSetMultiSigThreshold(address accID, uint8 threshold, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_SET_ACC_MULTISIG_THRESHOLD_H, accID, threshold, nonce));
}

bytes32 constant _ADD_WITHDRAW_ADDR_H = keccak256(
  "AddWithdrawalAddress(address accountID,address withdrawalAddress,uint32 nonce)"
);

function hashAddWithdrawalAddress(address accID, address withdrawal, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_WITHDRAW_ADDR_H, accID, withdrawal, nonce));
}

bytes32 constant _DEL_WITHDRAW_ADDR_H = keccak256(
  "RemoveWithdrawalAddress(address accountID,address withdrawalAddress,uint32 nonce)"
);

function hashRemoveWithdrawalAddress(address accID, address withdrawal, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_WITHDRAW_ADDR_H, accID, withdrawal, nonce));
}

bytes32 constant _ADD_TRANSFER_SUB_ACCOUNT_H = keccak256(
  "AddTransferSubAccount(address accountID,address transferAccountID,uint32 nonce)"
);

function hashAddTransferAccount(address accID, address transferAccountID, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_TRANSFER_SUB_ACCOUNT_H, accID, transferAccountID, nonce));
}

bytes32 constant _DEL_TRANSFER_SUB_ACC_H = keccak256(
  "RemoveTransferSubAccount(address accountID,address transferAccountID,uint32 nonce)"
);

function hashRemoveTransferAccount(address accID, address transferAccountID, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_TRANSFER_SUB_ACC_H, accID, transferAccountID, nonce));
}
