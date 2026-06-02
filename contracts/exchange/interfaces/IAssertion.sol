pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface IAssertion {
  function assertLastTxID(uint64 expectedLastTxID) external view;

  // Assertions for Account Contract
  function assertCreateAccount(address accountID, address signer) external view;

  function assertCreateAccountWithSubAccount(
    address accountID,
    uint64 subAccountID,
    MarginType marginType,
    uint8 quoteCurrency,
    int64 lastAppliedFundingTimestamp
  ) external view;

  function assertCreateAccountWithSubAccountV2(
    address accountID,
    uint64 subAccountID,
    MarginType marginType,
    uint8 quoteCurrency,
    int64 lastAppliedFundingTimestamp,
    SubAccountMode subAccountMode
  ) external view;

  function assertSetAccountMultiSigThreshold(address accountID, uint8 expectedThreshold) external view;

  function assertAddAccountSigner(
    address accountID,
    address signer,
    uint64 expectedPermissions,
    uint adminCount
  ) external view;

  function assertRemoveAccountSigner(address accountID, address signer, uint adminCount) external view;

  function assertAddWithdrawalAddress(address accountID, address withdrawalAddress) external view;

  function assertRemoveWithdrawalAddress(address accountID, address withdrawalAddress) external view;

  function assertAddTransferAccount(address accountID, address transferAccountID) external view;

  function assertRemoveTransferAccount(address accountID, address transferAccountID) external view;

  // Assertions for SubAccount Contract
  function assertCreateSubAccount(
    uint64 subAccountID,
    address accountID,
    uint8 quoteCurrency,
    MarginType marginType,
    int64 lastAppliedFundingTimestamp
  ) external view;

  function assertCreateSubAccountV2(
    uint64 subAccountID,
    address accountID,
    uint8 quoteCurrency,
    MarginType marginType,
    int64 lastAppliedFundingTimestamp,
    SubAccountMode subAccountMode
  ) external view;

  function assertSetSubAccountMarginType(uint64 subAccountID, MarginType expectedMarginType) external view;

  function assertAddSubAccountSigner(uint64 subAccountID, address signer, uint64 expectedPermissions) external view;

  function assertRemoveSubAccountSigner(uint64 subAccountID, address signer) external view;

  function assertAddSessionKey(address sessionKey, address expectedSigner, int64 expectedExpiry) external view;

  function assertRemoveSessionKey(address sessionKey) external view;

  // Assertions for Oracle Contract
  function assertMarkPriceTick(bytes32[] calldata assetIDs, uint64[] calldata expectedPrices) external view;

  function assertFundingPriceTick(
    bytes32[] calldata assetIDs,
    int64[] calldata expectedFundingIndexes,
    int64 expectedFundingTime
  ) external view;

  // Assertions for Config Contract
  function assertScheduleConfig(ConfigID key, bytes32 subKey, int64 expectedLockEndTime) external view;

  function assertSetConfig(
    ConfigID key,
    bytes32 subKey,
    bytes32 expectedValue,
    address[] calldata bridgingPartners
  ) external view;

  function assertInitializeConfig(
    InitializeConfigItem[] calldata items,
    address[] calldata bridgingPartners
  ) external view;

  // Assertions for Transfer Contract
  function assertDeposit(
    bytes32 txHash,
    address accountID,
    uint8 currency,
    int64 expectedBalance,
    int64 expectedTotalSpotBalance
  ) external view;

  function assertWithdraw(
    address fromAccID,
    uint8 currency,
    int64 expectedBalance,
    uint64 feeSubAccId,
    int64 expectedFeeBalance,
    uint64 insuranceFundSubAccId,
    int64 expectedInsuranceFundBalance,
    int64 expectedTotalSpotBalance,
    SubAccountAssertion[] calldata subAccounts
  ) external view;

  function assertTransfer(
    address fromAccID,
    address toAccID,
    uint64 fromSubID,
    uint64 toSubID,
    int64 expectedFromBalance,
    int64 expectedToBalance,
    uint8 currency,
    SubAccountAssertion[] calldata subAccounts
  ) external view;

  function assertTransferV2(
    address fromAccID,
    address toAccID,
    uint64 fromSubID,
    uint64 toSubID,
    int64 expectedFromBalance,
    int64 expectedToBalance,
    uint8 currency,
    WalletType fromWalletType,
    WalletType toWalletType,
    SubAccountAssertionV2[] calldata subAccounts
  ) external view;

  struct PositionAssertion {
    bytes32 assetID;
    int64 balance;
    int64 fundingIndex;
    int64 marginBalance;
  }
  struct SpotAssertion {
    uint8 currency;
    int64 balance;
  }
  struct SubAccountAssertion {
    uint64 subAccountID;
    int64 fundingTimestamp;
    PositionAssertion[] positions;
    SpotAssertion[] spots;
    int64 lastDeriskTimestamp;
  }

  struct SubAccountAssertionV2 {
    uint64 subAccountID;
    int64 fundingTimestamp;
    PositionAssertion[] positions;
    SpotAssertion[] futuresWalletSpots;
    SpotAssertion[] spotWalletSpots;
    int64 lastDeriskTimestamp;
  }

  struct AccountAssertion {
    address accountID;
    SpotAssertion[] spots;
  }

  struct TradeAssertion {
    SubAccountAssertion[] subAccounts;
    AccountAssertion[] accounts;
  }

  struct TradeAssertionV2 {
    SubAccountAssertionV2[] subAccounts;
    AccountAssertion[] accounts;
  }

  // Assertion for Trade Contract
  function assertTradeDeriv(TradeAssertion calldata tradeAssertion) external view;

  function assertTradeV2(TradeAssertionV2 calldata tradeAssertion) external view;

  // Assertions for WalletRecovery Contract
  function assertAddRecoveryAddress(
    address accountID,
    address signer,
    address[] calldata recoveryAddresses
  ) external view;

  function assertRemoveRecoveryAddress(
    address accountID,
    address signer,
    address[] calldata recoveryAddresses
  ) external view;

  function assertRecoverAddress(
    address accID,
    address oldSigner,
    address newSigner,
    uint64 mainAccountPermission,
    uint64[] calldata subAccountIDs,
    uint64[] calldata subAccountPermissions,
    address[] calldata recoveryAddresses
  ) external view;

  struct MarginTierAssertion {
    uint64 bracketStart;
    uint32 rate;
  }

  // Assertions for MarginConfig Contract
  function assertSetSimpleCrossMMTiers(bytes32 kud, MarginTierAssertion[] calldata expectedTiers) external view;

  function assertScheduleSimpleCrossMMTiers(bytes32 kud, int64 expectedLockEndTime) external view;

  // Vault assertion structs
  struct VaultLpAssertion {
    address accountID;
    uint64 lpTokenBalance;
    uint64 usdNotionalInvested;
    SpotAssertion[] spots;
  }

  struct VaultCreateParamsAssertion {
    uint32 managementFeeCentiBeeps;
    uint32 performanceFeeCentiBeeps;
    uint32 marketingFeeCentiBeeps;
    bool isCrossExchange;
    uint64 managerAttestedSharePrice;
  }

  struct VaultUpdateParamsAssertion {
    uint32 managementFeeCentiBeeps;
    uint32 performanceFeeCentiBeeps;
    uint32 marketingFeeCentiBeeps;
  }

  function assertVaultCreate(
    uint64 vaultID,
    address managerAccountID,
    uint8 quoteCurrency,
    MarginType marginType,
    int64 lastAppliedFundingTimestamp,
    VaultCreateParamsAssertion calldata vaultParamsAssertion,
    int64 lastFeeSettlementTimestamp,
    uint64 totalLpTokenSupply,
    uint8 initialInvestmentCurrency,
    int64 vaultInitialSpotBalance,
    VaultLpAssertion calldata managerAssertion,
    SubAccountAssertion calldata vaultSubAssertion
  ) external view;

  function assertVaultUpdate(uint64 vaultID, VaultUpdateParamsAssertion calldata vaultParamsAssertion) external view;

  function assertVaultDelist(uint64 vaultID) external view;

  function assertVaultClose(uint64 vaultID) external view;

  function assertVaultInvest(
    uint64 vaultID,
    uint64 expectedTotalLpTokenSupply,
    uint8 investmentCurrency,
    int64 expectedVaultSpotBalance,
    VaultLpAssertion calldata investorAssertion,
    SubAccountAssertion calldata vaultSubAssertion
  ) external view;

  function assertVaultBurnLpToken(
    uint64 vaultID,
    uint64 expectedTotalLpTokenSupply,
    VaultLpAssertion calldata lpAssertion
  ) external view;

  function assertVaultRedeem(
    uint64 vaultID,
    uint64 expectedTotalLpTokenSupply,
    uint8 currencyRedeemed,
    int64 expectedVaultSpotBalance,
    VaultLpAssertion calldata redeemingLpAssertion,
    VaultLpAssertion calldata managerAssertion,
    VaultLpAssertion calldata feeAccountAssertion
  ) external view;

  function assertVaultManagementFeeTick(
    uint64 vaultID,
    int64 expectedLastFeeSettlementTimestamp,
    uint64 expectedTotalLpTokenSupply,
    VaultLpAssertion calldata managerAssertion,
    VaultLpAssertion calldata feeAccountAssertion
  ) external view;

  function assertVaultCrossExchangeUpdate(uint64 vaultID, uint64 expectedManagerAttestedSharePrice) external view;

  function assertSetDeriskToMaintenanceMarginRatio(
    uint64 subAccountID,
    uint32 expectedDeriskToMaintenanceMarginRatio
  ) external view;

  function assertAddCurrency(uint16 id, uint16 balanceDecimals) external view;

  function assertUpdateFundingInfo(AssetFundingInfo[] calldata expectedFundingInfos) external view;

  function assertSetSubAccountPositionMarginConfig(
    uint64 subID,
    bytes32 asset,
    PositionMarginType marginType,
    int32 leverage
  ) external view;

  function assertAddIsolatedPositionMargin(
    uint64 subAccountID,
    bytes32 assetID,
    int64 marginBalance,
    int64 subAccountSpotBalance
  ) external view;

  function assertAuthorizeBuilder(
    address mainAccountID,
    address builderAccountID,
    uint32 maxFutureFeeRate,
    uint32 maxSpotFeeRate
  ) external view;

  function assertAddAccountSignerWithBuilder(
    address accountID,
    address signer,
    uint64 expectedPermissions,
    address builderAccountID,
    uint32 maxFutureFeeRate,
    uint32 maxSpotFeeRate,
    uint256 adminCount
  ) external view;

  // ── Staking ────────────────────────────────────────────────────────────────
  function assertStake(
    address accountID,
    uint8 currency,
    int64 expectedFundingBalance,
    int64 expectedLockedAmount,
    int64 expectedLockEndTime,
    int64 expectedCooldownEndTime
  ) external view;

  function assertInitiateUnstake(
    address accountID,
    int64 expectedLockedAmount,
    int64 expectedLockEndTime,
    int64 expectedCooldownEndTime
  ) external view;

  function assertCancelUnstake(
    address accountID,
    int64 expectedLockedAmount,
    int64 expectedLockEndTime,
    int64 expectedCooldownEndTime
  ) external view;

  function assertWithdrawStake(
    address accountID,
    uint8 currency,
    int64 expectedFundingBalance,
    int64 expectedLockedAmount,
    int64 expectedLockEndTime,
    int64 expectedCooldownEndTime
  ) external view;
  // ── End of Staking ────────────────────────────────────────────────────────────────
}
