// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Account, Signature, State, SubAccount, Currency, MarginType} from '../DataStructure.sol';
import {checkAndUpdateTimestampAndTxID, getAccountAndSubAccountByID} from '../util/Util.sol';

abstract contract SubAccountAPI {
  function getState() internal virtual returns (State storage);

  function CreateSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address subAccountID,
    Currency quoteCurrency,
    MarginType marginType,
    Signature[] calldata signatures
  ) public {
    State storage state = getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    (Account storage acc, SubAccount storage sub) = getAccountAndSubAccountByID(
      state,
      accountID,
      subAccountID
    );
    require(sub.accountID == 0, 'subaccount already exists');

    // If the account is new, the threshold is 0, but we still need at least 1 signature.
    uint multisigThreshold = max(acc.multiSigThreshold, 1);
    require(signatures.length >= multisigThreshold, 'not enough signatures');

    // TODO: signature verification

    // Create subaccount
    sub.id = subAccountID;
    sub.accountID = accountID;
    sub.marginType = marginType;
    sub.quoteCurrency = quoteCurrency;
    sub.lastAppliedFundingTimestamp = timestamp;
    // We will not create any authorizedSigners in subAccount upon creation. All account admins are presumably authorizedSigners

    // Create a new account if one did not exist
    if (acc.id == 0) {
      acc.id = accountID;
      acc.multiSigThreshold = 1;
      // the first account admins is the signer of the first signature
      acc.admins.push(signatures[0].signer);
      acc.subAccounts.push(subAccountID);
    }
  }
}

function max(uint a, uint b) pure returns (uint) {
  return a >= b ? a : b;
}
