// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Account, State, SubAccount} from '../DataStructure.sol';

function checkAndUpdateTimestampAndTxID(
  State storage state,
  uint64 newTimestamp,
  uint64 newTxID
) {
  require(newTimestamp > state.lastTxTime, 'timestamp must be increasing');
  require(
    newTxID == state.lastTxID + 1,
    'transactionID must be increasing by 1'
  );
  state.lastTxTime = newTimestamp;
  state.lastTxID = newTxID;
}

function getAccountByID(
  State storage state,
  uint32 accountID
) view returns (Account storage) {
  Account storage account = state.accounts[accountID];
  require(account.id > 0, 'account does not exist');
  return account;
}

function getAccountAndSubAccountByID(
  State storage state,
  uint32 accountID,
  address subAccountID
) view returns (Account storage, SubAccount storage) {
  return (state.accounts[accountID], state.subAccounts[subAccountID]);
}
