pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface IGetter {
  struct AccountResult {
    address id;
    uint64 multiSigThreshold;
    uint64 adminCount;
    uint64[] subAccounts;
  }
  // Not returned fields since mapping is not supported in return type include:
  // 1. spotBalances
  // 2. recoveryAddresses
  // 3. onboardedWithdrawalAddresses
  // 4. onboardedTransferAccounts
  // 5. signers

  struct SubAccountResult {
    uint64 id;
    uint64 adminCount;
    uint64 signerCount;
    address accountID;
    MarginType marginType;
    Currency quoteCurrency;
    int64 lastAppliedFundingTimestamp;
  }
  // Not returned fields since mapping or stucts with nested mapping is not supported in return type include:// The total amount of base currency that the sub account possesses
  // 1. spotBalances
  // 2. PositionsMap options;
  // 3. PositionsMap futures;
  // 4. PositionsMap perps;
  // 5. mapping(bytes => uint256) positionIndex;
  // 6. signers;

  function getAccountResult(address accID) external view returns (AccountResult memory);

  function isAllAccountExists(address[] calldata accountIDs) external view returns (bool);

  function getAccountFundingWalletBalance(address accID, Currency currency) external view returns (int64);

  function isRecoveryAddress(address id, address signer, address recoveryAddress) external view returns (bool);

  function isOnboardedWithdrawalAddress(address id, address withdrawalAddress) external view returns (bool);

  function getAccountOnboardedTransferAccount(address accID, address transferAccount) external view returns (bool);

  function getSignerPermission(address id, address signer) external view returns (uint64);

  function getSessionValue(address sessionKey) external view returns (address, int64);

  function getConfig2D(ConfigID id, bytes32 subKey) external view returns (bytes32);

  function config1DIsSet(ConfigID id) external view returns (bool);

  function config2DIsSet(ConfigID id) external view returns (bool);

  function getConfig1D(ConfigID id) external view returns (bytes32);

  function getConfigSchedule(ConfigID id, bytes32 subKey) external view returns (int64);

  function isConfigScheduleAbsent(ConfigID id, bytes32 subKey) external view returns (bool);

  function getSubAccountResult(uint64 id) external view returns (SubAccountResult memory);

  function getSubAccSignerPermission(uint64 id, address signer) external view returns (uint64);

  function getFundingIndex(bytes32 assetID) external view returns (int64);

  function getFundingTime() external view returns (int64);

  function getMarkPrice(bytes32 assetID) external view returns (uint64, bool);

  function getSettlementPrice(bytes32 assetID) external view returns (uint64, bool);

  function getInterestRate(bytes32 assetID) external view returns (int32);

  function getSubAccountValue(uint64 subAccountID) external view returns (int64);

  function getSubAccountPosition(
    uint64 subAccountID,
    bytes32 assetID
  ) external view returns (bool found, int64 balance, int64 lastAppliedFundingIndex, int64 marginBalance);

  function getSubAccountPositionCount(uint64 subAccountID) external view returns (uint);

  function getSubAccountFuturesWalletBalance(uint64 subAccountID, Currency currency) external view returns (int64);

  function getSubAccountSpotWalletBalance(uint64 subAccountID, Currency currency) external view returns (int64);

  function getSubAccountMode(uint64 subAccountID) external view returns (SubAccountMode);

  function getSimpleCrossMaintenanceMarginTiers(bytes32 kuq) external view returns (MarginTier[] memory);

  function getSimpleCrossMaintenanceMarginTimelockEndTime(bytes32 kuq) external view returns (int64);

  function getSubAccountMaintenanceMargin(uint64 subAccountID) external view returns (uint64);

  /// @notice Returns true when the oldest queued withdrawal has missed its deadline at current state timestamp.
  function hasOverdueWithdrawalRequest() external view returns (bool);

  /// @notice Returns true when the oldest queued withdrawal has missed its deadline at `timestampNs`.
  /// @dev `timestampNs` is expected to follow exchange sequencing timestamp units (nanoseconds).
  function hasOverdueWithdrawalRequestAt(int64 timestampNs) external view returns (bool);

  /// @notice Returns queue index bounds where valid entries exist in [head, tail).
  /// @dev `head == tail` means the pending-withdrawal queue is empty.
  /// @return head Queue head index (inclusive).
  /// @return tail Queue tail index (exclusive).
  function getPendingWithdrawalQueueBounds() external view returns (uint64 head, uint64 tail);

  /// @notice Returns up to `limit` queued withdrawal requests starting at `start`.
  /// @dev Reads are clipped to current [head, tail) bounds. If `start` is before `head`, it is treated as `head`.
  /// @param start Requested first queue index.
  /// @param limit Maximum number of requests to return.
  /// @return requests Contiguous queue entries in [start, min(start + limit, tail)).
  function getPendingWithdrawalRequests(
    uint64 start,
    uint64 limit
  ) external view returns (PendingWithdrawalRequest[] memory requests);

  function getTimestamp() external view returns (int64);

  function getExchangeCurrencyBalance(Currency currency) external view returns (int64);

  function getInsuranceFundLoss(Currency currency) external view returns (int64);

  function getTotalClientEquity(Currency currency) external view returns (int64);

  // Vault related getters
  function isVault(uint64 subAccountID) external view returns (bool);

  function getVaultStatus(uint64 vaultID) external view returns (VaultStatus);

  function getVaultFees(
    uint64 vaultID
  )
    external
    view
    returns (uint32 managementFeeCentiBeeps, uint32 performanceFeeCentiBeeps, uint32 marketingFeeCentiBeeps);

  function getVaultTotalLpTokenSupply(uint64 vaultID) external view returns (uint64);

  function getVaultLpInfo(
    uint64 vaultID,
    address lpAccountID
  ) external view returns (uint64 lpTokenBalance, uint64 usdNotionalInvested);

  function isUnderDeriskMargin(uint64 subAccountID, bool underDeriskMargin) external view returns (bool);

  function getCurrencyDecimals(uint16 id) external view returns (uint16);

  function vaultIsCrossExchange(uint64 vaultID) external view returns (bool);

  function getVaultManagerAttestedSharePrice(uint64 vaultID) external view returns (uint64);

  function getAuthorizedBuilderConfig(
    address mainAccountID,
    address builderAccountID
  ) external view returns (uint64, uint64);

  function getSubAccountPositionMarginConfig(
    uint64 subAccountID,
    bytes32 assetID
  ) external view returns (PositionMarginType, int32);
}
