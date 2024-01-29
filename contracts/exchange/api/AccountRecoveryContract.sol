// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./signature/generated/AccountRecoverySig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";

contract AccountRecoveryContract is BaseContract {
  function addAccountGuardian(
    int64 timestamp,
    uint64 txID,
    address accID,
    address signer,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    // Check that
    // - all signatures belong to admins
    // - quorum
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddGuardian(accID, signer, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    addAddress(acc.guardians, signer);
  }

  function removeAccountGuardian(
    int64 timestamp,
    uint64 txID,
    address accID,
    address signer,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveGuardian(accID, signer, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
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
    int64 timestamp,
    uint64 txID,
    address accID,
    AccountRecoveryType recoveryType,
    address oldAdmin,
    address newAdmin,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    require(signerHasPerm(acc.signers, oldAdmin, AccountPermAdmin), "admin does not exist");
    require(!signerHasPerm(acc.signers, newAdmin, AccountPermAdmin), "admin already exists");

    bytes32 hash = hashRecoverAdmin(accID, recoveryType, oldAdmin, newAdmin, nonce);
    // address[] memory voters = recoveryType == AccountRecoveryType.GUARDIAN ? acc.guardians : _getSigners(acc);
    // _requireSignatureQuorum(voters, 1 + voters.length / 2, hash, sigs);

    // Add recovery admin after all checks have passed
    acc.signers[newAdmin] = AccountPermAdmin;
    // remove old account admin
    acc.signers[oldAdmin] = 0;
  }

  // Return all signers in an account without duplicates
  // function _getSigners(Account storage acc) internal view returns (address[] memory) {
  //   uint64[] storage accSubs = acc.subAccounts;
  //   mapping(uint64 => SubAccount) storage allSubs = state.subAccounts;

  //   // If all signers are unique, the cardinality is maxSigners
  //   // Otherwise, the number of unique signers will be < maxSigners
  //   // Here we allocate the array to store the maximum number of votes possible
  //   uint maxSigners = 0;
  //   for (uint i = 0; i < accSubs.length; i++) {
  //     maxSigners += allSubs[accSubs[i]].authorisedSigners.length;
  //   }

  //   // Combine all signers of each subaccount into 1 array, guaranteeing that there are no duplicates.
  //   // The first two loops are for iterating through each signer of each subaccount.
  //   // The last for loop is to ensuring that we did not see this address before
  //   // Each insertion is O(num_signers)
  //   uint numUniqs = 0;
  //   address[] memory uniqs = new address[](maxSigners);
  //   uint numSubs = accSubs.length;
  //   for (uint i = 0; i < numSubs; i++) {
  //     Signer[] storage signers = allSubs[accSubs[i]].authorisedSigners;
  //     uint numSigners = signers.length;
  //     for (uint j = 0; j < numSigners; j++) {
  //       address subSigner = signers[j].signingKey;
  //       bool exists = false;
  //       for (uint k = 0; k < numUniqs; k++) {
  //         if (uniqs[k] == subSigner) {
  //           exists = true;
  //           break;
  //         }
  //       }
  //       if (!exists) uniqs[numUniqs++] = subSigner;
  //     }
  //   }
  //   return uniqs;
  // }
}
