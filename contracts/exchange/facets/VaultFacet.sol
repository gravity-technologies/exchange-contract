pragma solidity ^0.8.20;

import "../api/SubAccountContract.sol";
import "../api/TransferContract.sol";
import "../api/signature/generated/VaultSig.sol";
import "../interfaces/IVault.sol";

contract VaultFacet is IVault, SubAccountContract, TransferContract {
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
    Currency initialInvestmentCurrency,
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
      initialInvestmentCurrency,
      initialInvestmentNumTokens,
      sig.nonce,
      sig.expiration
    );
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    require(quoteCurrency == Currency.USDT, "only USDT vault is supported");
    require(initialInvestmentCurrency == quoteCurrency, "only investment in quote currency is supported");

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

    _validateAndSetVaultParams(
      vaultSub.vaultInfo,
      managementFeeCentiBeeps,
      performanceFeeCentiBeeps,
      marketingFeeCentiBeeps
    );

    vaultSub.vaultInfo.lastFeeSettlementTimestamp = timestamp;

    int64 initialInvestmentSigned = int64(initialInvestmentNumTokens);
    require(initialInvestmentSigned > 0, "initial investment must be positive");

    Account storage managerAcc = _requireAccount(managerAccountID);

    _investAndMintLpToken(vaultSub, managerAcc, initialInvestmentCurrency, initialInvestmentNumTokens);
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

    require(vaultSub.vaultInfo.status == VaultStatus.ACTIVE, "only active vault can be updated");

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
    uint32 newManagementFeeCentiBeeps,
    uint32 newPerformanceFeeCentiBeeps,
    uint32 newMarketingFeeCentiBeeps
  ) internal {
    require(
      newManagementFeeCentiBeeps <= vaultInfo.managementFeeCentiBeeps,
      "vault management fee cannot be increased"
    );
    require(
      newPerformanceFeeCentiBeeps <= vaultInfo.performanceFeeCentiBeeps,
      "vault performance fee cannot be increased"
    );
    require(newMarketingFeeCentiBeeps <= vaultInfo.marketingFeeCentiBeeps, "vault marketing fee cannot be increased");

    _validateAndSetVaultParams(
      vaultInfo,
      newManagementFeeCentiBeeps,
      newPerformanceFeeCentiBeeps,
      newMarketingFeeCentiBeeps
    );
  }

  function _validateAndSetVaultParams(
    VaultInfo storage vaultInfo,
    uint32 managementFeeCentiBeeps,
    uint32 performanceFeeCentiBeeps,
    uint32 marketingFeeCentiBeeps
  ) internal {
    require(managementFeeCentiBeeps <= 4_0000, "management fee must be <= 4%");
    require(performanceFeeCentiBeeps <= 40_0000, "performance fee must be <= 40%");
    require(marketingFeeCentiBeeps <= 80_0000, "marketing fee must be <= 80%");

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
    _requireAccountPermission(account, sig.signer, AccountPermVaultInvestor);

    SubAccount storage vaultSub = _requireVaultSubAccount(vaultID);
    require(vaultSub.vaultInfo.status == VaultStatus.ACTIVE, "only active vault can accept investment");
    require(tokenCurrency == vaultSub.quoteCurrency, "non-quote currency vault deposit");

    // ---------- Signature Verification -----------
    bytes32 hash = hashVaultInvest(vaultID, accountID, tokenCurrency, numTokens, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    _investAndMintLpToken(vaultSub, account, tokenCurrency, numTokens);
  }

  function _investAndMintLpToken(
    SubAccount storage vaultSub,
    Account storage account,
    Currency currency,
    uint64 numTokens
  ) internal {
    require(currency == Currency.USDT, "Only USDT vault investment is supported");

    int64 numTokensSigned = int64(numTokens);
    require(numTokensSigned > 0, "investment amount must be positive");

    (uint64 lpTokensToMint, uint64 amountInUsd) = _calculateLpTokensToMintOnInvest(vaultSub, currency, numTokens);
    require(lpTokensToMint > 0, "no LP tokens minted");

    _doTransferMainToSub(account, vaultSub, currency, numTokensSigned);
    _mintLpTokens(vaultSub, account.id, lpTokensToMint, amountInUsd);
  }

  function _calculateLpTokensToMintOnInvest(
    SubAccount storage vaultSub,
    Currency currency,
    uint64 numTokens
  ) internal returns (uint64, uint64) {
    BI memory numTokensBI = BIMath.fromUint64(numTokens, _getBalanceDecimal(currency));

    uint64 lpDec = _getLpTokenDecimal();
    BI memory amountInUsdBI = _convertCurrency(numTokensBI, currency, Currency.USD);
    uint64 amountInUsd = amountInUsdBI.toUint64(lpDec);

    if (vaultSub.vaultInfo.totalLpTokenSupply == 0) {
      return (amountInUsd, amountInUsd);
    }

    BI memory vaultEquityBeforeInUsd = _getSubAccountValueInUSD(vaultSub);
    require(vaultEquityBeforeInUsd.isPositive(), "vault equity is not positive");

    BI memory totalLpTokenSupplyBI = BIMath.fromUint64(vaultSub.vaultInfo.totalLpTokenSupply, lpDec);
    BI memory lpTokensToMintBI = amountInUsdBI.mul(totalLpTokenSupplyBI).div(vaultEquityBeforeInUsd);

    return (lpTokensToMintBI.toUint64(lpDec), amountInUsd);
  }

  function _mintLpTokens(
    SubAccount storage vaultSub,
    address accountID,
    uint64 lpTokenToMint,
    uint64 usdNotionalInvested
  ) internal {
    VaultInfo storage vaultInfo = vaultSub.vaultInfo;
    vaultInfo.totalLpTokenSupply += lpTokenToMint;

    VaultLpInfo storage lpInfo = vaultInfo.lpInfos[accountID];
    lpInfo.usdNotionalInvested += usdNotionalInvested;
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

    VaultLpInfo storage lpInfo = vaultSub.vaultInfo.lpInfos[accountID];
    uint64 costOfLpTokenBurntInUsd = _calculateCostOfLpTokenBurntInUsd(lpInfo, numLpTokens);

    _burnLpTokens(vaultSub, accountID, numLpTokens, costOfLpTokenBurntInUsd);
  }

  function vaultRedeem(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    Currency tokenCurrency,
    uint64 numLpTokens,
    address accountID,
    uint64 marketingFeeChargedInLpToken,
    Signature calldata sig
  ) external nonReentrant onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    SubAccount storage vaultSub = _requireVaultSubAccount(vaultID);
    require(tokenCurrency == vaultSub.quoteCurrency, "non-quote currency vault redemption");

    Account storage account = _requireAccount(accountID);

    // permission and signature check is skipped for closed vault
    // this is because the closed vaults does not have any positions and cannot trade any more
    // so GRVT can redeem closed vaults for users
    if (vaultSub.vaultInfo.status != VaultStatus.CLOSED) {
      _requireAccountPermission(account, sig.signer, AccountPermVaultInvestor);

      // ---------- Signature Verification -----------
      bytes32 hash = hashVaultRedeem(vaultID, tokenCurrency, numLpTokens, accountID, sig.nonce, sig.expiration);
      _preventReplay(hash, sig);
      // ------- End of Signature Verification -------
    }

    uint64 redeemedInUsd = _calculateUsdRedeemed(vaultSub, numLpTokens);

    VaultLpInfo storage lpInfo = vaultSub.vaultInfo.lpInfos[accountID];
    uint64 costOfLpTokenBurntInUsd = _calculateCostOfLpTokenBurntInUsd(lpInfo, numLpTokens);

    (uint64 performanceFeeInUsd, uint64 performanceFeeInLpToken) = _calculateRedemptionPerformanceFee(
      vaultSub,
      accountID,
      redeemedInUsd,
      costOfLpTokenBurntInUsd
    );

    if (performanceFeeInLpToken > 0) {
      _mintLpTokenForFee(vaultSub, performanceFeeInLpToken, marketingFeeChargedInLpToken);
    }

    uint64 redeemedInUsdAfterFee = redeemedInUsd - performanceFeeInUsd;

    uint64 lpDec = _getLpTokenDecimal();
    BI memory redeemedInUsdAfterFeeBI = BIMath.fromUint64(redeemedInUsdAfterFee, lpDec);

    int64 redeemedInQuoteAfterFee = _convertCurrency(redeemedInUsdAfterFeeBI, Currency.USD, tokenCurrency).toInt64(
      _getBalanceDecimal(tokenCurrency)
    );

    require(redeemedInQuoteAfterFee > 0, "redeemed in quote after fee is not positive");

    _burnLpTokens(vaultSub, accountID, numLpTokens, costOfLpTokenBurntInUsd);
    _doTransferSubToMain(vaultSub, account, tokenCurrency, redeemedInQuoteAfterFee);
  }

  function _calculateUsdRedeemed(SubAccount storage vaultSub, uint64 numLpTokens) internal returns (uint64) {
    BI memory vaultEquityInUsd = _getSubAccountValueInUSD(vaultSub);
    require(vaultEquityInUsd.isPositive(), "vault equity is not positive");

    uint64 lpDec = _getLpTokenDecimal();
    BI memory totalLpTokenSupplyBI = BIMath.fromUint64(vaultSub.vaultInfo.totalLpTokenSupply, lpDec);

    BI memory numLpTokensBI = BIMath.fromUint64(numLpTokens, lpDec);
    BI memory usdRedeemedBI = numLpTokensBI.mul(vaultEquityInUsd).div(totalLpTokenSupplyBI);

    return usdRedeemedBI.toUint64(lpDec);
  }

  function _calculateRedemptionPerformanceFee(
    SubAccount storage vaultSub,
    address accountID,
    uint64 redeemedInUsd,
    uint64 costOfLpTokenBurntInUsd
  ) internal returns (uint64, uint64) {
    uint64 lpDec = _getLpTokenDecimal();
    if (vaultSub.accountID == accountID || costOfLpTokenBurntInUsd >= redeemedInUsd) {
      return (0, 0);
    }

    uint64 profitInUsd = redeemedInUsd - costOfLpTokenBurntInUsd;
    BI memory profitInUsdBI = BIMath.fromUint64(profitInUsd, lpDec);
    BI memory performanceFeeRateBI = BIMath.fromUint32(vaultSub.vaultInfo.performanceFeeCentiBeeps, CENTIBEEP_DECIMALS);
    BI memory performanceFeeBI = profitInUsdBI.mul(performanceFeeRateBI);
    uint64 performanceFeeInUsd = performanceFeeBI.toUint64(lpDec);

    (uint64 performanceFeeInLpToken, ) = _calculateLpTokensToMintOnInvest(vaultSub, Currency.USD, performanceFeeInUsd);

    if (performanceFeeInLpToken > 0) {
      return (performanceFeeInUsd, performanceFeeInLpToken);
    }

    return (0, 0);
  }

  function _burnLpTokens(
    SubAccount storage vaultSub,
    address accountID,
    uint64 lpTokenToBurn,
    uint64 costOfLpTokenBurntInUsd
  ) internal {
    VaultInfo storage vaultInfo = vaultSub.vaultInfo;

    VaultLpInfo storage lpInfo = vaultInfo.lpInfos[accountID];
    require(lpInfo.lpTokenBalance >= lpTokenToBurn, "insufficient LP tokens");

    costOfLpTokenBurntInUsd = _calculateCostOfLpTokenBurntInUsd(lpInfo, lpTokenToBurn);

    vaultInfo.totalLpTokenSupply -= lpTokenToBurn;

    lpInfo.usdNotionalInvested -= costOfLpTokenBurntInUsd;
    lpInfo.lpTokenBalance -= lpTokenToBurn;
  }

  function _calculateCostOfLpTokenBurntInUsd(
    VaultLpInfo storage lpInfo,
    uint64 lpTokenToBurn
  ) internal returns (uint64 costOfLpTokenBurntInUsd) {
    uint64 lpDec = _getLpTokenDecimal();
    uint64 usdDec = _getBalanceDecimal(Currency.USD);
    BI memory usdNotionalInvestedBI = BIMath.fromUint64(lpInfo.usdNotionalInvested, usdDec);
    BI memory balanceBI = BIMath.fromUint64(lpInfo.lpTokenBalance, lpDec);
    BI memory burnBI = BIMath.fromUint64(lpTokenToBurn, lpDec);

    return usdNotionalInvestedBI.mul(burnBI).div(balanceBI).toUint64(usdDec);
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
    uint64 lpDec = _getLpTokenDecimal();

    BI memory lpTokenToMintBI = BIMath.fromUint64(lpTokenToMint, lpDec);
    BI memory marketingFeeCapRatioBI = BIMath.fromUint32(vaultSub.vaultInfo.marketingFeeCentiBeeps, CENTIBEEP_DECIMALS);
    BI memory marketingFeeCapBI = lpTokenToMintBI.mul(marketingFeeCapRatioBI);
    uint64 marketingFeeCap = marketingFeeCapBI.toUint64(lpDec);

    require(marketingFeeChargedInLpToken <= marketingFeeCap, "marketing fee charged is more than cap");

    (SubAccount storage feeSubAcc, bool isFeeSubAccIdSet) = _getAdminFeeSubAccount();

    uint64 managerPayment = lpTokenToMint;
    if (isFeeSubAccIdSet && marketingFeeChargedInLpToken > 0) {
      managerPayment -= marketingFeeChargedInLpToken;
      _mintLpTokens(vaultSub, feeSubAcc.accountID, marketingFeeChargedInLpToken, 0);
    }

    _mintLpTokens(vaultSub, vaultSub.accountID, managerPayment, 0);
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

    uint64 lpDec = _getLpTokenDecimal();

    BI memory managementFeeNewLpTokenSupplyBI = BIMath.fromUint64(vaultInfo.totalLpTokenSupply, lpDec).mul(
      managementFeeIncFactorBI
    );

    managementFeeInLpToken = managementFeeNewLpTokenSupplyBI.toUint64(lpDec);

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

  function _getLpTokenDecimal() internal view returns (uint64) {
    // lp token has the same decimal as USD
    return _getBalanceDecimal(Currency.USD);
  }
}
