pragma solidity ^0.8.20;

import "./AirdropWhitelist.sol";
import "./ConfigContract.sol";
import "./FundingAndSettlement.sol";
import "./RiskCheck.sol";
import "./signature/generated/TransferSig.sol";
import "../util/BIMath.sol";

import {IL2SharedBridge} from "../../../lib/era-contracts/l2-contracts/contracts/bridge/interfaces/IL2SharedBridge.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {DepositProxy} from "../../DepositProxy.sol";
import "../interfaces/ITransfer.sol";

abstract contract TransferContract is ITransfer, ConfigContract, FundingAndSettlement, RiskCheck {
  using BIMath for BI;

  /**
   * @notice Deposit collateral into a sub account
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param txHash hash of the BridgeMint event
   * @param accountID  account to deposit into
   * @param currency uint8 to deposit
   * @param numTokens Number of tokens to deposit
   **/
  function deposit(
    int64 timestamp,
    uint64 txID,
    bytes32 txHash,
    address accountID,
    uint8 currency,
    uint64 numTokens
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(_currencyCanHoldSpotBalance(currency), "invalid currency");
    _setSequence(timestamp, txID);

    require(!state.replay.executed[txHash], "replayed payload");
    state.replay.executed[txHash] = true;

    // Signature verification is not required as this will always be called by our backend
    // and token transfer will fail if `fromEthAddress` haven't successfully bridged in
    // the token required for deposit

    int64 numTokensSigned = SafeCast.toInt64(int(uint(numTokens)));
    require(numTokensSigned > 0, "invalid deposit amount");

    uint256 fundExchangeAmount = scaleToERC20Amount(currency, numTokensSigned);

    getDepositProxy(accountID).fundExchange(getCurrencyERC20Address(currency), fundExchangeAmount);

    Account storage account = _requireAccount(accountID);
    account.fundingWalletBalances[currency] += numTokensSigned;
    state.totalSpotBalances[currency] += numTokensSigned;

    emit Deposit(accountID, txHash, currency, numTokens, txID);
  }

  /**
   * @notice Withdraw collateral from a sub account.
   * @dev Keeps the same accounting path as synchronous withdrawals, then routes execution:
   *  - immediate L2 -> L1 bridge when queue is empty and L2 liquidity is sufficient
   *  - enqueue for later processing otherwise (including when queue is already non-empty to preserve FIFO)
   * Emits the same `Withdrawal` event in both sync and async routes.
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromAccID Sub account to withdraw from
   * @param recipient address of the recipient
   * @param currency uint8 to withdraw
   * @param numTokens Number of tokens to withdraw
   * @param sig Signature of the transaction
   **/
  function withdraw(
    int64 timestamp,
    uint64 txID,
    address fromAccID,
    address recipient,
    uint8 currency,
    uint64 numTokens,
    Signature calldata sig
  ) external nonReentrant onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(_currencyCanHoldSpotBalance(currency), "invalid currency");
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(fromAccID);

    // Check if the signer has the permission to withdraw
    _requireAccountPermission(acc, sig.signer, AccountPermWithdraw);

    require(
      _isBridgingPartnerAccount(fromAccID) || acc.onboardedWithdrawalAddresses[recipient],
      "invalid withdrawal address"
    );

    // ---------- Signature Verification -----------
    _preventReplay(hashWithdrawal(fromAccID, recipient, currency, numTokens, sig.nonce, sig.expiration), sig);
    // ------- End of Signature Verification -------

    int64 amount = SafeCast.toInt64(int(uint(numTokens)));
    require(amount > 0, "invalid withdrawal amount");
    require(amount <= acc.fundingWalletBalances[currency], "insufficient balance");

    // Keep behavior backward compatible: missing L2 shared bridge config still reverts withdrawals.
    _requireL2SharedBridgeAddress();

    WithdrawalInfo memory info = _prepareWithdrawalInfo(acc, amount, currency);

    // Strict FIFO: once queue is non-empty, all new withdrawals are queued behind the existing head.
    if (_hasPendingWithdrawalRequest()) {
      _enqueuePendingWithdrawal(recipient, info.currency, info.amountToSend);
    } else if (_hasSufficientL2Balance(info.erc20Address, info.erc20AmountToSend)) {
      // Sufficient immediate L2 liquidity -> preserve existing synchronous bridge behavior.
      _withdrawToL1Raw(recipient, info.erc20Address, info.erc20AmountToSend);
    } else {
      // Insufficient immediate L2 liquidity -> accept request and process asynchronously.
      _enqueuePendingWithdrawal(recipient, info.currency, info.amountToSend);
    }

    emit Withdrawal(fromAccID, recipient, txID, info);
  }

  /// @dev Drains queue head-first while each head item can be bridged with current L2 balance.
  /// @param maxCount Maximum items to process (0 = unlimited, for backward compatibility).
  function processWithdrawalQueue(uint256 maxCount) external nonReentrant onlyTxOriginRole(LIQUIDITY_ORCHESTRATOR_ROLE) {
    uint256 processed;
    while (!_isPendingWithdrawalQueueEmpty() && (maxCount == 0 || processed < maxCount)) {
      WithdrawalQueue storage queue = state.pendingWithdrawalQueue;
      uint64 head = queue.head;
      PendingWithdrawalRequest storage req = queue.requests[head];
      uint256 erc20AmountToSend = scaleToERC20Amount(req.currency, req.amountToSend);
      address erc20Address = getCurrencyERC20Address(req.currency);
      // Stop at first unserviceable head to preserve strict FIFO ordering.
      if (!_hasSufficientL2Balance(erc20Address, erc20AmountToSend)) {
        break;
      }

      // Accounting was already applied at request time; queue drain only executes deferred bridge transfer.
      _withdrawToL1Raw(req.recipient, erc20Address, erc20AmountToSend);
      delete queue.requests[head];
      queue.head = head + 1;
      processed++;
    }
  }

  function setL1DefiVaultAddress(address recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(recipient != address(0), "invalid recipient");
    require(state.l1DefiVaultAddress == address(0), "L1 DeFi vault address already set");

    state.l1DefiVaultAddress = recipient;
    emit L1DefiVaultAddressSet(recipient);
  }

  function getL1DefiVaultAddress() external view returns (address) {
    return state.l1DefiVaultAddress;
  }

  function setNativeVaultGatewayAddress(address recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(recipient != address(0), "invalid recipient");
    require(state.nativeVaultGatewayAddress == address(0), "native vault gateway address already set");

    state.nativeVaultGatewayAddress = recipient;
    emit NativeVaultGatewayAddressSet(recipient);
  }

  function getNativeVaultGatewayAddress() external view returns (address) {
    return state.nativeVaultGatewayAddress;
  }

  /// @notice Bridges exchange-held vault assets to the appropriate L1 destination.
  /// @dev ERC20 assets go directly to the configured L1 DeFi vault. ETH uses the shared bridge
  ///      withdrawal flow and routes to the configured native vault gateway.
  function bridgeToL1DefiVault(
    address l2Token,
    uint256 amount
  ) external nonReentrant onlyTxOriginRole(LIQUIDITY_ORCHESTRATOR_ROLE) {
    require(l2Token != address(0), "invalid token");
    require(amount > 0, "invalid amount");
    require(_isPendingWithdrawalQueueEmpty(), "pending withdrawal queue must be empty");

    address recipient = _bridgeToL1DefiVaultRaw(l2Token, amount);
    emit L1DefiVaultBridge(l2Token, amount, recipient);
  }

  function setOverCollateralizedFundDestination(address destination) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(destination != address(0), "invalid destination");
    state.overCollateralizedFundDestination = destination;
    emit OverCollateralizedFundDestinationSet(destination);
  }

  function getOverCollateralizedFundDestination() external view returns (address) {
    return state.overCollateralizedFundDestination;
  }

  /// @notice Returns the current over-collateralized amount for a currency in raw ERC20
  ///         native-decimal units (exchange balance minus totalSpotBalances).
  function getOverCollateralizedAmount(uint8 currency) external view returns (uint256) {
    require(_currencyCanHoldSpotBalance(currency), "invalid currency");
    (, uint256 surplus) = _computeOverCollateralizedAmount(currency);
    return surplus;
  }

  /// @notice Sweeps a caller-specified amount of ERC20 surplus to the admin-configured L1 destination.
  /// @param currency The spot currency whose surplus to sweep.
  /// @param amount   Raw ERC20 amount in the token's native decimals (NOT the exchange's
  ///                 internal int64 balance-decimal representation). Passed directly to
  ///                 IL2SharedBridge.withdraw.
  function sweepOverCollateralizedFund(
    uint8 currency,
    uint256 amount
  ) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
    require(amount > 0, "invalid amount");
    (address destination, address erc20Address, uint256 surplus) = _requireSweepable(currency);
    require(amount <= surplus, "amount exceeds over-collateralized balance");
    _doSweep(currency, destination, erc20Address, amount);
  }

  /// @notice Sweeps the entire current ERC20 surplus for a currency to the admin-configured L1 destination.
  /// @return swept Raw ERC20 amount bridged out.
  function sweepAllOverCollateralizedFund(
    uint8 currency
  ) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 swept) {
    (address destination, address erc20Address, uint256 surplus) = _requireSweepable(currency);
    require(surplus > 0, "no over-collateralized balance");
    _doSweep(currency, destination, erc20Address, surplus);
    return surplus;
  }

  /// @dev Validates sweep preconditions (currency, destination set, queue empty) and returns
  ///      the ERC20 address, destination, and current surplus. Reverts on any precondition
  ///      failure so the two sweep entry points cannot diverge.
  function _requireSweepable(
    uint8 currency
  ) private view returns (address destination, address erc20Address, uint256 surplus) {
    require(_currencyCanHoldSpotBalance(currency), "invalid currency");

    destination = state.overCollateralizedFundDestination;
    require(destination != address(0), "destination not set");

    // Queued withdrawals have already been debited from totalSpotBalances but their tokens
    // still sit on this contract, so they would otherwise show up as surplus.
    require(_isPendingWithdrawalQueueEmpty(), "pending withdrawal queue must be empty");

    (erc20Address, surplus) = _computeOverCollateralizedAmount(currency);
  }

  /// @dev Pure arithmetic: derives the over-collateralized amount in raw ERC20 units.
  ///      scaleToERC20Amount requires a positive int64, so non-positive tracked totals are
  ///      treated as zero (whole balance counts as surplus).
  function _computeOverCollateralizedAmount(
    uint8 currency
  ) private view returns (address erc20Address, uint256 surplus) {
    erc20Address = getCurrencyERC20Address(currency);
    uint256 erc20Balance = IERC20MetadataUpgradeable(erc20Address).balanceOf(address(this));
    int64 tracked = state.totalSpotBalances[currency];
    uint256 trackedErc20 = tracked > 0 ? scaleToERC20Amount(currency, tracked) : 0;
    surplus = erc20Balance > trackedErc20 ? erc20Balance - trackedErc20 : 0;
  }

  function _doSweep(uint8 currency, address destination, address erc20Address, uint256 amount) private {
    _withdrawToL1Raw(destination, erc20Address, amount);
    emit OverCollateralizedFundSwept(currency, erc20Address, destination, amount);
  }

  /// @dev Applies withdrawal accounting immediately; this function does not perform bridge side effects.
  function _prepareWithdrawalInfo(
    Account storage acc,
    int64 amount,
    uint8 currency
  ) private returns (WithdrawalInfo memory) {
    acc.fundingWalletBalances[currency] -= amount;

    (int64 amountAfterSocializedLoss, int64 socializedLossHaircutAmount) = _applySocializedLoss(
      acc.id,
      amount,
      currency
    );
    (int64 amountToSend, int64 withdrawalFeeCharged) = _applyWithdrawalFee(acc.id, amountAfterSocializedLoss, currency);

    state.totalSpotBalances[currency] -= amountToSend;

    address erc20Address = getCurrencyERC20Address(currency);
    uint256 erc20AmountToSend = scaleToERC20Amount(currency, amountToSend);

    return
      WithdrawalInfo({
        currency: currency,
        amount: amount,
        socializedLossHaircutAmount: socializedLossHaircutAmount,
        withdrawalFeeCharged: withdrawalFeeCharged,
        amountToSend: amountToSend,
        erc20Address: erc20Address,
        erc20AmountToSend: erc20AmountToSend
      });
  }

  function _withdrawToL1(uint8 currency, int64 amount, address recipient) private returns (address, uint256) {
    uint256 erc20AmountToSend = scaleToERC20Amount(currency, amount);
    address erc20Address = getCurrencyERC20Address(currency);
    _withdrawToL1Raw(recipient, erc20Address, erc20AmountToSend);

    return (erc20Address, erc20AmountToSend);
  }

  function _withdrawToL1Raw(address recipient, address erc20Address, uint256 erc20AmountToSend) private {
    IL2SharedBridge l2SharedBridge = IL2SharedBridge(_requireL2SharedBridgeAddress());
    l2SharedBridge.withdraw(recipient, erc20Address, erc20AmountToSend);
  }

  function _bridgeToL1DefiVaultRaw(address l2Token, uint256 amount) private returns (address) {
    address recipient = _getL1BridgeRecipient(l2Token);
    require(recipient != address(0), "no recipient");
    _withdrawToL1Raw(recipient, l2Token, amount);
    return recipient;
  }

  /// @dev ETH bridging is optional until its ERC20 config is set. Before then, all bridgeable tokens route to the
  ///      L1 DeFi vault.
  function _getL1BridgeRecipient(address l2Token) internal view returns (address) {
    ConfigValue storage ethConfig = state.config2DValues[ConfigID.ERC20_ADDRESSES][_currencyToConfig(CCY_ETH)];
    address ethL2Token = _configToAddress(ethConfig.val);
    bool isEthConfigured = ethConfig.isSet;
    if (isEthConfigured && l2Token == ethL2Token) {
      return state.nativeVaultGatewayAddress;
    }
    return state.l1DefiVaultAddress;
  }

  function _requireL2SharedBridgeAddress() private view returns (address) {
    (address l2SharedBridgeAddress, bool ok) = _getAddressConfig(ConfigID.L2_SHARED_BRIDGE_ADDRESS);
    require(ok, "missing L2 shared bridge address");
    return l2SharedBridgeAddress;
  }

  function _hasPendingWithdrawalRequest() private view returns (bool) {
    return !_isPendingWithdrawalQueueEmpty();
  }

  /// @dev Enqueues a new pending withdrawal using current sequencer timestamp.
  function _enqueuePendingWithdrawal(address recipient, uint8 currency, int64 amountToSend) private {
    WithdrawalQueue storage queue = state.pendingWithdrawalQueue;
    uint64 tail = queue.tail;
    require(tail < type(uint64).max, "withdrawal queue overflow");

    queue.requests[tail] = PendingWithdrawalRequest({
      recipient: recipient,
      currency: currency,
      amountToSend: amountToSend,
      enqueuedTimestampNs: state.timestamp
    });
    queue.tail = tail + 1;
  }

  function _hasSufficientL2Balance(address erc20Address, uint256 erc20AmountToSend) private view returns (bool) {
    return IERC20MetadataUpgradeable(erc20Address).balanceOf(address(this)) >= erc20AmountToSend;
  }

  function _applySocializedLoss(address fromAccID, int64 amount, uint8 currency) private returns (int64, int64) {
    (SubAccount storage insuranceFund, bool isInsuranceFundSet) = _getInsuranceFundSubAccount();
    if (!isInsuranceFundSet) {
      return (amount, 0);
    }

    _fundAndSettle(insuranceFund);

    // Socialized loss haircut only applies to USDT withdrawals.
    // Non-USDT withdrawals are not subject to socialized loss because the haircut
    // and total client equity calculations operate entirely in USDT terms.
    if (currency == CCY_USDT) {
      int64 socializedLossHaircutAmount = SafeCast.toInt64(int(uint(_getSocializedLossHaircutAmount(fromAccID, amount))));
      if (socializedLossHaircutAmount > 0) {
        insuranceFund.futuresWalletBalances[currency] += socializedLossHaircutAmount;
      }
      return (amount - socializedLossHaircutAmount, socializedLossHaircutAmount);
    }

    return (amount, 0);
  }

  function _applyWithdrawalFee(address fromAccID, int64 amount, uint8 currency) private returns (int64, int64) {
    if (_isWithdrawalFeeExempt(fromAccID)) {
      return (amount, 0);
    }
    (SubAccount storage feeSubAcc, bool isFeeSubAccIdSet) = _getAdminFeeSubAccount();
    if (!isFeeSubAccIdSet) {
      return (amount, 0);
    }

    int64 withdrawalFeeCharged = _convertCurrency(_getWithdrawalFeeInUSDT(), CCY_USDT, currency).toInt64(
      _getBalanceDecimal(currency)
    );

    int64 amountAfterFee = amount - withdrawalFeeCharged;
    // Route fees by currency: USDT fees go to futures wallet (perps collateral),
    // non-USDT fees go to spot wallet to keep perps wallets USDT-only.
    if (currency == CCY_USDT) {
      feeSubAcc.futuresWalletBalances[currency] += withdrawalFeeCharged;
    } else {
      feeSubAcc.spotWalletBalances[currency] += withdrawalFeeCharged;
    }

    require(amountAfterFee > 0, "withdrawal amount too small");

    return (amountAfterFee, withdrawalFeeCharged);
  }

  /// @dev Get the withdrawal fee in USDT
  function _getWithdrawalFeeInUSDT() private view returns (BI memory) {
    (uint64 fee, bool feeSet) = _getUintConfig(ConfigID.WITHDRAWAL_FEE);
    if (!feeSet) {
      return BIMath.zero();
    }
    return BI(SafeCast.toInt256(uint(fee)), _getBalanceDecimal(CCY_USDT));
  }

  function scaleToERC20Amount(uint8 currency, int64 numTokens) private view returns (uint256) {
    address ta = getCurrencyERC20Address(currency);
    IERC20MetadataUpgradeable token = IERC20MetadataUpgradeable(ta);
    uint8 erc20TokenDec = token.decimals();
    int256 erc20Amount = BI(numTokens, _getBalanceDecimal(currency)).scale(erc20TokenDec).toInt256(erc20TokenDec);
    require(erc20Amount > 0, "invalid amount");
    return SafeCast.toUint256(erc20Amount);
  }

  function getCurrencyERC20Address(uint8 currency) private view returns (address) {
    (address addr, bool ok) = _getAddressConfig2D(ConfigID.ERC20_ADDRESSES, _currencyToConfig(currency));
    require(ok, "unsupported currency");
    return addr;
  }

  /**
   * @notice Transfer tokens from one sub account to another sub account
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromAccID Sub account to transfer from
   * @param fromSubID Sub account to transfer from
   * @param toAccID Sub account to transfer to
   * @param toSubID Sub account to transfer to
   * @param currency uint8 to transfer
   * @param numTokens Number of tokens to transfer
   * @param sig Signature of the transaction
   */
  function transfer(
    int64 timestamp,
    uint64 txID,
    address fromAccID,
    uint64 fromSubID,
    address toAccID,
    uint64 toSubID,
    uint8 currency,
    uint64 numTokens,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _doTransfer(timestamp, txID, fromAccID, fromSubID, toAccID, toSubID, currency, numTokens,
      WalletType.UNSPECIFIED, WalletType.UNSPECIFIED, false, sig);
  }

  /**
   * @notice Transfer tokens from one sub account to another sub account with explicit wallet type routing
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromAccID Sub account to transfer from
   * @param fromSubID Sub account to transfer from
   * @param toAccID Sub account to transfer to
   * @param toSubID Sub account to transfer to
   * @param currency uint8 to transfer
   * @param numTokens Number of tokens to transfer
   * @param fromWalletType Source wallet type (UNSPECIFIED resolves to default)
   * @param toWalletType Destination wallet type (UNSPECIFIED resolves to default)
   * @param sig Signature of the transaction
   */
  function transferV2(
    int64 timestamp,
    uint64 txID,
    address fromAccID,
    uint64 fromSubID,
    address toAccID,
    uint64 toSubID,
    uint8 currency,
    uint64 numTokens,
    WalletType fromWalletType,
    WalletType toWalletType,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(fromWalletType != WalletType.UNSPECIFIED, "fromWalletType must be specified");
    require(toWalletType != WalletType.UNSPECIFIED, "toWalletType must be specified");
    _doTransfer(timestamp, txID, fromAccID, fromSubID, toAccID, toSubID, currency, numTokens,
      fromWalletType, toWalletType, true, sig);
  }

  function _doTransfer(
    int64 timestamp,
    uint64 txID,
    address fromAccID,
    uint64 fromSubID,
    address toAccID,
    uint64 toSubID,
    uint8 currency,
    uint64 numTokens,
    WalletType fromWalletType,
    WalletType toWalletType,
    bool useV2Signature,
    Signature calldata sig
  ) private {
    require(_currencyCanHoldSpotBalance(currency), "invalid currency");
    _setSequence(timestamp, txID);

    // Resolve wallet types to defaults
    WalletType resolvedFrom = _resolveWalletType(fromSubID, fromWalletType);
    WalletType resolvedTo = _resolveWalletType(toSubID, toWalletType);

    // Validate destination wallet currency restrictions
    _validateCurrencyForDestWallet(toSubID, resolvedTo, currency);

    // ---------- Signature Verification -----------
    if (useV2Signature) {
      _preventReplay(
        hashTransferV2(
          fromAccID, fromSubID, toAccID, toSubID, currency, numTokens,
          fromWalletType, toWalletType, sig.nonce, sig.expiration
        ),
        sig
      );
    } else {
      _preventReplay(
        hashTransfer(fromAccID, fromSubID, toAccID, toSubID, currency, numTokens, sig.nonce, sig.expiration),
        sig
      );
    }
    // ------- End of Signature Verification -------

    int64 numTokensSigned = SafeCast.toInt64(int(uint(numTokens)));
    require(numTokensSigned > 0, "invalid transfer amount");

    // 1. Same account
    if (fromAccID == toAccID) {
      require(
        fromSubID != toSubID || resolvedFrom != resolvedTo,
        "self transfer"
      );
      if (fromSubID == 0) {
        // 1.1 Main -> Sub
        _transferMainToSub(timestamp, fromAccID, toAccID, toSubID, resolvedTo, currency, numTokensSigned, sig);
      } else if (toSubID == 0) {
        // 1.2 Sub -> Main
        _transferSubToMain(timestamp, fromSubID, fromAccID, toAccID, resolvedFrom, currency, numTokensSigned, sig);
      } else {
        // 1.3 Sub -> Sub
        _transferSubToSub(
          timestamp, fromSubID, toSubID, fromAccID, toAccID, resolvedFrom, resolvedTo, currency, numTokensSigned, sig
        );
      }
    } else {
      // 2. Different accounts
      require(fromSubID == 0 && toSubID == 0, "subs transfer, diff acccounts");
      _transferMainToMain(fromAccID, toAccID, currency, numTokensSigned, sig);
    }
  }

  function _transferMainToMain(
    address fromAccID,
    address toAccID,
    uint8 currency,
    int64 numTokens,
    Signature calldata sig
  ) private {
    // Block external main-account -> main-account transfers for currencies on the
    // blockTransferMainToMainCurrencies denylist (e.g. GRVT), unless the source account is
    // exempt via blockTransferMainToMainExemptAccounts. Only this path is affected.
    require(
      !_isBlockTransferMainToMainCurrency(currency) || _isBlockTransferMainToMainExempt(fromAccID),
      "currency blocked for main to main transfer"
    );
    // Hardcoded restriction on all networks: external main-account -> main-account transfers are
    // limited to USDC and USDT. GRVT token airdrops are separately whitelisted via
    // isAirdropWhitelisted (see AirdropWhitelist.sol). ETH is not permitted.
    require(
      currency == CCY_USDC || currency == CCY_USDT || isAirdropWhitelisted(currency, fromAccID),
      "transfer blocked"
    );
    Account storage fromAcc = _requireAccount(fromAccID);
    _requireAccountPermission(fromAcc, sig.signer, AccountPermExternalTransfer);
    require(
      fromAcc.onboardedTransferAccounts[toAccID] ||
        _isBridgingPartnerAccount(fromAccID) ||
        _isBridgingPartnerAccount(toAccID),
      "bad external transfer address"
    );
    if (_isUserAccount(fromAccID)) {
      require(!_isInternalAccount(toAccID), "user account cannot transfer to internal account");
      if (_isBridgingPartnerAccount(toAccID)) {
        require(
          !_isSocializedLossActive(),
          "transfer to bridging partner is not allowed when socialized loss is active"
        );
      }
    }
    require(numTokens >= 0, "invalid transfer amount");
    require(numTokens <= fromAcc.fundingWalletBalances[currency], "insufficient balance");
    fromAcc.fundingWalletBalances[currency] -= numTokens;
    _requireAccount(toAccID).fundingWalletBalances[currency] += numTokens;
  }

  function _isSocializedLossActive() private view returns (bool) {
    return _getInsuranceFundLossAmountUSDT() > 0;
  }

  function _transferMainToSub(
    int64 timestamp,
    address fromAccID,
    address toAccID,
    uint64 toSubID,
    WalletType toWalletType,
    uint8 currency,
    int64 numTokens,
    Signature calldata sig
  ) private {
    Account storage fromAcc = _requireAccount(fromAccID);
    _requireSignerOrSessionKeyAccountPerm(fromAcc, sig.signer, AccountPermInternalTransfer, timestamp);

    SubAccount storage toSubAcc = _requireSubAccount(toSubID);
    require(!toSubAcc.isVault || toSubAcc.vaultInfo.isCrossExchange, "no transfer to on-exchange vault subaccount");
    require(!toSubAcc.isVault || toWalletType != WalletType.SPOT, "transfer to vault spot wallet");

    _requireSubAccountUnderAccount(toSubAcc, toAccID);
    _doTransferMainToSub(fromAcc, toSubAcc, toWalletType, currency, numTokens);
  }

  function _doTransferMainToSub(
    Account storage fromAcc,
    SubAccount storage toSubAcc,
    WalletType toWalletType,
    uint8 currency,
    int64 numTokens
  ) internal {
    require(numTokens >= 0, "invalid transfer amount");
    require(numTokens <= fromAcc.fundingWalletBalances[currency], "insufficient balance");

    _fundAndSettle(toSubAcc);

    fromAcc.fundingWalletBalances[currency] -= numTokens;
    _creditSubAccountWallet(toSubAcc, toWalletType, currency, numTokens);
  }

  function _transferSubToMain(
    int64 timestamp,
    uint64 fromSubID,
    address fromAccID,
    address toAccID,
    WalletType fromWalletType,
    uint8 currency,
    int64 numTokens,
    Signature calldata sig
  ) private {
    SubAccount storage fromSub = _requireSubAccount(fromSubID);
    require(!fromSub.isVault || fromSub.vaultInfo.isCrossExchange, "transfer from on-exchange vault subaccount");
    require(!fromSub.isVault || fromWalletType != WalletType.SPOT, "transfer from vault spot wallet");
    _requireSignerOrSessionKeySubAccountPerm(fromSub, sig.signer, SubAccountPermTransfer, timestamp);
    _requireSubAccountUnderAccount(fromSub, fromAccID);

    Account storage toAcc = _requireAccount(toAccID);

    _doTransferSubToMain(fromSub, toAcc, fromWalletType, currency, numTokens);
  }

  function _doTransferSubToMain(
    SubAccount storage fromSub,
    Account storage toAcc,
    WalletType fromWalletType,
    uint8 currency,
    int64 numTokens
  ) internal {
    require(numTokens >= 0, "invalid transfer amount");

    _fundAndSettle(fromSub);

    _debitSubAccountWallet(fromSub, fromWalletType, currency, numTokens);
    toAcc.fundingWalletBalances[currency] += numTokens;

    if (fromWalletType == WalletType.FUTURES) {
      require(_getTotalEquityCrossInQuote(fromSub).val >= 0, "subaccount value is negative");
    }
  }

  function _transferSubToSub(
    int64 timestamp,
    uint64 fromSubID,
    uint64 toSubID,
    address fromAccID,
    address toAccID,
    WalletType fromWalletType,
    WalletType toWalletType,
    uint8 currency,
    int64 numTokens,
    Signature calldata sig
  ) private {
    SubAccount storage fromSub = _requireSubAccount(fromSubID);
    _requireSignerOrSessionKeySubAccountPerm(fromSub, sig.signer, SubAccountPermTransfer, timestamp);
    _requireSubAccountUnderAccount(fromSub, fromAccID);

    SubAccount storage toSub = _requireSubAccount(toSubID);
    _requireSubAccountUnderAccount(toSub, toAccID);

    require(numTokens >= 0, "invalid transfer amount");
    require(!fromSub.isVault || fromSub.vaultInfo.isCrossExchange, "transfer from on-exchange vault subaccount");
    require(!fromSub.isVault || fromWalletType != WalletType.SPOT, "transfer from vault spot wallet");
    require(!toSub.isVault || toSub.vaultInfo.isCrossExchange, "transfer to on-exchange vault subaccount");
    require(!toSub.isVault || toWalletType != WalletType.SPOT, "transfer to vault spot wallet");

    _fundAndSettle(fromSub);
    _fundAndSettle(toSub);

    _debitSubAccountWallet(fromSub, fromWalletType, currency, numTokens);
    if (fromWalletType == WalletType.FUTURES) {
      require(_getTotalEquityCrossInQuote(fromSub).val >= 0, "subaccount value is negative");
    }
    _creditSubAccountWallet(toSub, toWalletType, currency, numTokens);
  }

  function _resolveWalletType(uint64 subID, WalletType wt) private pure returns (WalletType) {
    if (wt != WalletType.UNSPECIFIED) {
      if (subID == 0) {
        require(wt == WalletType.FUNDING, "subID 0 must use FUNDING wallet");
      } else {
        require(wt == WalletType.SPOT || wt == WalletType.FUTURES, "subID > 0 must use SPOT or FUTURES wallet");
      }
      return wt;
    }
    // UNSPECIFIED: default based on subID
    return subID == 0 ? WalletType.FUNDING : WalletType.FUTURES;
  }

  /// @dev Validates that the given currency is allowed in the destination wallet.
  /// Spot and funding wallets allow all currencies. Futures wallets are restricted based on SubAccountMode.
  function _validateCurrencyForDestWallet(uint64 toSubID, WalletType toWalletType, uint8 currency) private view {
    if (toWalletType == WalletType.SPOT || toWalletType == WalletType.FUNDING) {
      // Spot and funding wallets allow all spot assets
      return;
    }
    if (toWalletType == WalletType.FUTURES) {
      SubAccount storage sub = _requireSubAccount(toSubID);
      SubAccountMode mode = sub.subAccountMode;
      // UNSPECIFIED is treated as SINGLE_ASSET_MODE for backward compatibility (existing sub-accounts have UNSPECIFIED in storage)
      if (mode == SubAccountMode.SINGLE_ASSET_MODE || mode == SubAccountMode.UNSPECIFIED) {
        require(currency == CCY_USDT, "SINGLE_ASSET_MODE only allows USDT");
        return;
      }
      revert("unsupported sub account mode");
    }
    revert("unsupported wallet type");
  }

  function _debitSubAccountWallet(
    SubAccount storage sub,
    WalletType wt,
    uint8 currency,
    int64 amount
  ) private {
    if (wt == WalletType.FUTURES) {
      sub.futuresWalletBalances[currency] -= amount;
    } else {
      require(amount <= sub.spotWalletBalances[currency], "insufficient balance");
      sub.spotWalletBalances[currency] -= amount;
    }
  }

  function _creditSubAccountWallet(
    SubAccount storage sub,
    WalletType wt,
    uint8 currency,
    int64 amount
  ) private {
    if (wt == WalletType.FUTURES) {
      sub.futuresWalletBalances[currency] += amount;
    } else {
      sub.spotWalletBalances[currency] += amount;
    }
  }

  function _getSocializedLossHaircutAmount(address fromAccID, int64 withdrawAmount) private view returns (uint64) {
    int64 insuranceFundLossAmountUSDT = _getInsuranceFundLossAmountUSDT();
    if (insuranceFundLossAmountUSDT == 0) {
      return 0;
    }

    // non-user accounts are not subject to socialized loss
    if (!_isUserAccount(fromAccID)) {
      return 0;
    }

    int64 totalClientValueUSDT = _getTotalClientValueUSDT();
    int haircutAmount = (int(withdrawAmount) * int(insuranceFundLossAmountUSDT)) / int(totalClientValueUSDT);
    return SafeCast.toUint64(SafeCast.toUint256(haircutAmount));
  }
}
