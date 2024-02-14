// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./signature/generated/WalletRecoverySig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";

contract WalletRecoveryContract is BaseContract {
  // addRecoveryAddress adds a recoveryAddress for a given signer for a given account
  // The recoveryAddress can be used to change the signer from the signer to another signer from the account and subAccounts associated with the account
  function addRecoveryAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address signer,
    address recoveryAddress,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    // TODO: Add this check within _preventReplay
    require(sig.signer == signer, "invalid signer");
    _preventReplay(hashAddRecoveryAddress(accID, signer, recoveryAddress, nonce), sig);
    // ------- End of Signature Verification -------

    acc.recoveryAddresses[signer][recoveryAddress] = 1;
  }

  // removeRecoveryAddress removes a recoveryAddress for a given signer for a given account
  function removeRecoveryAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address signer,
    address recoveryAddress,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    // TODO: Add this check within _preventReplay
    require(sig.signer == signer, "invalid signer");
    _preventReplay(hashRemoveRecoveryAddress(accID, signer, recoveryAddress, nonce), sig);
    // ------- End of Signature Verification -------

    delete acc.recoveryAddresses[signer][recoveryAddress];
  }

  // recoverAddress replaces the oldSigner with the newSigner with the newSigner having the same permissions
  // as the oldSigner in the account and all the subAccounts associated with the account.
  // oldSigner is the existing signer that can have permissions in the account but needs to be replaced
  // newSigner is the new signer that will replace the oldSigner
  // recoverySigner is the signer that has to supply the signature to enable the recovery
  function recoverAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address oldSigner,
    address recoverySigner,
    address newSigner,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);
    require(acc.signers[newSigner] == 0, "new signer already exists");

    // ---------- Signature Verification -----------
    // TODO: Add this check within _preventReplay
    require(sig.signer == recoverySigner, "invalid signer");
    _preventReplay(hashRecoverAddress(accID, oldSigner, recoverySigner, newSigner, nonce), sig);
    // ------- End of Signature Verification -------

    require(acc.recoveryAddresses[oldSigner][recoverySigner] == 1, "invalid recovery signer");
    // Add a new signer with the same permission as the old signer to the account
    acc.signers[newSigner] = acc.signers[oldSigner];
    delete acc.signers[oldSigner];
    uint256 numSubAccs = acc.subAccounts.length;
    for (uint256 i = 0; i < numSubAccs; i++) {
      SubAccount storage subAcc = _requireSubAccount(acc.subAccounts[i]);
      require(subAcc.signers[newSigner] == 0, "new signer already exists");
      // Add a new signer with the same permission as the old signer to the subAccount
      subAcc.signers[newSigner] = subAcc.signers[oldSigner];
      delete subAcc.signers[oldSigner];
    }
  }
}
