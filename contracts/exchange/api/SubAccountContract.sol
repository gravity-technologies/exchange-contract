// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "./signature/generated/SubAccountSig.sol";
import "../types/DataStructure.sol";
import "../util/Address.sol";

contract SubAccountContract is BaseContract {
  int64 private constant _MAX_SESSION_DURATION_NANO = 24 * 60 * 60 * 1e9; // 24 hours

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

    acc.subAccounts.push(subAccountID);
  }

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
    require(sub.options.keys.length + sub.futures.keys.length + sub.perps.keys.length == 0, "open positions exist");
    _requireSubAccountPermission(sub, sig.signer, SubAccountPermAdmin);

    // ---------- Signature Verification -----------
    _preventReplay(hashSetMarginType(subAccID, marginType, sig.nonce), sig);
    // ------- End of Signature Verification -------

    sub.marginType = marginType;
  }

  function addSubAccountSigner(
    int64 timestamp,
    uint64 txID,
    uint64 subID,
    address signer,
    uint64 permissions,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subID);
    Account storage acc = _requireAccount(sub.accountID);
    _requireUpsertSigner(acc, sub, sig.signer, permissions, SubAccountPermAdmin);

    // // ---------- Signature Verification -----------
    _preventReplay(hashAddSubAccountSigner(subID, signer, permissions, sig.nonce), sig);
    // ------- End of Signature Verification -------

    sub.signers[signer] = permissions;
  }

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

    sub.signers[signer] = 0;
  }

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

  function removeSessionKey(int64 timestamp, uint64 txID, address signer) external {
    _setSequence(timestamp, txID);
    delete state.sessions[signer];
  }

  function _min(int64 a, int64 b) private pure returns (int64) {
    return a <= b ? a : b;
  }
}
