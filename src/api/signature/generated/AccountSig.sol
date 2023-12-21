// SPDX-License-Identifier: UNLICENSED
// Code generated, DO NOT EDIT.
pragma solidity ^0.8.19;

import "../../../types/DataStructure.sol";

// keccak256("CreateSubAccount(uint32 accountID,address subAccountID,uint8 quoteCurrency,uint8 marginType,uint32 nonce)");
bytes32 constant _CREATE_SUBACCOUNT_H = bytes32(0x6cafe27909faed17c65dae473a28613eec3d8c662247fdc3921f8f98a0c15385);

function hashCreateSubAccount(
  uint32 accID,
  address subID,
  Currency currency,
  MarginType margin,
  uint32 nonce
) pure returns (bytes32) {
  return keccak256(abi.encode(_CREATE_SUBACCOUNT_H, accID, subID, uint8(currency), uint8(margin), nonce));
}

// keccak256("AddAccountSigner(uint32 accountID,address signer,uint32 nonce)");
bytes32 constant _ADD_ACC_ADMIN_H = bytes32(0x5d49d0bdce6989db153e909d9324897811055dd2d77a42e5d721c2c2e62b01f2);

function hashAddAccountAdmin(uint32 accID, address signer, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_ACC_ADMIN_H, accID, signer, nonce));
}

bytes32 constant _DEL_ACC_ADMIN_H = keccak256("RemoveAccountSigner(uint32 accountID,address signer,uint32 nonce)");

function hashRemoveAccountAdmin(uint32 accID, address signer, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_ACC_ADMIN_H, accID, signer, nonce));
}

// keccak256("SetAccountMultiSigThreshold(uint32 accountID,uint8 multiSigThreshold,uint32 nonce)");
bytes32 constant _SET_ACC_MULTISIG_THRESHOLD_H = bytes32(
  0xf02109d81822adc4631ca8f4de6649cd9f896b0ff41e1d70c785ab5595b64864
);

function hashSetMultiSigThreshold(uint32 accID, uint8 threshold, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_SET_ACC_MULTISIG_THRESHOLD_H, accID, threshold, nonce));
}

// keccak256("AddWithdrawalAddress(uint32 accountID,address withdrawalAddress,uint32 nonce)");
bytes32 constant _ADD_WITHDRAW_ADDR_H = bytes32(0x9e8a1878fae8de3592d5098fecf1565e16e59b189f680bd515547496d3ac568f);

function hashAddWithdrawalAddress(uint32 accID, address withdrawal, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_WITHDRAW_ADDR_H, accID, withdrawal, nonce));
}

// keccak256("RemoveWithdrawalAddress(uint32 accountID,address withdrawalAddress,uint32 nonce)");
bytes32 constant _DEL_WITHDRAW_ADDR_H = bytes32(0x9bdf4cdc0901fd4d667b7e4a5c38c94d0960541b89bfe980615cda58a6c4a04e);

function hashRemoveWithdrawalAddress(uint32 accID, address withdrawal, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_WITHDRAW_ADDR_H, accID, withdrawal, nonce));
}

// keccak256("AddTransferSubAccount(uint32 accountID,address transferSubAccount,uint32 nonce)");
bytes32 constant _ADD_TRANSFER_SUB_ACCOUNT_H = bytes32(
  0xb7805997639b66d0086af76a62a08cc634d761a336b73c3a461ca55a36fc3127
);

function hashAddTransferSubAccount(uint32 accID, address subAcc, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_TRANSFER_SUB_ACCOUNT_H, accID, subAcc, nonce));
}

// keccak256("RemoveTransferSubAccount(uint32 accountID,address transferSubAccount,uint32 nonce)");
bytes32 constant _DEL_TRANSFER_SUB_ACC_H = bytes32(0xbd26f40b857bde8f289dc51b02f136361a4a9e21e37a2711100649894c24de26);

function hashRemoveTransferSubAccount(uint32 accID, address subAcc, uint32 nonce) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_TRANSFER_SUB_ACC_H, accID, subAcc, nonce));
}
