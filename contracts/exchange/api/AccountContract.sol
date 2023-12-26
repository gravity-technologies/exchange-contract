// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./HelperContract.sol";
import "./signature/generated/AccountSig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";

contract AccountContract is HelperContract {
  function createAccount(int64 timestamp, uint64 txID, address accountID, Signature calldata sig) external {
    _setSequence(timestamp, txID);
    Account storage acc = state.accounts[accountID];
    require(acc.id == address(0), "account already exists");

    // ---------- Signature Verification -----------
    bytes32 hash = hashCreateAccount(accountID, sig.nonce);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    // Create account
    acc.id = accountID;
    acc.multiSigThreshold = 1;
    acc.adminCount = 1;
    acc.signerCount = 1;
    acc.signers[sig.signer] = AccountPermAdmin;
  }

  function setAccountMultiSigThreshold(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint8 multiSigThreshold,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);
    require(acc.id != address(0), "account does not exist");
    require(multiSigThreshold > 0 && multiSigThreshold <= acc.adminCount, "invalid threshold");

    // ---------- Signature Verification -----------
    bytes32 hash = hashSetMultiSigThreshold(accountID, multiSigThreshold, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    acc.multiSigThreshold = multiSigThreshold;
  }

  function addAccountSigner(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address signer,
    uint64 permissions,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);
    require(acc.id != address(0), "account does not exist");

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddAccountSigner(accountID, signer, permissions, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    uint64 curPerm = acc.signers[signer];
    if (curPerm & AccountPermAdmin == 0 && permissions & AccountPermAdmin != 0) {
      acc.adminCount++;
    }
    acc.signers[signer] = permissions;
  }

  function removeAccountSigner(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address signer,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveAccountSigner(accountID, signer, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    uint64 curPerm = acc.signers[signer];
    bool isAdmin = curPerm & AccountPermAdmin != 0;
    if (isAdmin) {
      require(acc.adminCount > 1, "require 1 admin");
      acc.adminCount--;
    }
    acc.signers[signer] = 0;
  }

  function addWithdrawalAddress(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address withdrawalAddress,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddWithdrawalAddress(accountID, withdrawalAddress, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    acc.onboardedWithdrawalAddresses[withdrawalAddress] = true;
  }

  function removeWithdrawalAddress(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address withdrawalAddress,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveWithdrawalAddress(accountID, withdrawalAddress, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    acc.onboardedWithdrawalAddresses[withdrawalAddress] = false;
  }

  function addTransferAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddTransferAccount(accountID, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End hashAddTransferAccount -------

    acc.onboardedTransferAccounts[accountID] = true;
  }

  function removeTransferAccount(
    int64 timestamp,
    uint64 txID,
    address accID,
    uint32 nonce,
    Signature[] calldata sigs
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashRemoveTransferAccount(accID, nonce);
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hash, sigs);
    // ------- End of Signature Verification -------

    acc.onboardedTransferAccounts[accID] = false;
  }
}
