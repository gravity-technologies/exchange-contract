pragma solidity ^0.8.20;

import "./TradeContract.sol";
import "./signature/generated/TransferSig.sol";
import "../util/BIMath.sol";

import {IL2SharedBridge} from "../../../lib/era-contracts/l2-contracts/contracts/bridge/interfaces/IL2SharedBridge.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {DepositProxy} from "../../DepositProxy.sol";

abstract contract TransferContract is TradeContract {
  using BIMath for BI;

  event Withdrawal(
    address indexed fromAccount,
    address indexed recipient, // the recipient of the withdrawal on L1
    Currency currency,
    uint64 numTokens,
    uint64 txID
  );

  event Deposit(
    address indexed toAccount,
    bytes32 indexed bridgeMintHash, // the hash of the BridgeMint event on L2
    Currency currency,
    uint64 numTokens,
    uint64 txID
  );

  /**
   * @notice Deposit collateral into a sub account
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param txHash hash of the BridgeMint event
   * @param accountID  account to deposit into
   * @param currency Currency to deposit
   * @param numTokens Number of tokens to deposit
   **/
  function deposit(
    int64 timestamp,
    uint64 txID,
    bytes32 txHash,
    address accountID,
    Currency currency,
    uint64 numTokens
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(currency == Currency.USDT, "invalid currency");
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
    account.spotBalances[currency] += numTokensSigned;
    state.totalSpotBalances[currency] += numTokensSigned;

    emit Deposit(accountID, txHash, currency, numTokens, txID);
  }

  /**
   * @notice Withdraw collateral from a sub account. This will call external contract.
   * This follows the Checks-Effects-Interactions pattern to mitigate reentrancy attack.
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromAccID Sub account to withdraw from
   * @param recipient address of the recipient
   * @param currency Currency to withdraw
   * @param numTokens Number of tokens to withdraw
   * @param sig Signature of the transaction
   **/
  function withdraw(
    int64 timestamp,
    uint64 txID,
    address fromAccID,
    address recipient,
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) external nonReentrant onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(currency == Currency.USDT, "invalid currency");
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
    require(amount <= acc.spotBalances[currency], "insufficient balance");

    acc.spotBalances[currency] -= amount;

    int64 amountAfterSocializedLoss = _applySocializedLoss(fromAccID, amount, currency);
    int64 amountToSend = _applyWithdrawalFee(amountAfterSocializedLoss, currency);

    state.totalSpotBalances[currency] -= amountToSend;

    _withdrawToL1(currency, amountToSend, recipient);

    emit Withdrawal(fromAccID, recipient, currency, numTokens, txID);
  }

  function _withdrawToL1(Currency currency, int64 amount, address recipient) private {
    (address l2SharedBridgeAddress, bool ok) = _getAddressConfig(ConfigID.L2_SHARED_BRIDGE_ADDRESS);
    require(ok, "missing L2 shared bridge address");
    IL2SharedBridge l2SharedBridge = IL2SharedBridge(l2SharedBridgeAddress);

    uint256 erc20AmountToSend = scaleToERC20Amount(currency, amount);

    l2SharedBridge.withdraw(recipient, getCurrencyERC20Address(currency), erc20AmountToSend);
  }

  function _applySocializedLoss(address fromAccID, int64 amount, Currency currency) private returns (int64) {
    (SubAccount storage insuranceFund, bool isInsuranceFundSet) = _getInsuranceFundSubAccount();
    if (!isInsuranceFundSet) {
      return amount;
    }

    _fundAndSettle(insuranceFund);
    int64 socializedLossHaircutAmount = SafeCast.toInt64(int(uint(_getSocializedLossHaircutAmount(fromAccID, amount))));
    if (socializedLossHaircutAmount > 0) {
      insuranceFund.spotBalances[currency] += socializedLossHaircutAmount;
    }

    return amount - socializedLossHaircutAmount;
  }

  function _applyWithdrawalFee(int64 amount, Currency currency) private returns (int64) {
    (SubAccount storage feeSubAcc, bool isFeeSubAccIdSet) = _getAdminFeeSubAccount();
    if (!isFeeSubAccIdSet) {
      return amount;
    }

    BI memory spotMarkPrice = _requireAssetPriceBI(_getSpotAssetID(currency));
    uint64 tokenDec = _getBalanceDecimal(currency);
    int64 withdrawalFeeCharged = _getWithdrawalFee().div(spotMarkPrice).toInt64(tokenDec);

    int64 amountAfterFee = amount - withdrawalFeeCharged;
    feeSubAcc.spotBalances[currency] += withdrawalFeeCharged;

    require(amountAfterFee > 0, "withdrawal amount too small");

    return amountAfterFee;
  }

  function _getWithdrawalFee() private view returns (BI memory) {
    (uint64 fee, bool feeSet) = _getUintConfig(ConfigID.WITHDRAWAL_FEE);
    if (!feeSet) {
      return BIMath.zero();
    }
    return BI(SafeCast.toInt256(uint(fee)), _getBalanceDecimal(Currency.USD));
  }

  function scaleToERC20Amount(Currency currency, int64 numTokens) private view returns (uint256) {
    address ta = getCurrencyERC20Address(currency);
    IERC20MetadataUpgradeable token = IERC20MetadataUpgradeable(ta);
    uint8 erc20TokenDec = token.decimals();
    int256 erc20Amount = BI(numTokens, _getBalanceDecimal(currency)).scale(erc20TokenDec).toInt256(erc20TokenDec);
    require(erc20Amount > 0, "invalid amount");
    return SafeCast.toUint256(erc20Amount);
  }

  function getCurrencyERC20Address(Currency currency) private view returns (address) {
    (address addr, bool ok) = _getAddressConfig2D(ConfigID.ERC20_ADDRESSES, _currencyToConfig(currency));
    require(ok, "unsupported currency");
    return addr;
  }

  /**
   * @notice Transfer tokens from one sub account to another sub account
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromSubID Sub account to transfer from
   * @param toSubID Sub account to transfer to
   * @param currency Currency to transfer
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
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(currency == Currency.USDT, "invalid currency");
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    _preventReplay(
      hashTransfer(fromAccID, fromSubID, toAccID, toSubID, currency, numTokens, sig.nonce, sig.expiration),
      sig
    );
    // ------- End of Signature Verification -------

    int64 numTokensSigned = SafeCast.toInt64(int(uint(numTokens)));
    require(numTokensSigned > 0, "invalid transfer amount");

    // 1. Same account
    if (fromAccID == toAccID) {
      require(fromSubID != toSubID, "self transfer");
      if (fromSubID == 0) {
        // 1.1 Main -> Sub
        _transferMainToSub(fromAccID, toAccID, toSubID, currency, numTokensSigned, sig);
      } else if (toSubID == 0) {
        // 1.2 Sub -> Main
        _transferSubToMain(fromSubID, fromAccID, toAccID, currency, numTokensSigned, sig);
      } else {
        // 1.3 Sub -> Sub
        _transferSubToSub(fromSubID, toSubID, fromAccID, toAccID, currency, numTokensSigned, sig);
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
    Currency currency,
    int64 numTokens,
    Signature calldata sig
  ) private {
    Account storage fromAcc = _requireAccount(fromAccID);
    _requireAccountPermission(fromAcc, sig.signer, AccountPermExternalTransfer);
    require(
      _isBridgingPartnerAccount(fromAccID) || fromAcc.onboardedTransferAccounts[toAccID],
      "bad external transfer address"
    );
    require(!_isUserAccount(fromAccID) || _isUserAccount(toAccID), "user account cannot transfer to non-user account");
    require(numTokens <= fromAcc.spotBalances[currency], "insufficient balance");
    fromAcc.spotBalances[currency] -= numTokens;
    _requireAccount(toAccID).spotBalances[currency] += numTokens;
  }

  function _transferMainToSub(
    address fromAccID,
    address toAccID,
    uint64 toSubID,
    Currency currency,
    int64 numTokens,
    Signature calldata sig
  ) private {
    Account storage fromAcc = _requireAccount(fromAccID);
    _requireAccountPermission(fromAcc, sig.signer, AccountPermInternalTransfer);
    require(numTokens <= fromAcc.spotBalances[currency], "insufficient balance");
    fromAcc.spotBalances[currency] -= numTokens;

    SubAccount storage toSubAcc = _requireSubAccount(toSubID);
    _requireSubAccountUnderAccount(toSubAcc, toAccID);
    _fundAndSettle(toSubAcc);
    toSubAcc.spotBalances[currency] += numTokens;
  }

  function _transferSubToMain(
    uint64 fromSubID,
    address fromAccID,
    address toAccID,
    Currency currency,
    int64 numTokens,
    Signature calldata sig
  ) private {
    SubAccount storage fromSub = _requireSubAccount(fromSubID);
    _requireSubAccountPermission(fromSub, sig.signer, SubAccountPermTransfer);
    _requireSubAccountUnderAccount(fromSub, fromAccID);

    _fundAndSettle(fromSub);

    fromSub.spotBalances[currency] -= numTokens;

    require(isAboveMaintenanceMargin(fromSub), "subaccount is below maintenance margin");
    _requireAccount(toAccID).spotBalances[currency] += numTokens;
  }

  function _transferSubToSub(
    uint64 fromSubID,
    uint64 toSubID,
    address fromAccID,
    address toAccID,
    Currency currency,
    int64 numTokens,
    Signature calldata sig
  ) private {
    SubAccount storage fromSub = _requireSubAccount(fromSubID);
    _requireSubAccountPermission(fromSub, sig.signer, SubAccountPermTransfer);
    _requireSubAccountUnderAccount(fromSub, fromAccID);

    SubAccount storage toSub = _requireSubAccount(toSubID);
    _requireSubAccountUnderAccount(toSub, toAccID);

    _fundAndSettle(fromSub);

    fromSub.spotBalances[currency] -= numTokens;

    require(isAboveMaintenanceMargin(fromSub), "subaccount is below maintenance margin");
    toSub.spotBalances[currency] += numTokens;
  }
}
