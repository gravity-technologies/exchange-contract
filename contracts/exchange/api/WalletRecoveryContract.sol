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
    address recoveryAddress,
    uint32 nonce,
    Signature calldata sig
  ) external {
    // Check that
    // - all signatures belong to admins
    // - quorum
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    _preventReplay(hashAddRecoveryAddress(accID, signer, recoveryAddress, nonce), sig);
    // ------- End of Signature Verification -------

    acc.recoveryAddresses[signer][recoveryAddress] = 1;
  }

  function removeRecoveryAddress(
    int64 timestamp,
    uint64 txID,
    address accID,
    address signer,
    address recoveryAddress,
    uint32 nonce,
    Signature calldata sig
  ) external {
    // Check that
    // - all signatures belong to admins
    // - quorum
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    _preventReplay(hashRemoveRecoveryAddress(accID, signer, recoveryAddress, nonce), sig);
    // ------- End of Signature Verification -------

    delete acc.recoveryAddresses[signer][recoveryAddress];
  }

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

    // ---------- Signature Verification -----------
    _preventReplay(hashRecoverAddress(accID, oldSigner, recoverySigner, newSigner, nonce), sig);
    // ------- End of Signature Verification -------

    require(acc.recoveryAddresses[oldSigner][recoverySigner] == 1, "invalid recovery signer");
    acc.signers[newSigner] = acc.signers[oldSigner];
    delete acc.signers[oldSigner];
    for (uint256 i = 0; i < acc.subAccounts.length; i++) {
      SubAccount storage subAcc = _requireSubAccount(acc.subAccounts[i]);
      subAcc.signers[newSigner] = subAcc.signers[oldSigner];
      delete subAcc.signers[oldSigner];
    }
  }
}
