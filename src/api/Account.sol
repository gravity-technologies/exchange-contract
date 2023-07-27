// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Signer, SubAccount, Account, State, Signature} from '../DataStructure.sol';
import {addAddress, removeAddress} from '../util/Address.sol';
import {checkAndUpdateTimestampAndTxID, getAccountByID} from '../util/Util.sol';

abstract contract AccountAPI {
  function getState() internal virtual returns (State storage);

  function SetAccountMultiSigThreshold(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    uint8 multiSigThreshold,
    Signature[] calldata signatures
  ) public {
    State storage state = getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);
    requireSignatureQuorum(acc.multiSigThreshold, signatures.length);
    require(
      multiSigThreshold > 0 && multiSigThreshold <= acc.admins.length,
      'multiSigThreshold is invalid'
    );

    // TODO: signature verification
    acc.multiSigThreshold = multiSigThreshold;
  }

  function AddAccountAdmin(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer,
    Signature[] calldata signatures
  ) public {
    State storage state = getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);
    requireSignatureQuorum(acc.multiSigThreshold, signatures.length);

    // TODO verify signature
    addAddress(acc.admins, signer);
  }

  function RemoveAccountAdmin(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer,
    Signature[] calldata signatures
  ) public {
    State storage state = getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);
    requireSignatureQuorum(acc.multiSigThreshold, signatures.length);
    // TODO Solidity function implementation
    // TODO: verify multisig threshold reached
    // TODO: prevent replay attack
    removeAddress(acc.admins, signer);
  }

  function AddWithdrawalAddress(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address withdrawalAddress,
    Signature[] calldata signatures
  ) public {
    State storage state = getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    // TODO verify signature
    Account storage acc = getAccountByID(state, accountID);
    requireSignatureQuorum(acc.multiSigThreshold, signatures.length);
    addAddress(acc.onboardedWithdrawalAddresses, withdrawalAddress);
  }

  function RemoveWithdrawalAddress(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address withdrawalAddress,
    Signature[] calldata signatures
  ) public {
    State storage state = getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);
    requireSignatureQuorum(acc.multiSigThreshold, signatures.length);
    // TODO verify signature
    removeAddress(acc.onboardedWithdrawalAddresses, withdrawalAddress);
  }

  function AddTransferSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address transferSubAccount,
    Signature[] calldata signatures
  ) public {
    State storage state = getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);
    Account storage acc = getAccountByID(state, accountID);
    requireSignatureQuorum(acc.multiSigThreshold, signatures.length);
    // TODO verify signature
    addAddress(acc.onboardedTransferSubAccounts, transferSubAccount);
  }

  function RemoveTransferSubAccount(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address transferSubAccount,
    Signature[] calldata signatures
  ) public {
    State storage state = getState();
    checkAndUpdateTimestampAndTxID(state, timestamp, txID);

    // TODO verify signature
    Account storage acc = getAccountByID(state, accountID);
    requireSignatureQuorum(acc.multiSigThreshold, signatures.length);
    removeAddress(acc.onboardedTransferSubAccounts, transferSubAccount);
  }
}

function requireSignatureQuorum(uint256 quorum, uint256 numSignatures) pure {
  require(numSignatures >= quorum, 'insufficient signatures');
}
