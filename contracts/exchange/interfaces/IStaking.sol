pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface IStaking {
  event Staked(address indexed accountID, uint64 numTokens, int64 lockEndTime, uint64 txID);
  event UnstakeInitiated(address indexed accountID, int64 cooldownEndTime, uint64 txID);
  event UnstakeCancelled(address indexed accountID, uint64 txID);
  event StakeWithdrawn(address indexed accountID, uint64 numTokens, uint64 txID);

  function stake(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint8 currency,
    uint64 numTokens,
    int64 newLockEndTime,
    Signature calldata sig
  ) external;

  function initiateUnstake(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint8 currency,
    int64 cooldownEndTime,
    Signature calldata sig
  ) external;

  function cancelUnstake(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint8 currency,
    Signature calldata sig
  ) external;

  function withdrawStake(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint8 currency,
    Signature calldata sig
  ) external;
}
