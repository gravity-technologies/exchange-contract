// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Account, State, AccountRecoveryType, Signature} from '../DataStructure.sol';
import {addressExists, removeAddress} from '../util/Address.sol';
import {checkAndUpdateTimestampAndTxID, getAccountByID} from '../util/Util.sol';

function AddAccountGuardian(
  State storage state,
  uint64 timestamp,
  uint64 txID,
  uint32 accountID,
  address signer // Signature[] memory signatures
) {
  checkAndUpdateTimestampAndTxID(state, timestamp, txID);
  Account storage account = getAccountByID(state, accountID);
  if (addressExists(account.guardians, signer)) {
    // No op if the guardian already exists
    return;
  }

  // TODO verify signature
  account.guardians.push(signer);
}

function RemoveAccountGuardian(
  State storage state,
  uint64 timestamp,
  uint64 txID,
  uint32 accountID,
  address signer // Signature[] memory signatures
) {
  checkAndUpdateTimestampAndTxID(state, timestamp, txID);
  // TODO verify signature
  Account storage account = getAccountByID(state, accountID);
  removeAddress(account.guardians, signer);
}

function RecoverAccountAdmin(
  State storage state,
  uint64 timestamp,
  uint64 txID,
  uint32 accountID,
  AccountRecoveryType recoveryType,
  address oldAdmin,
  address recoveryAdmin // Signature[] memory signatures
) {
  checkAndUpdateTimestampAndTxID(state, timestamp, txID);
  // Account storage account = getAccountByID(state, accountID);
  // TODO verify signature
}
