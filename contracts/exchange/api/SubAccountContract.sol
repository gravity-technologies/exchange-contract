// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./signature/generated/SubAccountSig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";

contract SubAccountContract is BaseContract {
  int64 private constant _MAX_SESSION_DURATION_NANO = 24 * 60 * 60 * 1e9; // 24 hours

  /// @notice Create a subaccount
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param accountID The account ID
  /// @param subAccountID The subaccount ID
  /// @param quoteCurrency The quote currency of the subaccount
  /// @param marginType The margin type of the subaccount
  /// @param sig The signature of the acting user
  function createSubAccount(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint64 subAccountID,
    Currency quoteCurrency,
    MarginType marginType,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    Account storage acc = state.accounts[accountID];
    require(quoteCurrency != Currency.UNSPECIFIED, "invalid quote currency");
    require(marginType != MarginType.UNSPECIFIED, "invalid margin type");
    require(acc.id != address(0), "account does not exist");
    require(subAccountID != 0, "invalid subaccount id");
    SubAccount storage sub = state.subAccounts[subAccountID];
    require(sub.accountID == address(0), "subaccount already exists");

    // requires that the user is an account admin
    require(acc.signers[sig.signer] & AccountPermAdmin > 0, "not account admin");

    // ---------- Signature Verification -----------
    bytes32 hash = hashCreateSubAccount(accountID, subAccountID, quoteCurrency, marginType, sig.nonce);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

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

  /// @notice Change the margin type of a subaccount
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param subAccID The subaccount ID
  /// @param marginType The new margin type
  /// @param sig The signature of the acting user
  function setSubAccountMarginType(
    int64 timestamp,
    uint64 txID,
    uint64 subAccID,
    MarginType marginType,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subAccID);

    require(marginType != MarginType.UNSPECIFIED, "invalid margin");
    // To change margin type requires that there's no OPEN position
    // See Binance: https://www.binance.com/en/support/faq/how-to-switch-between-cross-margin-mode-and-isolated-margin-mode-360038075852#:~:text=You%20are%20not%20allowed%20to%20change%20the%20margin%20mode%20if%20you%20have%20any%20open%20orders%20or%20positions%3B
    // TODO: revise this to if subaccount is liquidatable under new margin model. If it is not, we allow it through.
    require(sub.options.keys.length + sub.futures.keys.length + sub.perps.keys.length == 0, "open positions exist");
    _requireSubAccountPermission(sub, sig.signer, SubAccountPermAdmin);

    // ---------- Signature Verification -----------
    _preventReplay(hashSetMarginType(subAccID, marginType, sig.nonce), sig);
    // ------- End of Signature Verification -------

    sub.marginType = marginType;
  }

  /// @notice Add a signer to a subaccount. This signer will be able to
  /// perform actions like Deposit, Withdrawal, Transfer, Trade etc. on the account, depending on the permissions.
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param subID The subaccount ID
  /// @param signer The signer to add
  /// @param permissions The permissions of the signer as a bitmask
  /// @param sig The signature of the acting user
  function addSubAccountSigner(
    int64 timestamp,
    uint64 txID,
    uint64 subID,
    address signer,
    uint64 permissions,
    Signature calldata sig
  ) external {
    // subaccount, account exist
    // has permission
    // new signer permission is valid, and is a subset of current signer permission
    // signature is valid
    // caller owns the account/subaccount
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subID);
    Account storage acc = _requireAccount(sub.accountID);
    _requireUpsertSigner(acc, sub, sig.signer, permissions, SubAccountPermAdmin);

    // // ---------- Signature Verification -----------
    _preventReplay(hashAddSubAccountSigner(subID, signer, permissions, sig.nonce), sig);
    // ------- End of Signature Verification -------

    sub.signers[signer] = permissions;
  }

  /// @notice Remove a signer from a subaccount
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param subAccID The subaccount ID
  /// @param signer The signer to remove
  /// @param sig The signature of the acting user
  function removeSubAccountSigner(
    int64 timestamp,
    uint64 txID,
    uint64 subAccID,
    address signer,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subAccID);

    _requireSubAccountPermission(sub, sig.signer, SubAccountPermAdmin);

    // ---------- Signature Verification -----------
    _preventReplay(hashRemoveSigner(subAccID, signer, sig.nonce), sig);
    // ------- End of Signature Verification -------

    // If we reach here, that means the user calling this API is an admin. Hence, even after we remove the last
    // subaccount signer, the subaccount is still accessible by the account admins. Thus we skip the logic to
    // require at least 1 admin
    sub.signers[signer] = 0;
  }

  // Used for add and update signer permission. Perform additional check that the new permission is a subset of the caller's permission if the caller is not an admin
  function _requireUpsertSigner(
    Account storage acc,
    SubAccount storage sub,
    address actor,
    uint64 grantedAuthz,
    uint64 requiredPerm
  ) private view {
    // Actor is Account Admin. ALLOW
    if (signerHasPerm(acc.signers, actor, AccountPermAdmin)) return;
    // Actor is Sub Account Admin. ALLOW
    uint64 actorAuthz = sub.signers[actor];
    if (actorAuthz & SubAccountPermAdmin > 0) return;
    // Actor must have the ability to call the function
    require(actorAuthz & requiredPerm > 0, "actor cannot call function");
    // Actor can only grant permissions that actor has
    require(actorAuthz & grantedAuthz == grantedAuthz, "actor cannot grant permission");
  }

  /// @notice Add a session key to for a signer. This session key will be
  /// allowed to sign trade transactions for a period of time
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID of the transaction
  /// @param sessionKey The session key to be added
  /// @param keyExpiry The unix timestamp in nanosecond after which this session expires
  function addSessionKey(
    int64 timestamp,
    uint64 txID,
    address sessionKey,
    int64 keyExpiry,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    require(int64(keyExpiry) > timestamp, "invalid expiry");
    // Cap the expiry to timestamp + maxSessionDurationInSec
    int64 cappedExpiry = _min(keyExpiry, timestamp + _MAX_SESSION_DURATION_NANO);

    // ---------- Signature Verification -----------
    _preventReplay(hashAddSessionKey(sessionKey, keyExpiry), sig);
    // ------- End of Signature Verification -------

    // Overwrite any existing session key
    state.sessions[sessionKey] = Session(sig.signer, cappedExpiry);
  }

  /// @notice Removing signature verification only makes session keys safer.
  /// Operators can remove session keys upon user inactivity to keep users safe on their behalf.
  /// This only ever removes the privilege of a temporary key, and never breaks self-custody of assets.
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID of the transaction
  /// @param signer The address of the signer
  function removeSessionKey(int64 timestamp, uint64 txID, address signer) external {
    _setSequence(timestamp, txID);
    delete state.sessions[signer];
  }

  function _min(int64 a, int64 b) private pure returns (int64) {
    return a <= b ? a : b;
  }
}
