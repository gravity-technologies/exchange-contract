// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {HelperContract} from "./HelperContract.sol";
import {requireValidSig} from "./signature/Common.sol";
import {hashAddGuardian, hashRemoveGuardian, hashRecoverAdmin} from "./signature/generated/AccountRecoverySig.sol";
import {Account, AccountRecoveryType, Signature, Signer, State, SubAccount} from "../DataStructure.sol";
import {addAddress, addressExists, removeAddress} from "../util/Address.sol";

abstract contract AccountRecoveryContract is HelperContract {
  function _getState() internal virtual returns (State storage);

  function addAccountGuardian(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer,
    uint32 nonce,
    Signature[] calldata signatures
  ) external {
    // Check that
    // - all signatures belong to admins
    // - quorum
    State storage state = _getState();
    _setTimestampAndTxID(state, timestamp, txID);
    Account storage acc = _requireAccount(state, accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddGuardian(accountID, signer, nonce);
    _requireSignatureQuorum(state, acc.admins, acc.multiSigThreshold, hash, signatures);
    // ------- End of Signature Verification -------

    addAddress(acc.guardians, signer);
  }

  function removeAccountGuardian(
    uint64 timestamp,
    uint64 txID,
    uint32 accountID,
    address signer,
    uint32 nonce,
    Signature[] calldata signatures
  ) external {
    State storage state = _getState();
    _setTimestampAndTxID(state, timestamp, txID);
    Account storage acc = _requireAccount(state, accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveGuardian(accountID, signer, nonce);
    _requireSignatureQuorum(state, acc.admins, acc.multiSigThreshold, hash, signatures);
    // ------- End of Signature Verification -------

    removeAddress(acc.guardians, signer, false);
  }

  // In this function, we need to aggregate all guardians and subaccount
  // signers, and verify that the signatures are from them. The reason
  // that we have to use an ugly looking set implementation (tbh its an
  // array with O(n) insertion) is:
  // - Solidity doesn't provide push and pop for in memory array
  // - To store these entries in the storage mapping would be very
  //   expensive (as it costs 200k gas per write)
  // - Thus, we opted for using an O(n^2) algo to create the set of voters
  //   (guardians and subaccount signers) and verify that the signatures
  //   are from them
  function recoverAccountAdmin(
    uint64 timestamp,
    uint64 txID,
    uint32 accID,
    AccountRecoveryType recoveryType,
    address oldAdmin,
    address recoveryAdmin,
    uint32 nonce,
    Signature[] calldata signatures
  ) external {
    State storage state = _getState();
    _setTimestampAndTxID(state, timestamp, txID);
    Account storage acc = _requireAccount(state, accID);

    require(addressExists(acc.admins, oldAdmin), "admin does not exist");
    require(!addressExists(acc.admins, recoveryAdmin), "admin already exists");

    bytes32 hash = hashRecoverAdmin(accID, recoveryType, oldAdmin, recoveryAdmin, nonce);
    address[] memory voters = recoveryType == AccountRecoveryType.GUARDIAN ? acc.guardians : _getSigners(state, acc);
    _requireSignatureQuorum(state, voters, 1 + voters.length / 2, hash, signatures);

    // Add recovery admin after all checks have passed
    addAddress(acc.admins, recoveryAdmin);
    // remove old account admin
    removeAddress(acc.admins, oldAdmin, false);
  }

  // Return all signers in an account without duplicates
  function _getSigners(State storage state, Account storage acc) internal view returns (address[] memory) {
    address[] storage accSubs = acc.subAccounts;
    mapping(address => SubAccount) storage allSubs = state.subAccounts;

    // If all signers are unique, the cardinality is maxSigners
    // Otherwise, the number of unique signers will be < maxSigners
    // Here we allocate the array to store the maximum number of votes possible
    uint maxSigners = 0;
    for (uint i = 0; i < accSubs.length; i++) {
      maxSigners += allSubs[accSubs[i]].authorizedSigners.length;
    }

    // Combine all signers of each subaccount into 1 array, guaranteeing that there are no duplicates.
    // The first two loops are for iterating through each signer of each subaccount.
    // The last for loop is to ensuring that we did not see this address before
    // Each insertion is O(num_signers)
    uint numUniqs = 0;
    address[] memory uniqs = new address[](maxSigners);
    uint numSubs = accSubs.length;
    for (uint i = 0; i < numSubs; i++) {
      Signer[] storage signers = allSubs[accSubs[i]].authorizedSigners;
      uint numSigners = signers.length;
      for (uint j = 0; j < numSigners; j++) {
        address subSigner = signers[j].signingKey;
        bool exists = false;
        for (uint k = 0; k < numUniqs; k++) {
          if (uniqs[k] == subSigner) {
            exists = true;
            break;
          }
        }
        if (!exists) uniqs[numUniqs++] = subSigner;
      }
    }
    return uniqs;
  }
}
