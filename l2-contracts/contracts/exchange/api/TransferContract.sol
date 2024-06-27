// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TradeContract.sol";
import "./signature/generated/TransferSig.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../util/BIMath.sol";
import "../../interface/IL2StandardToken.sol";
import "../../interface/IL2SharedBridge.sol";

abstract contract ERC20 {
  /**
   * @dev Moves a `value` amount of tokens from the caller's account to `to`.
   * Returns a boolean value indicating whether the operation succeeded.
   */
  function transfer(address to, uint256 value) external virtual returns (bool);
}

abstract contract TransferContract is TradeContract {
  using BIMath for BI;

  /**
   * @notice Deposit collateral into a sub account
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param accountID  account to deposit into
   * @param currency Currency to deposit
   * @param numTokens Number of tokens to deposit
   * @param sig Signature of the transaction
   **/
  function deposit(
    int64 timestamp,
    uint64 txID,
    address fromEthAddress,
    address accountID,
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // Check if the deposit comes from a whilelisted deposit address
    // (address depositAddr, bool ok) = _getAddressConfig(ConfigID.DEPOSIT_ADDRESS);
    // require(ok && depositAddr == sig.signer, "invalid depositor");

    // ---------- Signature Verification -----------
    // _preventReplay(hashDeposit(fromEthAddress, accountID, currency, numTokens, sig.nonce), sig);
    // ------- End of Signature Verification -------

    // Signature verification is not required as this will always be called by our backend
    // and token transfer will fail if `fromEthAddress` haven't successfully bridged in
    // the token required for deposit

    int64 numTokensSigned = int64(numTokens);
    require(numTokensSigned >= 0, "invalid withdrawal amount");

    IL2StandardToken(getCurrencyERC20Address(currency)).fundExchangeAccount(fromEthAddress, numTokens);

    Account storage account = _requireAccount(accountID);
    account.spotBalances[currency] += numTokensSigned;
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
  ) external nonReentrant {
    _setSequence(timestamp, txID);
    Account storage acc = _requireAccount(fromAccID);

    // Check if the signer has the permission to withdraw
    _requireAccountPermission(acc, sig.signer, AccountPermWithdraw);
    require(acc.onboardedWithdrawalAddresses[recipient], "invalid withdrawal address");

    int64 numTokensSigned = int64(numTokens);
    require(numTokensSigned >= 0, "invalid withdrawal amount");

    // ---------- Signature Verification -----------
    // FIXME: disable for testnet testing
    // _preventReplay(hashWithdrawal(fromAccID, recipient, currency, numTokens, sig.nonce), sig);
    // ------- End of Signature Verification -------

    int64 withdrawalFee = 0;
    (uint64 feeSubAccId, bool feeSubAccIdSet) = _getUintConfig(ConfigID.ADMIN_FEE_SUB_ACCOUNT_ID);
    if (feeSubAccIdSet) {
      (uint64 spotMark, bool markSet) = _getMarkPrice9Decimals(_getSpotAssetID(currency));
      require(markSet, "missing mark price");
      uint64 tokenDec = _getBalanceDecimal(currency);
      withdrawalFee = BI(1, 0).div(BI(int256(int64(spotMark)), PRICE_DECIMALS)).toInt64(tokenDec);
      _requireSubAccount(feeSubAccId).spotBalances[currency] += int64(withdrawalFee);
    }

    require(numTokensSigned <= acc.spotBalances[currency], "insufficient balance");
    require(numTokensSigned > withdrawalFee, "withdrawal amount too small");

    acc.spotBalances[currency] -= numTokensSigned;

    int64 numTokensToSend = numTokensSigned - withdrawalFee;

    (address l2SharedBridgeAddress, bool ok) = _getAddressConfig(ConfigID.L2_SHARED_BRIDGE_ADDRESS);
    require(ok, "missing L2 shared bridge address");
    IL2SharedBridge l2SharedBridge = IL2SharedBridge(l2SharedBridgeAddress);

    l2SharedBridge.withdraw(recipient, getCurrencyERC20Address(currency), uint256(int256(numTokensToSend)));
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
  ) external {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    _preventReplay(hashTransfer(fromAccID, fromSubID, toAccID, toSubID, currency, numTokens, sig.nonce), sig);
    // ------- End of Signature Verification -------

    int64 numTokensSigned = int64(numTokens);
    require(numTokensSigned >= 0, "invalid transfer amount");
    // 1. Same account
    if (fromAccID == toAccID) {
      require(fromSubID != toSubID, "self transfer");
      if (fromSubID == 0) {
        // 1.1 Main -> Sub
        _transferMainToSub(fromAccID, toAccID, toSubID, currency, numTokensSigned, sig);
      } else if (toSubID == 0) {
        // 1.2 Sub -> Main
        _transferSubToMain(timestamp, fromSubID, fromAccID, toAccID, currency, numTokensSigned, sig);
      } else {
        // 1.3 Sub -> Sub
        _transferSubToSub(timestamp, fromSubID, toSubID, fromAccID, toAccID, currency, numTokensSigned, sig);
      }
    } else {
      // 2. Different accounts
      require(fromSubID == 0 && toSubID == 0, "transfer between sub accounts of different accounts");
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
    require(fromAcc.onboardedTransferAccounts[toAccID], "invalid external transfer address");
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
    toSubAcc.spotBalances[currency] += numTokens;
  }

  function _transferSubToMain(
    int64 timestamp,
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

    _fundAndSettle(timestamp, fromSub);

    fromSub.spotBalances[currency] -= numTokens;

    _requireValidSubAccountUsdValue(fromSub);
    _requireAccount(toAccID).spotBalances[currency] += numTokens;
  }

  function _transferSubToSub(
    int64 timestamp,
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

    _fundAndSettle(timestamp, fromSub);

    fromSub.spotBalances[currency] -= numTokens;

    _requireValidSubAccountUsdValue(fromSub);
    toSub.spotBalances[currency] += numTokens;
  }
}
