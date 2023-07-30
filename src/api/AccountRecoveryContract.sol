// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Account, State, AccountRecoveryType, Signature} from '../DataStructure.sol';
import {addressExists, removeAddress} from '../util/Address.sol';
import {checkAndUpdateTimestampAndTxID, getAccountByID} from '../util/Util.sol';

abstract contract AccountRecoveryContract {
  function _getState() internal virtual returns (State storage);

  function addAccountGuardian(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer // Signature[] calldata signatures
  ) public {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage account = getAccountByID(state, accountID);
    if (addressExists(account.guardians, signer)) {
      // No op if the guardian already exists
      return;
    }

    // TODO verify signature
    account.guardians.push(signer);
  }

  function removeAccountGuardian(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer // Signature[] calldata signatures
  ) public {
    State storage state = _getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    // TODO verify signature
    Account storage account = getAccountByID(state, accountID);
    removeAddress(account.guardians, signer, false);
  }

  // function recoverAccountAdmin(
  //   State storage state,
  //   uint64 timestamp,
  //   uint64 txID,
  //   uint32 accountID,
  //   AccountRecoveryType recoveryType,
  //   address oldAdmin,
  //   address recoveryAdmin,
  //   Signature[] calldata signatures
  // ) {
  //   checkAndUpdateTimestampAndTxID(state, timestamp, txID);
  //   // Account storage account = getAccountByID(state, accountID);
  //   // TODO verify signature
  // }
}
