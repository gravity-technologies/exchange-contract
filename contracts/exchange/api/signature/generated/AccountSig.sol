// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

bytes32 constant _CREATE_ACCOUNT_H = keccak256("CreateAccount(address accountID,uint32 nonce,int64 expiration)");

function hashCreateAccount(address accID, uint32 nonce, int64 expiration) pure returns (bytes32) {
  return keccak256(abi.encode(_CREATE_ACCOUNT_H, accID, nonce, expiration));
}

bytes32 constant _ADD_ACC_SIGNER_H = keccak256(
  "AddAccountSigner(address accountID,address signer,uint64 permissions,uint32 nonce,int64 expiration)"
);

function hashAddAccountSigner(
  address accID,
  address signer,
  uint64 permissions,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_ACC_SIGNER_H, accID, signer, permissions, nonce, expiration));
}

bytes32 constant _DEL_ACC_SIGNER_H = keccak256(
  "RemoveAccountSigner(address accountID,address signer,uint32 nonce,int64 expiration)"
);

function hashRemoveAccountSigner(address accID, address signer, uint32 nonce, int64 expiration) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_ACC_SIGNER_H, accID, signer, nonce, expiration));
}

bytes32 constant _SET_ACC_MULTISIG_THRESHOLD_H = keccak256(
  "SetAccountMultiSigThreshold(address accountID,uint8 multiSigThreshold,uint32 nonce,int64 expiration)"
);

function hashSetMultiSigThreshold(
  address accID,
  uint8 threshold,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_SET_ACC_MULTISIG_THRESHOLD_H, accID, threshold, nonce, expiration));
}

bytes32 constant _ADD_WITHDRAW_ADDR_H = keccak256(
  "AddWithdrawalAddress(address accountID,address withdrawalAddress,uint32 nonce,int64 expiration)"
);

function hashAddWithdrawalAddress(
  address accID,
  address withdrawal,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_WITHDRAW_ADDR_H, accID, withdrawal, nonce, expiration));
}

bytes32 constant _DEL_WITHDRAW_ADDR_H = keccak256(
  "RemoveWithdrawalAddress(address accountID,address withdrawalAddress,uint32 nonce,int64 expiration)"
);

function hashRemoveWithdrawalAddress(
  address accID,
  address withdrawal,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_WITHDRAW_ADDR_H, accID, withdrawal, nonce, expiration));
}

bytes32 constant _ADD_TRANSFER_ACCOUNT_H = keccak256(
  "AddTransferAccount(address accountID,address transferAccountID,uint32 nonce,int64 expiration)"
);

function hashAddTransferAccount(
  address accID,
  address transferAccountID,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_ADD_TRANSFER_ACCOUNT_H, accID, transferAccountID, nonce, expiration));
}

bytes32 constant _DEL_TRANSFER_ACC_H = keccak256(
  "RemoveTransferAccount(address accountID,address transferAccountID,uint32 nonce,int64 expiration)"
);

function hashRemoveTransferAccount(
  address accID,
  address transferAccountID,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_DEL_TRANSFER_ACC_H, accID, transferAccountID, nonce, expiration));
}
