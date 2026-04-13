pragma solidity ^0.8.20;

import "./ConfigContract.sol";
import "./signature/generated/AccountSig.sol";
import "./signature/generated/CombinedAccountSig.sol";
import "../types/DataStructure.sol";
import "../interfaces/IAccount.sol";
import "../util/Address.sol";

contract AccountContract is IAccount, ConfigContract {
  uint32 constant _MAX_FUTURE_BUILDER_FEE_RATE_HIGH = 10_00; // 0.1%
  uint32 constant _MAX_SPOT_BUILDER_FEE_RATE_HIGH = 1_00_00; // 1%

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

    _addAccountSigner(acc, signer, permissions);
  }

  /// @dev Adds or updates a signer with the given permissions, handling admin count updates
  function _addAccountSigner(Account storage acc, address signer, uint64 permissions) internal {
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
  /// @param transferAccountID The account ID to transfer to
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
    require(quoteCurrency == Currency.USDT, "invalid quote currency");
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
    sub.subAccountMode = SubAccountMode.SINGLE_ASSET_MODE;
    // We will not create any authorizedSigners in subAccount upon creation.
    // All account admins are presumably authorizedSigners

    acc.subAccounts.push(subAccountID);
  }

  function authorizeBuilder(
    int64 timestamp,
    uint64 txID,
    address mainAccountID,
    address builderAccountID,
    uint32 maxFutureFeeRate,
    uint32 maxSpotFeeRate,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    Account storage mainAccount = _requireAccount(mainAccountID);
    address[] memory signers = new address[](1);
    signers[0] = sig.signer;
    _validateAuthorizeBuilder(mainAccount, mainAccountID, builderAccountID, maxFutureFeeRate, maxSpotFeeRate, signers);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAuthorizeBuilder(
      mainAccountID,
      builderAccountID,
      maxFutureFeeRate,
      maxSpotFeeRate,
      sig.nonce,
      sig.expiration
    );
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    _setBuilderFeeConfig(mainAccount, builderAccountID, maxFutureFeeRate, maxSpotFeeRate);
  }

  /// @dev Validates builder account ID, fee rates, ensures builder account exists, and verifies at least one signer has admin permission
  function _validateAuthorizeBuilder(
    Account storage mainAccount,
    address mainAccountID,
    address builderAccountID,
    uint32 maxFutureFeeRate,
    uint32 maxSpotFeeRate,
    address[] memory signers
  ) internal view {
    if (builderAccountID == mainAccountID) {
      revert InvalidBuilderAccountID();
    }

    if (
      maxFutureFeeRate < 0 ||
      maxFutureFeeRate > _MAX_FUTURE_BUILDER_FEE_RATE_HIGH ||
      maxSpotFeeRate < 0 ||
      maxSpotFeeRate > _MAX_SPOT_BUILDER_FEE_RATE_HIGH
    ) {
      revert InvalidBuilderFeeRate();
    }

    _requireAccount(builderAccountID);

    // Verify that at least one signer has AccountPermAdmin permission
    _requireAtLeastOneSignerHasPermission(mainAccount, signers, AccountPermAdmin);
  }

  /// @dev Sets the builder fee configuration for a builder account
  function _setBuilderFeeConfig(
    Account storage mainAccount,
    address builderAccountID,
    uint32 maxFutureFeeRate,
    uint32 maxSpotFeeRate
  ) internal {
    BuilderFeeConfig storage builderConfig = mainAccount.builders[builderAccountID];
    builderConfig.maxFutureFeeRate = maxFutureFeeRate;
    builderConfig.maxSpotFeeRate = maxSpotFeeRate;
  }

  /// @notice Add a signer to an account and authorize them as a builder in a single transaction
  /// This requires the multisig threshold to be met
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param signer The new signer to add
  /// @param permissions The permissions of the new signer (can be Trade/Admin/any permissions)
  /// @param builderAccountID The builder account ID (should be the same as signer)
  /// @param maxFutureFeeRate The maximum future builder fee rate
  /// @param maxSpotFeeRate The maximum spot builder fee rate
  /// @param nonce The nonce of the transaction
  /// @param sigs The signatures of the account signers with admin permissions
  function addAccountSignerWithBuilder(
    int64 timestamp,
    uint64 txID,
    address accountID,
    address signer,
    uint64 permissions,
    address builderAccountID,
    uint32 maxFutureFeeRate,
    uint32 maxSpotFeeRate,
    uint32 nonce,
    Signature[] calldata sigs
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(accountID);

    // Extract signers from signatures
    address[] memory signers = new address[](sigs.length);
    for (uint256 i = 0; i < sigs.length; i++) {
      signers[i] = sigs[i].signer;
    }
    _validateAuthorizeBuilder(acc, accountID, builderAccountID, maxFutureFeeRate, maxSpotFeeRate, signers);

    // ---------- Signature Verification -----------
    string memory permissionString = _getAccountPermissionsString(permissions);
    bytes32[] memory hashes = new bytes32[](sigs.length);
    for (uint256 i = 0; i < sigs.length; i++) {
      hashes[i] = hashAddAccountSignerWithBuilder(
        accountID,
        signer,
        permissionString,
        builderAccountID,
        maxFutureFeeRate,
        maxSpotFeeRate,
        nonce,
        sigs[i].expiration
      );
    }
    _requireSignatureQuorum(acc.signers, acc.multiSigThreshold, hashes, sigs);
    // ------- End of Signature Verification -------

    // Add signer logic (from addAccountSigner)
    _addAccountSigner(acc, signer, permissions);

    // Authorize builder logic (from authorizeBuilder)
    _setBuilderFeeConfig(acc, builderAccountID, maxFutureFeeRate, maxSpotFeeRate);
  }

  function _getAccountPermissionsString(uint64 permissions) internal pure returns (string memory) {
    bytes memory res = "";
    if (permissions & AccountPermAdmin != 0) {
      res = "Admin";
    }
    if (permissions & AccountPermInternalTransfer != 0) {
      if (bytes(res).length > 0) res = abi.encodePacked(res, "&");
      res = abi.encodePacked(res, "InternalTransfer");
    }
    if (permissions & AccountPermExternalTransfer != 0) {
      if (bytes(res).length > 0) res = abi.encodePacked(res, "&");
      res = abi.encodePacked(res, "ExternalTransfer");
    }
    if (permissions & AccountPermWithdraw != 0) {
      if (bytes(res).length > 0) res = abi.encodePacked(res, "&");
      res = abi.encodePacked(res, "Withdraw");
    }
    if (permissions & AccountPermVaultInvestor != 0) {
      if (bytes(res).length > 0) res = abi.encodePacked(res, "&");
      res = abi.encodePacked(res, "VaultInvestor");
    }
    if (permissions & AccountPermTrade != 0) {
      if (bytes(res).length > 0) res = abi.encodePacked(res, "&");
      res = abi.encodePacked(res, "Trade");
    }
    return string(res);
  }
}
