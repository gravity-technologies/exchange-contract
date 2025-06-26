pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface IConfig {
  /**
   * @dev Sends a message to L1 containing the latest config version.
   * This function is used to prove that no config updates have occurred
   * since the config operation with the version sent to L1.
   */
  function proveConfig() external;

  /**
   * @notice Initialize config values
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param items Array of config items to initialize
   * @param sig Signature of the transaction
   */
  function initializeConfig(
    int64 timestamp,
    uint64 txID,
    InitializeConfigItem[] calldata items,
    Signature calldata sig
  ) external;

  /**
   * @notice Schedule a config change
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param key Config key
   * @param subKey Config subkey (for 2D configs)
   * @param value New config value
   * @param sig Signature of the transaction
   */
  function scheduleConfig(
    int64 timestamp,
    uint64 txID,
    ConfigID key,
    bytes32 subKey,
    bytes32 value,
    Signature calldata sig
  ) external;

  /**
   * @notice Apply a scheduled config change
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param key Config key
   * @param subKey Config subkey (for 2D configs)
   * @param value New config value
   * @param sig Signature of the transaction
   */
  function setConfig(
    int64 timestamp,
    uint64 txID,
    ConfigID key,
    bytes32 subKey,
    bytes32 value,
    Signature calldata sig
  ) external;
}
