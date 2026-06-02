// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _STAKE_H = keccak256(
  "Stake(address accountID,uint8 tokenCurrency,uint64 numTokens,int64 newLockEndTime,uint32 nonce,int64 expiration)"
);

function hashStake(
  address accountID,
  uint8 currency,
  uint64 numTokens,
  int64 newLockEndTime,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(_STAKE_H, accountID, currency, numTokens, newLockEndTime, nonce, expiration)
    );
}

bytes32 constant _INITIATE_UNSTAKE_H = keccak256(
  "InitiateUnstake(address accountID,uint8 tokenCurrency,int64 cooldownEndTime,uint32 nonce,int64 expiration)"
);

function hashInitiateUnstake(
  address accountID,
  uint8 currency,
  int64 cooldownEndTime,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_INITIATE_UNSTAKE_H, accountID, currency, cooldownEndTime, nonce, expiration));
}

bytes32 constant _CANCEL_UNSTAKE_H = keccak256(
  "CancelUnstake(address accountID,uint8 tokenCurrency,uint32 nonce,int64 expiration)"
);

function hashCancelUnstake(
  address accountID,
  uint8 currency,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_CANCEL_UNSTAKE_H, accountID, currency, nonce, expiration));
}

bytes32 constant _WITHDRAW_STAKE_H = keccak256(
  "WithdrawStake(address accountID,uint8 tokenCurrency,uint32 nonce,int64 expiration)"
);

function hashWithdrawStake(
  address accountID,
  uint8 currency,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_WITHDRAW_STAKE_H, accountID, currency, nonce, expiration));
}
