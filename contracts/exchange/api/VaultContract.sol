pragma solidity ^0.8.20;

import "./SubAccountContract.sol";
import "./TransferContract.sol";
import "./signature/generated/VaultSig.sol";

contract VaultContract is SubAccountContract, TransferContract {
  using BIMath for BI;

  function vaultCreate(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    address managerAccountID,
    Currency quoteCurrency,
    MarginType marginType,
    uint32 managementFeeCentiBeeps,
    uint32 performanceFeeCentiBeeps,
    uint32 marketingFeeCentiBeeps,
    uint64 initialInvestmentNumTokens,
    Signature calldata sig
  ) external nonReentrant onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashVaultCreate(
      vaultID,
      managerAccountID,
      quoteCurrency,
      marginType,
      managementFeeCentiBeeps,
      performanceFeeCentiBeeps,
      marketingFeeCentiBeeps,
      sig.nonce,
      sig.expiration
    );
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    require(quoteCurrency == Currency.USDT, "only USDT vault is supported");

    // signer Admin permission is checked here
    SubAccount storage vaultSub = _validateAndCreateBaseSubAccount(
      timestamp,
      managerAccountID,
      vaultID,
      quoteCurrency,
      marginType,
      sig.signer
    );

    vaultSub.isVault = true;
    vaultSub.vaultInfo.status = VaultStatus.ACTIVE;

    _validateAndUpdateVaultParams(
      vaultSub.vaultInfo,
      managementFeeCentiBeeps,
      performanceFeeCentiBeeps,
      marketingFeeCentiBeeps
    );

    vaultSub.vaultInfo.lastFeeSettlementTimestamp = timestamp;

    int64 initialInvestmentSigned = int64(initialInvestmentNumTokens);
    require(initialInvestmentSigned > 0, "initial investment must be positive");

    Account storage managerAcc = _requireAccount(managerAccountID);

    _investAndMintLpToken(vaultSub, managerAcc, initialInvestmentNumTokens);
  }

  function vaultUpdate(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    uint32 managementFeeCentiBeeps,
    uint32 performanceFeeCentiBeeps,
    uint32 marketingFeeCentiBeeps,
    Signature calldata sig
  ) external nonReentrant onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    SubAccount storage vaultSub = _requireVaultSubAccount(vaultID);
    _requireSubAccountPermission(vaultSub, sig.signer, SubAccountPermAdmin);

    // ---------- Signature Verification -----------
    bytes32 hash = hashVaultUpdate(
      vaultID,
      managementFeeCentiBeeps,
      performanceFeeCentiBeeps,
      marketingFeeCentiBeeps,
      sig.nonce,
      sig.expiration
    );
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    _validateAndUpdateVaultParams(
      vaultSub.vaultInfo,
      managementFeeCentiBeeps,
      performanceFeeCentiBeeps,
      marketingFeeCentiBeeps
    );
  }

  function _validateAndUpdateVaultParams(
    VaultInfo storage vaultInfo,
    uint32 managementFeeCentiBeeps,
    uint32 performanceFeeCentiBeeps,
    uint32 marketingFeeCentiBeeps
  ) internal {
    require(managementFeeCentiBeeps <= 400, "management fee must be <= 4%");
    require(performanceFeeCentiBeeps <= 4000, "performance fee must be <= 40%");
    require(marketingFeeCentiBeeps <= 4000, "marketing fee must be <= 40%");

    vaultInfo.managementFeeCentiBeeps = managementFeeCentiBeeps;
    vaultInfo.performanceFeeCentiBeeps = performanceFeeCentiBeeps;
    vaultInfo.marketingFeeCentiBeeps = marketingFeeCentiBeeps;
  }

  function vaultDelist(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID
  ) external nonReentrant onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    SubAccount storage vaultSub = _requireVaultSubAccount(vaultID);
    require(vaultSub.vaultInfo.status == VaultStatus.ACTIVE, "only active vault can be delisted");

    vaultSub.vaultInfo.status = VaultStatus.DELISTED;
  }

  function vaultClose(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID
  ) external nonReentrant onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    SubAccount storage vaultSub = _requireVaultSubAccount(vaultID);
    require(vaultSub.vaultInfo.status == VaultStatus.DELISTED, "only delisted vault can be closed");
    require(vaultSub.perps.keys.length == 0, "vault to close has perps positions");
    require(vaultSub.futures.keys.length == 0, "vault to close has futures positions");
    require(vaultSub.options.keys.length == 0, "vault to close has options positions");

    vaultSub.vaultInfo.status = VaultStatus.CLOSED;
  }

  function vaultInvest(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    address accountID,
    Currency tokenCurrency,
    uint64 numTokens,
    Signature calldata sig
  ) external nonReentrant onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    Account storage account = _requireAccount(accountID);
    _requireAccountPermission(account, sig.signer, AccountPermVaultInvest);

    SubAccount storage vaultSub = _requireVaultSubAccount(vaultID);
    require(vaultSub.vaultInfo.status == VaultStatus.ACTIVE, "only active vault can accept investment");
    require(tokenCurrency == vaultSub.quoteCurrency, "non-quote currency vault deposit");

    // ---------- Signature Verification -----------
    bytes32 hash = hashVaultInvest(vaultID, accountID, tokenCurrency, numTokens, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    _investAndMintLpToken(vaultSub, account, numTokens);
  }

  function _investAndMintLpToken(SubAccount storage vaultSub, Account storage account, uint64 numQuoteTokens) internal {
    int64 numQuoteTokensSigned = int64(numQuoteTokens);
    require(numQuoteTokensSigned > 0, "investment amount must be positive");

    uint64 lpTokensToMint = _calculateLpTokensToMintOnInvest(vaultSub, numQuoteTokens);
    require(lpTokensToMint > 0, "no LP tokens minted");

    _doTransferMainToSub(account, vaultSub, vaultSub.quoteCurrency, numQuoteTokensSigned);
    _mintLpTokens(vaultSub, account.id, lpTokensToMint, numQuoteTokens);
  }

  function _calculateLpTokensToMintOnInvest(
    SubAccount storage vaultSub,
    uint64 numQuoteTokens
  ) internal returns (uint64) {
    // Calculate LP tokens to mint based on proportion of equity increase
    if (vaultSub.vaultInfo.totalLpTokenSupply == 0) {
      // First investment - mint same amount as deposit
      return numQuoteTokens;
    }

    BI memory vaultEquityBeforeInQuote = _getSubAccountValueInQuote(vaultSub);
    require(vaultEquityBeforeInQuote.isPositive(), "vault equity is not positive");

    BI memory totalLpTokenSupplyBI = BIMath.fromUint64(
      vaultSub.vaultInfo.totalLpTokenSupply,
      _getBalanceDecimal(vaultSub.quoteCurrency)
    );

    uint64 qDec = _getBalanceDecimal(vaultSub.quoteCurrency);
    BI memory numQuoteTokensBI = BIMath.fromUint64(numQuoteTokens, qDec);
    BI memory lpTokensToMintBI = numQuoteTokensBI.mul(totalLpTokenSupplyBI).div(vaultEquityBeforeInQuote);

    return lpTokensToMintBI.toUint64(qDec);
  }

  function _mintLpTokens(
    SubAccount storage vaultSub,
    address accountID,
    uint64 lpTokenToMint,
    uint64 costInQuote
  ) internal {
    VaultInfo storage vaultInfo = vaultSub.vaultInfo;
    vaultInfo.totalLpTokenSupply += lpTokenToMint;

    VaultLpInfo storage lpInfo = vaultInfo.lpInfos[accountID];
    lpInfo.costInQuote += costInQuote;
    lpInfo.lpTokenBalance += lpTokenToMint;
  }

  function vaultBurnLpToken(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    uint64 numLpTokens,
    address accountID,
    Signature calldata sig
  ) external nonReentrant onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashVaultBurnLpToken(vaultID, numLpTokens, accountID, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    Account storage account = _requireAccount(accountID);
    _requireAccountPermission(account, sig.signer, AccountPermAdmin);

    SubAccount storage vaultSub = _requireVaultSubAccount(vaultID);

    _burnLpTokens(vaultSub, accountID, numLpTokens);
  }

  function vaultRedeem(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    uint64 numLpTokens,
    address accountID,
    uint64 marketingFeeChargedInLpToken,
    Signature calldata sig
  ) external nonReentrant onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    SubAccount storage vaultSub = _requireVaultSubAccount(vaultID);

    // ---------- Signature Verification -----------
    bytes32 hash = hashVaultRedeem(vaultID, numLpTokens, accountID, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    uint64 redeemedInQuote = _calculateQuoteTokenRedeemed(vaultSub, numLpTokens);
    uint64 costOfLpTokenBurnt = _burnLpTokens(vaultSub, accountID, numLpTokens);

    (uint64 performanceFeeInQuote, uint64 performanceFeeInLpToken) = _calculateRedemptionPerformanceFee(
      vaultSub,
      accountID,
      redeemedInQuote,
      costOfLpTokenBurnt
    );

    if (performanceFeeInLpToken > 0) {
      _mintLpTokenForFee(vaultSub, performanceFeeInLpToken, marketingFeeChargedInLpToken);
    }

    uint64 redeemedInQuoteAfterFee = redeemedInQuote - performanceFeeInQuote;

    int64 redeemedInQuoteAfterFeeSigned = int64(redeemedInQuoteAfterFee);
    require(redeemedInQuoteAfterFeeSigned > 0, "redeemed in quote after fee is not positive");

    _doTransferSubToMain(vaultSub, _requireAccount(accountID), vaultSub.quoteCurrency, redeemedInQuoteAfterFeeSigned);
  }

  function _calculateQuoteTokenRedeemed(SubAccount storage vaultSub, uint64 numLpTokens) internal returns (uint64) {
    BI memory vaultEquityInQuote = _getSubAccountValueInQuote(vaultSub);
    require(vaultEquityInQuote.isPositive(), "vault equity is not positive");

    BI memory totalLpTokenSupplyBI = BIMath.fromUint64(
      vaultSub.vaultInfo.totalLpTokenSupply,
      _getBalanceDecimal(vaultSub.quoteCurrency)
    );

    uint64 qDec = _getBalanceDecimal(vaultSub.quoteCurrency);

    BI memory numLpTokensBI = BIMath.fromUint64(numLpTokens, qDec);
    BI memory quoteTokenRedeemedBI = numLpTokensBI.mul(vaultEquityInQuote).div(totalLpTokenSupplyBI);

    return quoteTokenRedeemedBI.toUint64(qDec);
  }

  function _calculateRedemptionPerformanceFee(
    SubAccount storage vaultSub,
    address accountID,
    uint64 redeemedInQuote,
    uint64 costOfLpTokenBurnt
  ) internal returns (uint64, uint64) {
    uint64 qDec = _getBalanceDecimal(vaultSub.quoteCurrency);
    if (vaultSub.accountID == accountID || costOfLpTokenBurnt >= redeemedInQuote) {
      return (0, 0);
    }

    uint64 profitInQuote = redeemedInQuote - costOfLpTokenBurnt;
    BI memory profitInQuoteBI = BIMath.fromUint64(profitInQuote, qDec);
    BI memory performanceFeeRateBI = BIMath.fromUint32(vaultSub.vaultInfo.performanceFeeCentiBeeps, CENTIBEEP_DECIMALS);
    BI memory performanceFeeBI = profitInQuoteBI.mul(performanceFeeRateBI);
    uint64 performanceFeeInQuote = performanceFeeBI.toUint64(qDec);

    uint64 performanceFeeInLpToken = _calculateLpTokensToMintOnInvest(vaultSub, performanceFeeInQuote);

    if (performanceFeeInLpToken > 0) {
      return (performanceFeeInQuote, performanceFeeInLpToken);
    }

    return (0, 0);
  }

  function _burnLpTokens(
    SubAccount storage vaultSub,
    address accountID,
    uint64 lpTokenToBurn
  ) internal returns (uint64 costOfLpTokenBurnt) {
    VaultInfo storage vaultInfo = vaultSub.vaultInfo;
    vaultInfo.totalLpTokenSupply -= lpTokenToBurn;

    VaultLpInfo storage lpInfo = vaultInfo.lpInfos[accountID];
    require(lpInfo.lpTokenBalance >= lpTokenToBurn, "insufficient LP tokens");

    uint64 qDec = _getBalanceDecimal(vaultSub.quoteCurrency);
    BI memory costBI = BIMath.fromUint64(lpInfo.costInQuote, qDec);
    BI memory balanceBI = BIMath.fromUint64(lpInfo.lpTokenBalance, qDec);
    BI memory burnBI = BIMath.fromUint64(lpTokenToBurn, qDec);
    BI memory remainingBalanceBI = balanceBI.sub(burnBI);

    uint64 costInQuoteAfter = costBI.mul(remainingBalanceBI).div(balanceBI).toUint64(qDec);
    costOfLpTokenBurnt = lpInfo.costInQuote - costInQuoteAfter;

    lpInfo.costInQuote = costInQuoteAfter;
    lpInfo.lpTokenBalance -= lpTokenToBurn;

    return costOfLpTokenBurnt;
  }

  function vaultManagementFeeTick(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    uint64 marketingFeeChargedInLpToken
  ) external nonReentrant onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    SubAccount storage vaultSub = _requireVaultSubAccount(vaultID);

    _settleManagementFee(timestamp, vaultSub, marketingFeeChargedInLpToken);
  }

  function _settleManagementFee(
    int64 timestamp,
    SubAccount storage vaultSub,
    uint64 marketingFeeChargedInLpToken
  ) internal {
    VaultInfo storage vaultInfo = vaultSub.vaultInfo;

    require(vaultInfo.status == VaultStatus.ACTIVE, "only active vault can tick management fee");
    if (vaultInfo.totalLpTokenSupply == 0) {
      return;
    }

    (uint64 daysSinceLastFeeSettlement, uint64 managementFeeInLpToken) = _calculateManagementFee(timestamp, vaultSub);

    _mintLpTokenForFee(vaultSub, managementFeeInLpToken, marketingFeeChargedInLpToken);

    // only settle in whole days
    vaultSub.vaultInfo.lastFeeSettlementTimestamp += ONE_DAY_NANOS * int64(daysSinceLastFeeSettlement);
  }

  function _mintLpTokenForFee(
    SubAccount storage vaultSub,
    uint64 lpTokenToMint,
    uint64 marketingFeeChargedInLpToken
  ) internal {
    uint64 qDec = _getBalanceDecimal(vaultSub.quoteCurrency);

    BI memory lpTokenToMintBI = BIMath.fromUint64(lpTokenToMint, qDec);
    BI memory marketingFeeCapRatioBI = BIMath.fromUint32(vaultSub.vaultInfo.marketingFeeCentiBeeps, CENTIBEEP_DECIMALS);
    BI memory marketingFeeCapBI = lpTokenToMintBI.mul(marketingFeeCapRatioBI);
    uint64 marketingFeeCap = marketingFeeCapBI.toUint64(qDec);

    require(marketingFeeChargedInLpToken <= marketingFeeCap, "marketing fee charged is more than cap");

    (SubAccount storage feeSubAcc, bool isFeeSubAccIdSet) = _getAdminFeeSubAccount();

    uint64 managerPayment = lpTokenToMint;
    if (isFeeSubAccIdSet) {
      managerPayment -= marketingFeeChargedInLpToken;
      _mintLpTokens(vaultSub, feeSubAcc.accountID, marketingFeeChargedInLpToken, 0);
    }

    _mintLpTokens(vaultSub, vaultSub.accountID, managerPayment, 0);

    vaultSub.vaultInfo.totalLpTokenSupply += lpTokenToMint;
  }

  function _calculateManagementFee(
    int64 timestamp,
    SubAccount storage vaultSub
  ) internal view returns (uint64 daysSinceLastFeeSettlement, uint64 managementFeeInLpToken) {
    VaultInfo storage vaultInfo = vaultSub.vaultInfo;

    int64 lastFeeSettlementTimestamp = vaultInfo.lastFeeSettlementTimestamp;
    int64 timeSinceLastFeeSettlement = timestamp - lastFeeSettlementTimestamp;
    int64 daysSinceLastFeeSettlementSigned = timeSinceLastFeeSettlement / ONE_DAY_NANOS;
    if (daysSinceLastFeeSettlementSigned <= 0) {
      return (0, 0);
    }

    daysSinceLastFeeSettlement = uint64(daysSinceLastFeeSettlementSigned);

    BI memory managementFeeIncFactorBI = _calculateManagementFeeIncreaseFactor(
      vaultInfo.managementFeeCentiBeeps,
      daysSinceLastFeeSettlement
    );

    uint64 qDec = _getBalanceDecimal(vaultSub.quoteCurrency);

    BI memory managementFeeNewLpTokenSupplyBI = BIMath.fromUint64(vaultInfo.totalLpTokenSupply, qDec).mul(
      managementFeeIncFactorBI
    );

    managementFeeInLpToken = managementFeeNewLpTokenSupplyBI.toUint64(qDec);

    return (daysSinceLastFeeSettlement, managementFeeInLpToken);
  }

  function _calculateManagementFeeIncreaseFactor(
    uint32 managementFeeCentiBeeps,
    uint64 daysSinceLastFeeSettlement
  ) internal pure returns (BI memory) {
    BI memory managementFeeAnnualFactorBI = BIMath.fromUint32(managementFeeCentiBeeps, CENTIBEEP_DECIMALS);
    managementFeeAnnualFactorBI = managementFeeAnnualFactorBI.scale(RATE_DECIMALS);
    BI memory managementFeeDailyFactorBI = managementFeeAnnualFactorBI.div(BI(365, 0));
    BI memory managementFeeDailyMultiplierBI = managementFeeDailyFactorBI.add(BIMath.one());
    return managementFeeDailyMultiplierBI.pow(daysSinceLastFeeSettlement).sub(BIMath.one());
  }
}
