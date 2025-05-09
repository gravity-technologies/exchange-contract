pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface IMarginConfig {
  /**
   * @notice Schedule a change to simple cross maintenance margin tiers
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param kud The asset KUD
   * @param tiers The margin tiers to schedule
   * @param sig Signature of the transaction
   */
  function scheduleSimpleCrossMaintenanceMarginTiers(
    int64 timestamp,
    uint64 txID,
    bytes32 kud,
    MarginTier[] calldata tiers,
    Signature calldata sig
  ) external;

  /**
   * @notice Apply a scheduled change to simple cross maintenance margin tiers
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param kud The asset KUD
   * @param tiers The margin tiers to set
   * @param sig Signature of the transaction
   */
  function setSimpleCrossMaintenanceMarginTiers(
    int64 timestamp,
    uint64 txID,
    bytes32 kud,
    MarginTier[] calldata tiers,
    Signature calldata sig
  ) external;
}
