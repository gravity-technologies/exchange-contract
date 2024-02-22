// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./signature/generated/WalletRecoverySig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";

contract WalletRecoveryContract is BaseContract {
  /// @notice Add a recovery address for a signer for a given signer for a given account
  /// The recoveryAddress can be used to change the signer from the signer to another signer from the account and subAccounts associated with the account
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accID The account ID
  /// @param recoveryAddress The recovery address that can be used to change the signer
  /// @param sig The signature of the signer for which the recovery address is being added
  function addRecoveryAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address recoveryAddress,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    _requireSignerInAccount(acc, sig.signer);
    _preventReplay(hashAddRecoveryAddress(accID, recoveryAddress, sig.nonce), sig);
    // ------- End of Signature Verification -------

    acc.recoveryAddresses[sig.signer][recoveryAddress] = 1;
  }

  /// @notice Remove a recovery address for a signer for a given signer for a given account
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accID The account ID
  /// @param recoveryAddress The recovery address that is being removed
  /// @param sig The signature of the signer whose recovery address is being removed
  function removeRecoveryAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address recoveryAddress,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    _requireSignerInAccount(acc, sig.signer);
    _preventReplay(hashRemoveRecoveryAddress(accID, recoveryAddress, sig.nonce), sig);
    // ------- End of Signature Verification -------

    delete acc.recoveryAddresses[sig.signer][recoveryAddress];
  }

  /// @notice Recover the address of an account
  /// Replaces the oldSigner with the newSigner with the newSigner having the same permissions
  /// as the oldSigner in the account and all the subAccounts associated with the account.
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accID The account ID
  /// @param oldSigner  existing signer that can have permissions in the account but needs to be replaced
  /// @param newSigner new signer that will replace the oldSigner
  /// @param recoverySignerSig The signature of the recoverySigner
  function recoverAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address oldSigner,
    address newSigner,
    Signature calldata recoverySignerSig
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);
    require(acc.signers[newSigner] == 0, "new signer already exists");

    // ---------- Signature Verification -----------
    // The recoverySigner must be a signer of the account or a recovery signer for the oldSigner
    require(
      ((acc.signers[oldSigner] != 0 && recoverySignerSig.signer == oldSigner)) ||
        acc.recoveryAddresses[oldSigner][recoverySignerSig.signer] == 1,
      "invalid signer"
    );
    _preventReplay(hashRecoverAddress(accID, oldSigner, newSigner, recoverySignerSig.nonce), recoverySignerSig);
    // ------- End of Signature Verification -------
    // Add a new signer with the same permission as the old signer to the account
    acc.signers[newSigner] = acc.signers[oldSigner];
    delete acc.signers[oldSigner];
    uint256 numSubAccs = acc.subAccounts.length;
    for (uint256 i; i < numSubAccs; ++i) {
      SubAccount storage subAcc = _requireSubAccount(acc.subAccounts[i]);
      require(subAcc.signers[newSigner] == 0, "new signer already exists");
      // Add a new signer with the same permission as the old signer to the subAccount
      subAcc.signers[newSigner] = subAcc.signers[oldSigner];
      delete subAcc.signers[oldSigner];
    }
  }
}
