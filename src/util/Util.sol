// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Account, State, SubAccount} from "../DataStructure.sol";

function checkAndUpdateTimestampAndTxID(State storage state, uint64 newTimestamp, uint64 newTxID) {
  require(newTimestamp > state.timestamp, "invalid timestamp");
  require(newTxID == state.lastTxID + 1, "invalid transactionID");
  state.timestamp = newTimestamp;
  state.lastTxID = newTxID;
}

function getAccountByID(State storage state, uint32 accountID) view returns (Account storage) {
  Account storage account = state.accounts[accountID];
  require(account.id > 0, "account does not exist");
  return account;
}

function getSubAccountByID(State storage state, address subAccountID) view returns (SubAccount storage) {
  SubAccount storage sub = state.subAccounts[subAccountID];
  require(sub.id != address(0), "subaccount does not exist");
  return sub;
}

function getAccountAndSubAccountByID(
  State storage state,
  uint32 accountID,
  address subAccountID
) view returns (Account storage, SubAccount storage) {
  return (state.accounts[accountID], state.subAccounts[subAccountID]);
}
