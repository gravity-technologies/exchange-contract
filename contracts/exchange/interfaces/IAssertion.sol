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
    Currency quoteCurrency,
    int64 lastAppliedFundingTimestamp
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
    Currency quoteCurrency,
    MarginType marginType,
    int64 lastAppliedFundingTimestamp
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
    Currency currency,
    int64 expectedBalance,
    int64 expectedTotalSpotBalance
  ) external view;

  function assertWithdraw(
    address fromAccID,
    Currency currency,
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
    Currency currency,
    SubAccountAssertion[] calldata subAccounts
  ) external view;

  struct PositionAssertion {
    bytes32 assetID;
    int64 balance;
    int64 fundingIndex;
  }
  struct SpotAssertion {
    Currency currency;
    int64 balance;
  }
  struct SubAccountAssertion {
    uint64 subAccountID;
    int64 fundingTimestamp;
    PositionAssertion[] positions;
    SpotAssertion[] spots;
    int64 lastDeriskTimestamp;
  }
  struct TradeAssertion {
    SubAccountAssertion[] subAccounts;
  }

  // Assertion for Trade Contract
  function assertTradeDeriv(TradeAssertion calldata tradeAssertion) external view;

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

  function assertVaultCreate(
    uint64 vaultID,
    address managerAccountID,
    Currency quoteCurrency,
    MarginType marginType,
    int64 lastAppliedFundingTimestamp,
    uint32 managementFeeCentiBeeps,
    uint32 performanceFeeCentiBeeps,
    uint32 marketingFeeCentiBeeps,
    int64 lastFeeSettlementTimestamp,
    uint64 totalLpTokenSupply,
    Currency initialInvestmentCurrency,
    int64 vaultInitialSpotBalance,
    VaultLpAssertion calldata managerAssertion,
    SubAccountAssertion calldata vaultSubAssertion
  ) external view;

  function assertVaultUpdate(
    uint64 vaultID,
    uint32 managementFeeCentiBeeps,
    uint32 performanceFeeCentiBeeps,
    uint32 marketingFeeCentiBeeps
  ) external view;

  function assertVaultDelist(uint64 vaultID) external view;

  function assertVaultClose(uint64 vaultID) external view;

  function assertVaultInvest(
    uint64 vaultID,
    uint64 expectedTotalLpTokenSupply,
    Currency investmentCurrency,
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
    Currency currencyRedeemed,
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

  function assertSetDeriskToMaintenanceMarginRatio(
    uint64 subAccountID,
    uint32 expectedDeriskToMaintenanceMarginRatio
  ) external view;
}
