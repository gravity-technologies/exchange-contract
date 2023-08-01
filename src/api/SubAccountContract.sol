// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {HelperContract} from "./HelperContract.sol";
import {hashSetMarginType, hashAddSigner, hashSetSignerPermissions, hashRemoveSigner} from "./signature/generated/SubAccountSig.sol";
import {requireUniqSig} from "./signature/Common.sol";
import {Account, MarginType, Signature, Signer, State, SubAccount, SubAccountPermAddSigner, SubAccountPermAdmin, SubAccountPermChangeMarginType, SubAccountPermRemoveSignerPermission, SubAccountPermUpdateSigner} from "../DataStructure.sol";
import {addressExists} from "../util/Address.sol";

abstract contract SubAccountContract is HelperContract {
  function _getState() internal virtual returns (State storage);

  function setSubAccountMarginType(
    uint64 timestamp,
    uint64 txID,
    address subAccID,
    MarginType marginType,
    uint32 nonce,
    Signature calldata sig
  ) external {
    State storage state = _getState();
    _setTimestampAndTxID(state, timestamp, txID);
    SubAccount storage sub = _requireSubAccount(state, subAccID);
    Account storage acc = _requireAccount(state, sub.accountID);

    require(marginType != MarginType.UNSPECIFIED, "invalid margin");
    // To change margin type requires that there's no OPEN position
    // See Binance: https://www.binance.com/en/support/faq/how-to-switch-between-cross-margin-mode-and-isolated-margin-mode-360038075852#:~:text=You%20are%20not%20allowed%20to%20change%20the%20margin%20mode%20if%20you%20have%20any%20open%20orders%20or%20positions%3B
    // TODO: revise this to if subaccount is liquidatable under new margin model. If it is not, we allow it through.
    require(sub.derivativePositions.length == 0, "open positions exist");
    _requirePermission(acc, sub, sig.signer, SubAccountPermChangeMarginType);

    // ---------- Signature Verification -----------
    requireUniqSig(state, hashSetMarginType(subAccID, marginType, nonce), sig);
    // ------- End of Signature Verification -------

    // No op if the marginType is the same
    sub.marginType = marginType;
  }

  function addSubAccountSigner(
    uint64 timestamp,
    uint64 txID,
    address subAccID,
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
    State storage state = _getState();
    _setTimestampAndTxID(state, timestamp, txID);
    SubAccount storage sub = _requireSubAccount(state, subAccID);
    Account storage acc = _requireAccount(state, sub.accountID);
    _requireUpsertSigner(acc, sub, sig.signer, permissions, SubAccountPermAddSigner);

    // ---------- Signature Verification -----------
    bytes32 hash = hashAddSigner(subAccID, signer, permissions, nonce);
    requireUniqSig(state, hash, sig);
    // ------- End of Signature Verification -------

    Signer[] storage signers = sub.authorizedSigners;
    (, bool found) = _findSigner(signers, signer);
    require(!found, "signer already exists");
    signers.push(Signer(signer, permissions));
  }

  function setSubAccountSignerPermissions(
    uint64 timestamp,
    uint64 txID,
    address subAccID,
    address signer,
    uint64 permissions,
    uint32 nonce,
    Signature calldata sig
  ) external {
    State storage state = _getState();
    _setTimestampAndTxID(state, timestamp, txID);
    SubAccount storage sub = _requireSubAccount(state, subAccID);
    Account storage acc = _requireAccount(state, sub.accountID);
    _requireUpsertSigner(acc, sub, sig.signer, permissions, SubAccountPermUpdateSigner);

    // ---------- Signature Verification -----------
    bytes32 hash = hashSetSignerPermissions(subAccID, signer, permissions, nonce);
    requireUniqSig(state, hash, sig);
    // ------- End of Signature Verification -------

    // Update permission
    Signer[] storage signers = sub.authorizedSigners;
    (uint idx, bool found) = _findSigner(signers, signer);
    require(found, "signer not found");
    signers[idx] = Signer(signer, permissions);
  }

  function removeSubAccountSigner(
    uint64 timestamp,
    uint64 txID,
    address subAccID,
    address signer,
    uint32 nonce,
    Signature calldata sig
  ) external {
    State storage state = _getState();
    _setTimestampAndTxID(state, timestamp, txID);
    SubAccount storage sub = _requireSubAccount(state, subAccID);
    Account storage acc = _requireAccount(state, sub.accountID);

    _requirePermission(acc, sub, sig.signer, SubAccountPermRemoveSignerPermission);

    // ---------- Signature Verification -----------
    requireUniqSig(state, hashRemoveSigner(subAccID, signer, nonce), sig);
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
    uint64 permFlag
  ) private view {
    if (addressExists(acc.admins, signer)) return;
    uint64 permSet = _getPermSet(sub, signer);
    require(permSet & (SubAccountPermAdmin | permFlag) > 0, "no permission");
  }

  // Used for add and update signer permission. Perform additional check that the new permission is a subset of the caller's permission if the caller is not an admin
  function _requireUpsertSigner(
    Account storage acc,
    SubAccount storage sub,
    address actingAddress,
    uint64 newPerms,
    uint64 flag
  ) private view {
    // Actor is Account Admin. ALLOW
    if (addressExists(acc.admins, actingAddress)) return;
    // Actor is Sub Account Admin. ALLOW
    uint64 actingPerms = _getPermSet(sub, actingAddress);
    if (actingPerms & SubAccountPermAdmin > 0) return;
    // Actor must have the ability to call the function
    require(actingPerms & flag > 0, "actor can't call function");
    // Actor can only grant permissions that actor has
    require(actingPerms & newPerms == newPerms, "actor can't grant permission");
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
}
