pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface IVault {
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
    bool isCrossExchange,
    Signature calldata sig
  ) external;

  function vaultUpdate(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    uint32 managementFeeCentiBeeps,
    uint32 performanceFeeCentiBeeps,
    uint32 marketingFeeCentiBeeps,
    Signature calldata sig
  ) external;

  function vaultDelist(int64 timestamp, uint64 txID, uint64 vaultID) external;

  function vaultClose(int64 timestamp, uint64 txID, uint64 vaultID) external;

  function vaultInvest(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    address accountID,
    Currency tokenCurrency,
    uint64 numTokens,
    Signature calldata sig
  ) external;

  function vaultBurnLpToken(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    uint64 numLpTokens,
    address accountID,
    Signature calldata sig
  ) external;

  function vaultRedeem(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    Currency tokenCurrency,
    uint64 numLpTokens,
    address accountID,
    uint64 marketingFeeChargedInLpToken,
    Signature calldata sig
  ) external;

  function vaultManagementFeeTick(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    uint64 marketingFeeChargedInLpToken
  ) external;

  function vaultCrossExchangeUpdate(
    int64 timestamp,
    uint64 txID,
    uint64 vaultID,
    uint64 totalEquity,
    uint64 numLpTokens,
    uint64 sharePrice,
    int64 lastUpdateTimestamp,
    Signature calldata sig
  ) external;
}
