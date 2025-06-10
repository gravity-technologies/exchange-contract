pragma solidity ^0.8.20;

import "./FundingAndSettlement.sol";
import "./BaseContract.sol";
import "./ConfigContract.sol";
import "./signature/generated/SubAccountSig.sol";
import "../types/DataStructure.sol";

contract SubAccountContract is BaseContract, ConfigContract, FundingAndSettlement {
  int64 private constant _MAX_SESSION_DURATION_NANO = 37 * 24 * 60 * 60 * 1e9; // 31 days

  // DeriskToMaintenanceMarginRatio constants
  uint32 private constant DERISK_MM_RATIO_MIN = 1_000_000; // 1x
  uint32 private constant DERISK_MM_RATIO_MAX = 2_000_000; // 2x

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
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    Account storage acc = state.accounts[accountID];
    require(currencyCanHoldSpotBalance(quoteCurrency), "invalid quote currency");
    require(marginType == MarginType.SIMPLE_CROSS_MARGIN, "invalid margin type");
    require(acc.id != address(0), "account does not exist");
    require(subAccountID != 0, "invalid subaccount id");
    SubAccount storage sub = state.subAccounts[subAccountID];
    require(sub.accountID == address(0), "subaccount already exists");
    require(!_isBridgingPartnerAccount(accountID), "bridging partners cannot have subaccount");

    // requires that the user is an account admin
    require(acc.signers[sig.signer] & AccountPermAdmin > 0, "not account admin");

    // ---------- Signature Verification -----------
    bytes32 hash = hashCreateSubAccount(accountID, subAccountID, quoteCurrency, marginType, sig.nonce, sig.expiration);
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
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    revert("not supported");
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subAccID);

    require(marginType != MarginType.UNSPECIFIED, "invalid margin");
    // To change margin type requires that there's no OPEN position
    // See Binance: https://www.binance.com/en/support/faq/how-to-switch-between-cross-margin-mode-and-isolated-margin-mode-360038075852#:~:text=You%20are%20not%20allowed%20to%20change%20the%20margin%20mode%20if%20you%20have%20any%20open%20orders%20or%20positions%3B
    // TODO: revise this to if subaccount is liquidatable under new margin model. If it is not, we allow it through.
    _fundAndSettle(sub);
    require(sub.options.keys.length + sub.futures.keys.length + sub.perps.keys.length == 0, "open positions exist");
    _requireSubAccountPermission(sub, sig.signer, SubAccountPermAdmin);

    // ---------- Signature Verification -----------
    _preventReplay(hashSetMarginType(subAccID, marginType, sig.nonce, sig.expiration), sig);
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
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
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
    _preventReplay(hashAddSubAccountSigner(subID, signer, permissions, sig.nonce, sig.expiration), sig);
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
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subAccID);

    _requireSubAccountPermission(sub, sig.signer, SubAccountPermAdmin);

    // ---------- Signature Verification -----------
    _preventReplay(hashRemoveSigner(subAccID, signer, sig.nonce, sig.expiration), sig);
    // ------- End of Signature Verification -------

    require(sub.signers[signer] != 0, "signer not found");

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
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    require(keyExpiry > timestamp, "invalid expiry");
    // Cap the expiry to timestamp + maxSessionDurationInSec
    int64 cappedExpiry = _min(keyExpiry, timestamp + _MAX_SESSION_DURATION_NANO);

    // ---------- Signature Verification -----------
    _preventReplay(hashAddSessionKey(sessionKey, keyExpiry), sig);
    // ------- End of Signature Verification -------

    require(state.sessions[sessionKey].expiry == 0, "session key already exists");

    state.sessions[sessionKey] = Session(sig.signer, cappedExpiry);
  }

  /// @notice Removing signature verification only makes session keys safer.
  /// Operators can remove session keys upon user inactivity to keep users safe on their behalf.
  /// This only ever removes the privilege of a temporary key, and never breaks self-custody of assets.
  ///
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID of the transaction
  /// @param signer The address of the signer
  function removeSessionKey(
    int64 timestamp,
    uint64 txID,
    address signer
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    delete state.sessions[signer];
  }

  /// @notice Sets the deriskToMaintenanceMarginRatio, a crucial parameter controlling the account de-risking process.
  /// @notice De-risking is a mechanism to proactively reduce a user's leverage before liquidation, aiming to prevent it.
  /// It proportionately reduces all open positions at prices that widen the gap between the account's Equity and the Maintenance Margin Requirement (MMR).
  /// This helps avoid liquidation, improves user experience, and potentially retains funds on the account.
  /// @dev **Understanding the Ratio:**
  ///  - The ratio must be between 1 and 2 (inclusive).
  ///  - **1 (or less):** Disables de-risking. Liquidation occurs when Equity falls below the Maintenance Margin.
  ///  - **Between 1 and 2:** Triggers de-risking when Equity is between the Maintenance Margin and Initial Margin.
  ///    - Example: A ratio of 1.1 initiates de-risking when Equity is below 1.1 times the Maintenance Margin but still above the Maintenance Margin.
  /// @dev **How De-Risking Works:**
  ///  - When `MMR < Account Equity <= (deriskToMaintenanceMarginRatio * MMR)`, the system reduces position sizes.
  ///  - De-risking stops if the Account Equity falls below the MMR, and the liquidation process takes over.
  /// @dev **Important Considerations:**
  ///  - Setting a higher ratio triggers de-risking earlier, potentially preventing liquidation but also reducing positions sooner.
  ///  - Setting a lower ratio delays de-risking, allowing for more leverage but increasing the risk of liquidation.
  ///  - This parameter affects the entire sub account and is not specific to individual instruments.
  /// @dev **This was added on May 29, 2025.**
  ///  - Existing sub accounts have a deriskToMaintenanceMarginRatio of 0, ie de-risking is disabled.
  function setDeriskToMaintenanceMarginRatio(
    int64 timestamp,
    uint64 txID,
    uint64 subAccID,
    uint32 deriskToMaintenanceMarginRatio,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subAccID);

    // require subaccount signer to have trade permission
    _requireSubAccountPermission(sub, sig.signer, SubAccountPermTrade);

    // TODO: if sub account is a vault, reject

    // If sub account is the insurance fund, reject
    (uint64 insurFundSubID, bool isInsurFundSet) = _getUintConfig(ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID);
    require(!isInsurFundSet || insurFundSubID != subAccID, "insurFund cannot set derisk");

    require(
      deriskToMaintenanceMarginRatio >= DERISK_MM_RATIO_MIN && deriskToMaintenanceMarginRatio <= DERISK_MM_RATIO_MAX,
      "bad deriskRatio"
    );

    // ---------- Signature Verification -----------
    _preventReplay(
      hashSetDeriskToMaintenanceMarginRatio(subAccID, deriskToMaintenanceMarginRatio, sig.nonce, sig.expiration),
      sig
    );
    // ------- End of Signature Verification -------

    sub.deriskToMaintenanceMarginRatio = deriskToMaintenanceMarginRatio;
  }
}
