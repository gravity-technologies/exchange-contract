// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./HelperContract.sol";
import "./signature/generated/SubAccountSig.sol";
import "../DataStructure.sol";
import "../util/Address.sol";

contract SubAccountContract is HelperContract {
  uint private constant _MAX_SESSION_DURATION_NANO = 1 days;

  /// @notice Change the margin type of a subaccount
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param subAccID The subaccount ID
  /// @param marginType The new margin type
  /// @param nonce The nonce of the transaction
  /// @param sig The signature of the acting user
  function setSubAccountMarginType(
    uint64 timestamp,
    uint64 txID,
    address subAccID,
    MarginType marginType,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subAccID);
    Account storage acc = _requireAccount(sub.accountID);

    require(marginType != MarginType.UNSPECIFIED, "invalid margin");
    // To change margin type requires that there's no OPEN position
    // See Binance: https://www.binance.com/en/support/faq/how-to-switch-between-cross-margin-mode-and-isolated-margin-mode-360038075852#:~:text=You%20are%20not%20allowed%20to%20change%20the%20margin%20mode%20if%20you%20have%20any%20open%20orders%20or%20positions%3B
    // TODO: revise this to if subaccount is liquidatable under new margin model. If it is not, we allow it through.
    require(sub.derivativePositions.length == 0, "open positions exist");
    _requirePermission(acc, sub, sig.signer, SubAccountPermChangeMarginType);

    // ---------- Signature Verification -----------
    _preventHashReplay(hashSetMarginType(subAccID, marginType, nonce), sig);
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
  /// @param nonce The nonce of the transaction
  /// @param sig The signature of the acting user
  function addSubAccountSigner(
    uint64 timestamp,
    uint64 txID,
    address subID,
    address signer,
    uint16 permissions,
    uint32 nonce,
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
    _requireUpsertSigner(acc, sub, sig.signer, permissions, SubAccountPermAddSigner);

    // ---------- Signature Verification -----------
    _preventHashReplay(hashAddSigner(subID, signer, permissions, nonce), sig);
    // ------- End of Signature Verification -------

    Signer[] storage signers = sub.authorizedSigners;
    (, bool found) = _findSigner(signers, signer);
    require(!found, "signer already exists");
    signers.push(Signer(signer, permissions));
  }

  /// @notice Change the permissions of a subaccount signer
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param subID The subaccount ID
  /// @param signer The signer to change permissions for
  /// @param perms The new permissions of the signer as a bitmask
  /// @param nonce The nonce of the transaction
  /// @param sig The signature of the acting user
  function setSubAccountSignerPermissions(
    uint64 timestamp,
    uint64 txID,
    address subID,
    address signer,
    uint64 perms,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subID);
    Account storage acc = _requireAccount(sub.accountID);
    _requireUpsertSigner(acc, sub, sig.signer, perms, SubAccountPermUpdateSignerPermission);

    // ---------- Signature Verification -----------
    bytes32 hash = hashSetSignerPermissions(subID, signer, perms, nonce);
    _preventHashReplay(hash, sig);
    // ------- End of Signature Verification -------

    // Update permission
    Signer[] storage signers = sub.authorizedSigners;
    (uint idx, bool found) = _findSigner(signers, signer);
    require(found, "signer not found");
    signers[idx] = Signer(signer, perms);
  }

  /// @notice Remove a signer from a subaccount
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param subAccID The subaccount ID
  /// @param signer The signer to remove
  /// @param nonce The nonce of transaction
  /// @param sig The signature of the acting user
  function removeSubAccountSigner(
    uint64 timestamp,
    uint64 txID,
    address subAccID,
    address signer,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subAccID);
    Account storage acc = _requireAccount(sub.accountID);

    _requirePermission(acc, sub, sig.signer, SubAccountPermRemoveSigner);

    // ---------- Signature Verification -----------
    _preventHashReplay(hashRemoveSigner(subAccID, signer, nonce), sig);
    // ------- End of Signature Verification -------

    // If we reach here, that means the user calling this API is an admin. Hence, even after we remove the last
    // subaccount signer, the subaccount is still accessible by the account admins. Thus we skip the logic to
    // require at least 1 admin
    Signer[] storage signers = sub.authorizedSigners;
    (uint idx, bool found) = _findSigner(signers, signer);
    require(found, "signer not found");
    signers[idx] = signers[signers.length - 1];
    signers.pop();
  }

  // Check if the caller has certain permissions on a subaccount
  function _requirePermission(
    Account storage acc,
    SubAccount storage sub,
    address signer,
    uint64 requiredPerm
  ) private view {
    if (addressExists(acc.admins, signer)) return;
    uint64 signerAuthz = _getPermSet(sub, signer);
    require(signerAuthz & (SubAccountPermAdmin | requiredPerm) > 0, "no permission");
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
    if (addressExists(acc.admins, actor)) return;
    // Actor is Sub Account Admin. ALLOW
    uint64 actorAuthz = _getPermSet(sub, actor);
    if (actorAuthz & SubAccountPermAdmin > 0) return;
    // Actor must have the ability to call the function
    require(actorAuthz & requiredPerm > 0, "actor cannot call function");
    // Actor can only grant permissions that actor has
    require(actorAuthz & grantedAuthz == grantedAuthz, "actor cannot grant permission");
  }

  // Return the permission set of the signerAddress in the subAccount
  // If signerAddress not found in subaccount, return 0: no permission
  function _getPermSet(SubAccount storage subAccount, address signerAddress) private view returns (uint64) {
    uint length = subAccount.authorizedSigners.length;
    Signer[] storage signers = subAccount.authorizedSigners;
    for (uint256 i = 0; i < length; i++) {
      Signer storage signer = signers[i];
      if (signer.signingKey == signerAddress) return signer.permission;
    }
    return 0;
  }

  function _findSigner(Signer[] storage signers, address signerAddress) private view returns (uint, bool) {
    uint length = signers.length;
    for (uint i = 0; i < length; i++) {
      if (signers[i].signingKey == signerAddress) return (i, true);
    }
    return (0, false);
  }

  /// @notice Add a session key to for a signer. This session key will be
  /// allowed to sign trade transactions for a period of time
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID of the transaction
  /// @param sessionKey The session key to be added
  /// @param keyExpiry The unix timestamp in nanosecond after which this session expires
  function addSessionKey(
    uint64 timestamp,
    uint64 txID,
    address sessionKey,
    uint64 keyExpiry,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    require(keyExpiry > timestamp, "invalid expiry");
    // Cap the expiry to timestamp + maxSessionDurationInSec
    uint64 cappedExpiry = _min(keyExpiry, timestamp + uint64(_MAX_SESSION_DURATION_NANO));

    // ---------- Signature Verification -----------
    _preventHashReplay(hashAddSessionKey(sessionKey, keyExpiry), sig);
    // ------- End of Signature Verification -------

    // Overwrite any existing session key
    state.sessionKeys[sig.signer] = SessionKey(sessionKey, cappedExpiry);
  }

  /// @notice Removing signature verification only makes session keys safer.
  /// Operators can remove session keys upon user inactivity to keep users safe on their behalf.
  /// This only ever removes the privilege of a temporary key, and never breaks self-custody of assets.
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID of the transaction
  /// @param signer The address of the signer
  function removeSessionKey(uint64 timestamp, uint64 txID, address signer) external {
    _setSequence(timestamp, txID);
    delete state.sessionKeys[signer];
  }

  function _min(uint64 a, uint64 b) private pure returns (uint64) {
    return a <= b ? a : b;
  }
}
