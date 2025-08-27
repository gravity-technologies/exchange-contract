pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _VAULT_CREATE_H = keccak256(
  "VaultCreate(uint64 vaultID,address managerAccountID,uint8 quoteCurrency,uint8 marginType,uint32 managementFeeCentiBeeps,uint32 performanceFeeCentiBeeps,uint32 marketingFeeCentiBeeps,uint8 initialInvestmentCurrency,uint64 initialInvestmentNumTokens,bool isCrossExchange,uint32 nonce,int64 expiration)"
);

function hashVaultCreate(
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
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(
        _VAULT_CREATE_H,
        vaultID,
        managerAccountID,
        uint8(quoteCurrency),
        uint8(marginType),
        managementFeeCentiBeeps,
        performanceFeeCentiBeeps,
        marketingFeeCentiBeeps,
        uint8(initialInvestmentCurrency),
        initialInvestmentNumTokens,
        isCrossExchange,
        nonce,
        expiration
      )
    );
}

bytes32 constant _VAULT_UPDATE_H = keccak256(
  "VaultUpdate(uint64 vaultID,uint32 managementFeeCentiBeeps,uint32 performanceFeeCentiBeeps,uint32 marketingFeeCentiBeeps,uint32 nonce,int64 expiration)"
);

function hashVaultUpdate(
  uint64 vaultID,
  uint32 managementFeeCentiBeeps,
  uint32 performanceFeeCentiBeeps,
  uint32 marketingFeeCentiBeeps,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(
        _VAULT_UPDATE_H,
        vaultID,
        managementFeeCentiBeeps,
        performanceFeeCentiBeeps,
        marketingFeeCentiBeeps,
        nonce,
        expiration
      )
    );
}

bytes32 constant _VAULT_INVEST_H = keccak256(
  "VaultInvest(uint64 vaultID,address accountID,uint8 tokenCurrency,uint64 numTokens,uint32 nonce,int64 expiration)"
);

function hashVaultInvest(
  uint64 vaultID,
  address accountID,
  Currency tokenCurrency,
  uint64 numTokens,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_VAULT_INVEST_H, vaultID, accountID, uint8(tokenCurrency), numTokens, nonce, expiration));
}

bytes32 constant _VAULT_BURN_LP_TOKEN_H = keccak256(
  "VaultBurnLpToken(uint64 vaultID,uint64 numLpTokens,address accountID,uint32 nonce,int64 expiration)"
);

function hashVaultBurnLpToken(
  uint64 vaultID,
  uint64 numLpTokens,
  address accountID,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_VAULT_BURN_LP_TOKEN_H, vaultID, numLpTokens, accountID, nonce, expiration));
}

bytes32 constant _VAULT_REDEEM_H = keccak256(
  "VaultRedeem(uint64 vaultID,uint8 tokenCurrency,uint64 numLpTokens,address accountID,uint32 nonce,int64 expiration)"
);

function hashVaultRedeem(
  uint64 vaultID,
  Currency tokenCurrency,
  uint64 numLpTokens,
  address accountID,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(abi.encode(_VAULT_REDEEM_H, vaultID, uint8(tokenCurrency), numLpTokens, accountID, nonce, expiration));
}

bytes32 constant _VAULT_CROSS_EXCHANGE_UPDATE_H = keccak256(
  "VaultCrossExchangeUpdate(uint64 vaultID,uint64 totalEquity,uint64 numLpTokens,uint64 sharePrice,int64 lastUpdateTimestamp,uint32 nonce,int64 expiration)"
);

function hashVaultCrossExchangeUpdate(
  uint64 vaultID,
  uint64 totalEquity,
  uint64 numLpTokens,
  uint64 sharePrice,
  int64 lastUpdateTimestamp,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(
        _VAULT_CROSS_EXCHANGE_UPDATE_H,
        vaultID,
        totalEquity,
        numLpTokens,
        sharePrice,
        lastUpdateTimestamp,
        nonce,
        expiration
      )
    );
}
