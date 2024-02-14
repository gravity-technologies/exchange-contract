// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./signature/generated/WalletRecoverySig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";

contract WalletRecoveryContract is BaseContract {
  function addRecoveryAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address signer,
    address recoveryWallet,
    uint32 nonce,
    Signature calldata sig
  ) external {
    // Check that
    // - all signatures belong to admins
    // - quorum
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddRecoveryWallet(accID, signer, recoveryWallet, nonce);
    // ------- End of Signature Verification -------

    acc.recoveryAddresses[signer][recoveryWallet] = 1;
  }

  function removeRecoveryAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address signer,
    address recoveryWallet,
    uint32 nonce,
    Signature calldata sig
  ) external {
    // Check that
    // - all signatures belong to admins
    // - quorum
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveRecoveryWallet(accID, signer, recoveryWallet, nonce);
    // ------- End of Signature Verification -------

    acc.recoveryAddresses[signer][recoveryWallet] = 0;
  }

  function recoverWallet(
    int64 timestamp,
    uint64 txID,
    address accID,
    address oldSigner,
    address recoverySigner,
    address newSigner,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    // Check that
    // - all signatures belong to admins
    // - quorum
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRecoverWallet(accID, oldSigner, recoverySigner, newSigner, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    require(acc.recoveryAddresses[oldSigner][recovery] == 1, "invalid recovery signer");
    acc.signers[newSigner] = 1;
    delete acc.signers[oldSigner];
    for (uint256 i = 0; i < acc.subAccounts.length; i++) {
      acc.subAccounts[i].signers[newSigner] = 1;
      delete acc.subAccounts[i].signers[oldSigner];
    }
  }
}
