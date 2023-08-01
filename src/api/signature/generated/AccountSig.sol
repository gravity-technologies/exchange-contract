// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.19;

import {Currency, MarginType} from "../../../DataStructure.sol";

bytes32 constant _CREATE_SUBACCOUNT_PAYLOAD_TYPEHASH = keccak256("CreateSubAccountPayload(uint32 accountID,address subAccountID,uint8 quoteCurrency,uint8 marginType,uint32 nonce)");

function getCreateSubAccountPayloadPacketHash(uint32 accountID, address subAccountID, Currency quoteCurrency, MarginType marginType, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_CREATE_SUBACCOUNT_PAYLOAD_TYPEHASH, accountID, subAccountID, uint8(quoteCurrency), uint8(marginType), nonce));
}

bytes32 constant _ADD_ACCOUNT_ADMIN_PAYLOAD_TYPE_HASH = keccak256("AddAccountAdminPayload(uint32 accountID,address signer,uint32 nonce)");

function getAddAccountAdminPayloadPacketHash(uint32 accountID, address signer, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_ACCOUNT_ADMIN_PAYLOAD_TYPE_HASH, accountID, signer, nonce));
}

bytes32 constant _REMOVE_ACCOUNT_ADMIN_PAYLOAD_TYPE_HASH = keccak256("RemoveAccountAdminPayload(uint32 accountID,address signer,uint32 nonce)");

function getRemoveAccountAdminPayloadPacketHash(uint32 accountID, address signer, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_REMOVE_ACCOUNT_ADMIN_PAYLOAD_TYPE_HASH, accountID, signer, nonce));
}

bytes32 constant _SET_ACCOUNT_MULTI_SIG_THRESHOLD_PAYLOAD_TYPE_HASH = keccak256("SetAccountMultiSigThresholdPayload(uint32 accountID,uint8 multiSigThreshold,uint32 nonce)");

function getSetAccountMultiSigThresholdPayloadPacketHash(uint32 accountID, uint8 multiSigThreshold, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_SET_ACCOUNT_MULTI_SIG_THRESHOLD_PAYLOAD_TYPE_HASH, accountID, multiSigThreshold, nonce));
}

bytes32 constant _ADD_WITHDRAWAL_ADDRESS_PAYLOAD_TYPE_HASH = keccak256("AddWithdrawalAddressPayload(uint32 accountID,address withdrawalAddress,uint32 nonce)");

function getAddWithdrawalAddressPayloadPacketHash(uint32 accountID, address withdrawalAddress, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_WITHDRAWAL_ADDRESS_PAYLOAD_TYPE_HASH, accountID, withdrawalAddress, nonce));
}

bytes32 constant _REMOVE_WITHDRAWAL_ADDRESS_PAYLOAD_TYPE_HASH = keccak256("RemoveWithdrawalAddressPayload(uint32 accountID,address withdrawalAddress,uint32 nonce)");

function getRemoveWithdrawalAddressPayloadPacketHash(uint32 accountID, address withdrawalAddress, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_REMOVE_WITHDRAWAL_ADDRESS_PAYLOAD_TYPE_HASH, accountID, withdrawalAddress, nonce));
}

bytes32 constant _ADD_TRANSFER_SUB_ACCOUNT_PAYLOAD_TYPE_HASH = keccak256("AddTransferSubAccountPayload(uint32 accountID,address transferSubAccount,uint32 nonce)");

function getAddTransferSubAccountPayloadPacketHash(uint32 accountID, address transferSubAccount, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_TRANSFER_SUB_ACCOUNT_PAYLOAD_TYPE_HASH, accountID, transferSubAccount, nonce));
}

bytes32 constant _REMOVE_TRANSFER_SUB_ACCOUNT_PAYLOAD_TYPE_HASH = keccak256("RemoveTransferSubAccountPayload(uint32 accountID,address transferSubAccount,uint32 nonce)");

function getRemoveTransferSubAccountPayloadPacketHash(uint32 accountID, address transferSubAccount, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_REMOVE_TRANSFER_SUB_ACCOUNT_PAYLOAD_TYPE_HASH, accountID, transferSubAccount, nonce));
}

