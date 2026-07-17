pragma solidity ^0.8.20;

import "./FundingAndSettlement.sol";
import "./BaseContract.sol";
import "./ConfigContract.sol";
import "./signature/generated/SubAccountSig.sol";
import "../types/DataStructure.sol";
import "../types/PositionMap.sol";
import "../util/Asset.sol";
import "../util/BIMath.sol";
import "../interfaces/ISubAccount.sol";

contract SubAccountContract is ISubAccount, BaseContract, ConfigContract, FundingAndSettlement {
  using BIMath for BI;

  int64 private constant _DURATION_37_DAYS_NANO = 37 * 24 * 60 * 60 * 1e9; // 37 days
  int64 private constant _DURATION_150_DAYS_NANO = 150 * 24 * 60 * 60 * 1e9; // 150 days

  // DeriskToMaintenanceMarginRatio constants
  uint32 private constant DERISK_MM_RATIO_MIN = 1_000_000; // 1x
  uint32 private constant DERISK_MM_RATIO_MAX = 2_000_000; // 2x

  int32 private constant _MIN_ISOLATED_POSITION_LEVERAGE = 1_000_000; // 1x
  int32 private constant _MAX_ISOLATED_POSITION_LEVERAGE = 50_000_000; // 50x

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
    uint8 quoteCurrency,
    MarginType marginType,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashCreateSubAccount(accountID, subAccountID, quoteCurrency, marginType, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    _validateAndCreateBaseSubAccount(timestamp, accountID, subAccountID, quoteCurrency, marginType, sig.signer);
  }

  function _validateAndCreateBaseSubAccount(
    int64 timestamp,
    address accountID,
    uint64 subAccountID,
    uint8 quoteCurrency,
    MarginType marginType,
    address signer
  ) internal returns (SubAccount storage sub) {
    Account storage acc = state.accounts[accountID];
    require(quoteCurrency == CCY_USDT, "invalid quote currency");
    require(marginType == MarginType.SIMPLE_CROSS_MARGIN, "invalid margin type");
    require(acc.id != address(0), "account does not exist");
    require(subAccountID != 0, "invalid subaccount id");
    sub = state.subAccounts[subAccountID];
    require(sub.accountID == address(0), "subaccount already exists");
    require(!_isBridgingPartnerAccount(accountID), "bridging partners cannot have subaccount");

    // requires that the user is an account admin
    require(signerHasPerm(acc.signers, signer, AccountPermAdmin), "not account admin");

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
    int64 cappedExpiry = _min(keyExpiry, timestamp + _getMaxSessionDurationNano());

    // ---------- Signature Verification -----------
    _preventReplay(hashAddSessionKey(sessionKey, keyExpiry), sig);
    // ------- End of Signature Verification -------

    require(state.sessions[sessionKey].expiry == 0, "session key already exists");

    state.sessions[sessionKey] = Session(sig.signer, cappedExpiry);
  }

  function _getMaxSessionDurationNano() internal view returns (int64) {
    if (_isFeatureFlagEnabled(FeatureFlagID.EXTEND_MAX_SESSION_DURATION_TO_150_DAYS)) {
      return _DURATION_150_DAYS_NANO;
    }
    return _DURATION_37_DAYS_NANO;
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

  /// @notice Set margin configuration for a specific asset on a sub account.
  /// @dev Requires a trade permission signature, only allows isolated or simple cross margin, and
  /// rejects vaults or sub accounts with existing positions.
  /// @param timestamp The timestamp of the transaction
  /// @param txID The id of the transaction
  /// @param subAccID Target sub account id
  /// @param assetID Asset identifier whose margin config is updated
  /// @param marginType Desired margin type (isolated or simple cross)
  /// @param leverage Desired leverage for the asset on the sub account
  /// @param sig Permissioned signature authorizing the change
  function setSubAccountPositionMarginConfig(
    int64 timestamp,
    uint64 txID,
    uint64 subAccID,
    bytes32 assetID,
    PositionMarginType marginType,
    int32 leverage,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    if (marginType != PositionMarginType.ISOLATED && marginType != PositionMarginType.CROSS) {
      revert ErrSetPositionMarginConfigInvalidMarginType();
    }
    if (leverage < _MIN_ISOLATED_POSITION_LEVERAGE || leverage > _MAX_ISOLATED_POSITION_LEVERAGE) {
      revert ErrSetPositionMarginConfigInvalidLeverage();
    }
    SubAccount storage sub = _requireSubAccount(subAccID);
    _requireSignerOrSessionKeySubAccountPerm(sub, sig.signer, SubAccountPermTrade, timestamp);

    // In Risk, we also have a check for vault that relies on cluster config, which is not replicated on chain. Omit here

    PositionMarginConfig storage currentCfg = sub.positionMarginConfigs[assetID];
    PositionMarginType currentMarginType = currentCfg.marginType;
    currentMarginType = currentMarginType == PositionMarginType.UNSPECIFIED
      ? PositionMarginType.CROSS
      : currentMarginType;
    if (currentMarginType != marginType && _hasPosition(sub, assetID)) {
      revert ErrSetPostionMarginConfigPositionNotEmpty();
    }

    // ---------- Signature Verification -----------
    _preventReplayNoDupCheck(
      hashSetSubAccountPositionMarginConfig(subAccID, assetID, marginType, leverage, sig.nonce, sig.expiration),
      sig
    );
    // ------- End of Signature Verification -------

    PositionMarginConfig storage conf = sub.positionMarginConfigs[assetID];
    conf.marginType = marginType;
    conf.leverage = leverage;
  }

  /// @notice Switch a sub account between SINGLE_ASSET_MODE and MULTI_ASSET_MODE (MAM).
  /// @dev Mirrors the platform's SetSubAccountMode (MAM-3). The platform validates all switch
  /// preconditions (isolated-position MMR buffer, CDC headroom, IM coverage, zero USDT debt for
  /// MAM->SAM, whitelist/modeSwitchEnabled gating); the chain lacks CL/CDC/buffer config and trusts
  /// the trusted sequencer to only submit a switch that passed platform validation. The contract
  /// just records the resulting mode and the paired assertion confirms the field value.
  /// @param timestamp The timestamp of the transaction
  /// @param txID The transaction ID
  /// @param subAccID The subaccount ID
  /// @param mode The target mode (SINGLE_ASSET_MODE or MULTI_ASSET_MODE; UNIFIED is out of scope)
  /// @param isolatedAssets Sequencer-derived context (excluded from the signed payload, like
  /// `feeCharged`): the assets whose isolated margin configs this switch converts to cross.
  /// Risk stamps it at confirmation by iterating its config map (EVM mappings are not
  /// iterable); empty when isolated margin is allowed in MAM or the target is not MAM.
  /// @param sig The signature of the acting user
  function setSubAccountMode(
    int64 timestamp,
    uint64 txID,
    uint64 subAccID,
    SubAccountMode mode,
    bytes32[] calldata isolatedAssets,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    SubAccount storage sub = _requireSubAccount(subAccID);

    // permission: TRADE (verified) — account-level AccountPermTrade OR sub-level SubAccountPermTrade,
    // directly or via a valid session key, mirroring the platform's
    // requireSignerOrSessionKeySubAccountPerm. Same as SetSubAccountPositionMarginConfig. NOT admin.
    _requireSignerOrSessionKeySubAccountPerm(sub, sig.signer, SubAccountPermTrade, timestamp);

    // ---------- Signature Verification -----------
    _preventReplay(hashSetSubAccountMode(subAccID, mode, sig.nonce, sig.expiration), sig);
    // ------- End of Signature Verification -------

    // UNIFIED out of scope; only SINGLE <-> MULTI is supported.
    require(
      mode == SubAccountMode.SINGLE_ASSET_MODE || mode == SubAccountMode.MULTI_ASSET_MODE,
      "unsupported target mode"
    );

    // Mirror the platform apply order: settle pending funding at switch time so the
    // post-switch state matches the platform's (which funds-and-settles before flipping).
    _fundAndSettle(sub);

    // Mirror the platform apply: rewrite the stamped isolated configs to cross (leverage
    // preserved). The set is sequencer context — empty when no conversion applies — so the
    // contract needs no flag read and no iterable config storage.
    // The entries are isolated configs by construction (Risk derived the list from the same
    // state at confirmation) — trust the context, no re-check; leverage stays as stored.
    uint256 len = isolatedAssets.length;
    for (uint256 i; i < len; ) {
      sub.positionMarginConfigs[isolatedAssets[i]].marginType = PositionMarginType.CROSS;
      unchecked {
        ++i;
      }
    }

    sub.subAccountMode = mode;
  }

  function scalePositions(
    int64 timestamp,
    uint64 txID,
    bytes32 instrument,
    uint64[] calldata batchSubAccountIDs,
    uint32 scaleFrom,
    uint32 scaleTo
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    require(scaleFrom != 0 && scaleTo != 0, "invalid scale ratio");

    uint len = batchSubAccountIDs.length;
    require(len != 0, "scalePositions: empty batch");

    Kind kind = assetGetKind(instrument);
    require(kind == Kind.PERPS || kind == Kind.FUTURES, "scalePositions: only perp/future");

    uint256 underlyingDec = _getBalanceDecimal(assetGetUnderlying(instrument));
    BI memory fromBI = BIMath.fromUint32(scaleFrom, 0);
    BI memory toBI = BIMath.fromUint32(scaleTo, 0);

    for (uint i; i < len; ) {
      uint64 subID = batchSubAccountIDs[i];

      // Reject duplicate sub-accounts
      for (uint j; j < i; ) {
        require(batchSubAccountIDs[j] != subID, "scalePositions: duplicate sub-account");
        unchecked {
          ++j;
        }
      }

      SubAccount storage sub = _requireSubAccount(subID);

      // Settle pending perp funding on the CURRENT (pre-scale) size before resizing. Funding is lazy
      // ((fundingIndex - lastAppliedFundingIndex) * balance), so scaling balance first would mis-charge
      // it; this advances lastAppliedFundingIndex without changing balance.
      _fundAndSettle(sub);

      PositionsMap storage posmap = _getPositionCollection(sub, kind);
      Position storage pos = posmap.values[instrument];
      
      require(pos.id != 0x0 && pos.balance != 0, "scalePositions: no open position");

      pos.balance = BIMath.fromInt64(pos.balance, underlyingDec).mul(toBI).div(fromBI).toInt64(underlyingDec);
      unchecked {
        ++i;
      }
    }
  }
}
