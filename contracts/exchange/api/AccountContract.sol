pragma solidity ^0.8.20;

import "./ConfigContract.sol";
import "./signature/generated/AccountSig.sol";
import "./signature/generated/CombinedAccountSig.sol";
import "../types/DataStructure.sol";

contract AccountContract is ConfigContract {
  /// @notice Create a new account
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The ID the account will be tagged to
  /// @param sig The signature of the acting user
  function createAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    Account storage acc = state.accounts[accountID];
    require(acc.id == address(0), "account already exists");
    require(accountID == sig.signer, "accountID must be signer");

    // ---------- Signature Verification -----------
    bytes32 hash = hashCreateAccount(accountID, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    _deployDepositProxy(accountID);

    // Create account
    acc.id = accountID;
    acc.multiSigThreshold = 1;
    acc.adminCount = 1;
    acc.signers[sig.signer] = AccountPermAdmin;
  }

  /// @notice Set the multiSigThreshold for an account
  /// This requires the multisig threshold to be met
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param multiSigThreshold The multiSigThreshold that is set
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the account signers with admin permissions
  function setAccountMultiSigThreshold(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint8 multiSigThreshold,
    uint32 nonce,
    Signature[] calldata sigs
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);
    require(multiSigThreshold > 0 && multiSigThreshold <= acc.adminCount, "invalid threshold");

    // ---------- Signature Verification -----------
    bytes32[] memory hashes = new bytes32[](sigs.length);
    for (uint256 i = 0; i < sigs.length; i++) {
      hashes[i] = hashSetMultiSigThreshold(accountID, multiSigThreshold, nonce, sigs[i].expiration);
    }
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hashes, sigs);
    // ------- End of Signature Verification -------

    acc.multiSigThreshold = multiSigThreshold;
  }

  /// @notice Add a signer to an account or change the permissions of an existing signer
  /// This requires the multisig threshold to be met
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param signer The new signer
  /// @param permissions The permissions of the new signer
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the account signers with admin permissions
  function addAccountSigner(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address signer,
    uint64 permissions,
    uint32 nonce,
    Signature[] calldata sigs
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32[] memory hashes = new bytes32[](sigs.length);
    for (uint256 i = 0; i < sigs.length; i++) {
      hashes[i] = hashAddAccountSigner(accountID, signer, permissions, nonce, sigs[i].expiration);
    }
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hashes, sigs);
    // ------- End of Signature Verification -------

    uint64 curPerm = acc.signers[signer];
    if (curPerm & AccountPermAdmin == 0 && permissions & AccountPermAdmin != 0) {
      acc.adminCount++;
    }

    if (curPerm & AccountPermAdmin != 0 && permissions & AccountPermAdmin == 0) {
      require(acc.adminCount > 1, "require 1 admin");
      require(acc.multiSigThreshold <= acc.adminCount - 1, "require threshold <= adminCount - 1");
      acc.adminCount--;
    }

    acc.signers[signer] = permissions;
  }

  /// @notice Remove a signer from an account
  /// This requires the multisig threshold to be met
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param signer The signer to be removed
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the account signers with admin permissions
  function removeAccountSigner(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address signer,
    uint32 nonce,
    Signature[] calldata sigs
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32[] memory hashes = new bytes32[](sigs.length);
    for (uint256 i = 0; i < sigs.length; i++) {
      hashes[i] = hashRemoveAccountSigner(accountID, signer, nonce, sigs[i].expiration);
    }
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hashes, sigs);
    // ------- End of Signature Verification -------

    uint64 curPerm = acc.signers[signer];
    bool isAdmin = curPerm & AccountPermAdmin != 0;
    if (isAdmin) {
      require(acc.adminCount > 1, "require 1 admin");
      require(acc.multiSigThreshold <= acc.adminCount - 1, "require threshold <= adminCount - 1");
      acc.adminCount--;
    }
    acc.signers[signer] = 0;
  }

  /// @notice Add withdrawal address that the account can withdraw to
  /// This requires the multisig threshold to be met
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param withdrawalAddress The withdrawal address
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the account signers with admin permissions
  function addWithdrawalAddress(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address withdrawalAddress,
    uint32 nonce,
    Signature[] calldata sigs
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32[] memory hashes = new bytes32[](sigs.length);
    for (uint256 i = 0; i < sigs.length; i++) {
      hashes[i] = hashAddWithdrawalAddress(accountID, withdrawalAddress, nonce, sigs[i].expiration);
    }
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hashes, sigs);
    // ------- End of Signature Verification -------

    acc.onboardedWithdrawalAddresses[withdrawalAddress] = true;
  }

  /// @notice Remove withdrawal address that the account can withdraw to
  /// This requires the multisig threshold to be met
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param withdrawalAddress The withdrawal address
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the account signers with admin permissions
  function removeWithdrawalAddress(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address withdrawalAddress,
    uint32 nonce,
    Signature[] calldata sigs
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32[] memory hashes = new bytes32[](sigs.length);
    for (uint256 i = 0; i < sigs.length; i++) {
      hashes[i] = hashRemoveWithdrawalAddress(accountID, withdrawalAddress, nonce, sigs[i].expiration);
    }
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hashes, sigs);
    // ------- End of Signature Verification -------

    acc.onboardedWithdrawalAddresses[withdrawalAddress] = false;
  }

  /// @notice Add a account that this account can transfer to
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the acting users
  function addTransferAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address transferAccountID,
    uint32 nonce,
    Signature[] calldata sigs
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(transferAccountID != address(0), "invalid transfer account");

    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32[] memory hashes = new bytes32[](sigs.length);
    for (uint256 i = 0; i < sigs.length; i++) {
      hashes[i] = hashAddTransferAccount(accountID, transferAccountID, nonce, sigs[i].expiration);
    }
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hashes, sigs);
    // ------- End hashAddTransferAccount -------

    acc.onboardedTransferAccounts[transferAccountID] = true;
  }

  function removeTransferAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address transferAccountID,
    uint32 nonce,
    Signature[] calldata sigs
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // ---------- Signature Verification -----------
    bytes32[] memory hashes = new bytes32[](sigs.length);
    for (uint256 i = 0; i < sigs.length; i++) {
      hashes[i] = hashRemoveTransferAccount(accountID, transferAccountID, nonce, sigs[i].expiration);
    }
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hashes, sigs);
    // ------- End of Signature Verification -------

    acc.onboardedTransferAccounts[transferAccountID] = false;
  }

  /// @notice Create a new account and subaccount in a single transaction
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The ID the account will be tagged to
  /// @param subAccountID The subaccount ID
  /// @param quoteCurrency The quote currency of the subaccount
  /// @param marginType The margin type of the subaccount
  /// @param sig The signature of the acting user
  function createAccountWithSubAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint64 subAccountID,
    MarginType marginType,
    Currency quoteCurrency,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    // Account creation verification
    Account storage acc = state.accounts[accountID];
    require(acc.id == address(0), "account already exists");
    require(accountID == sig.signer, "accountID must be signer");

    // Subaccount creation verification
    require(currencyCanHoldSpotBalance(quoteCurrency), "invalid quote currency");
    require(marginType == MarginType.SIMPLE_CROSS_MARGIN, "invalid margin type");
    require(subAccountID != 0, "invalid subaccount id");
    SubAccount storage sub = state.subAccounts[subAccountID];
    require(sub.accountID == address(0), "subaccount already exists");
    require(!_isBridgingPartnerAccount(accountID), "no subaccts for bridges");

    // ---------- Signature Verification -----------
    bytes32 hash = hashCreateAccountWithSubAccount(
      accountID,
      subAccountID,
      quoteCurrency,
      marginType,
      sig.nonce,
      sig.expiration
    );
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    // Create account
    _deployDepositProxy(accountID);
    acc.id = accountID;
    acc.multiSigThreshold = 1;
    acc.adminCount = 1;
    acc.signers[sig.signer] = AccountPermAdmin;

    // Create subaccount
    sub.id = subAccountID;
    sub.accountID = accountID;
    sub.marginType = marginType;
    sub.quoteCurrency = quoteCurrency;
    sub.lastAppliedFundingTimestamp = timestamp;
    // We will not create any authorizedSigners in subAccount upon creation.
    // All account admins are presumably authorizedSigners

    acc.subAccounts.push(subAccountID);
  }
}
