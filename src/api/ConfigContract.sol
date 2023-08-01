// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./HelperContract.sol";
import "../DataStructure.sol";
import "./signature/generated/ConfigSig.sol";
import {ConfigID as CfgID, ConfigTimelockRule as Rule} from "../DataStructure.sol";
import "../util/Address.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

// import "hardhat/console.sol";

contract ConfigContract is HelperContract {
  // --------------- Constants ---------------
  uint private constant CENTIBEEP = 1;
  uint private constant BEEP = 100;
  uint private constant PERCENT = 10000;

  // The type of each config, either bool, address, int, uint
  // This is a bitmask representation of the type of each config
  // Each config type is represented by 4 bits
  // To get the type of each config, we shift the _CONFIG_TYPE to the right by 4 * configID and get the last 4 bit
  // ie: type = (_CONFIG_TYPE >> (4 * configID)) & 0xF
  // 19 configs * 4 bits = 76 bits
  // uint256 private constant _CONFIG_TYPE = 0x02040404040404040404040404040404040400;
  uint256 private constant _CONFIG_TYPE = 0x2444444444444444440;

  // ---------------- Events ----------------
  event ConfigScheduledEvent(CfgID indexed configID, bytes32 value);
  event ConfigSetEvent(CfgID indexed configID, bytes32 value);

  /// @notice This function should be called once in the Exchange contract constructor
  function _setConfigTimelock() internal {
    mapping(CfgID => Rule[]) storage timelocks = state.configTimelocks;

    Rule[] storage futInitMargin = timelocks[CfgID.SM_FUTURES_INITIAL_MARGIN];
    // If reducing the margin, the timelock is 0
    futInitMargin.push(Rule(0, 0, 100 * PERCENT));
    // If increasing the margin within 10bps, the timelock is 1 hour
    futInitMargin.push(Rule(1 hours, 10 * BEEP, 0));
    // If increasing the margin within 1%, the timelock is 4 hours
    futInitMargin.push(Rule(4 hours, 1 * PERCENT, 0));
    // If increasing the margin within 10%, the timelock is 1 day
    futInitMargin.push(Rule(1 days, 10 * PERCENT, 0));

    timelocks[CfgID.SM_FUTURES_MAINTENANCE_MARGIN].push(Rule(0, 0, 0));
    timelocks[CfgID.SM_FUTURES_VARIABLE_MARGIN].push(Rule(0, 0, 0));
    timelocks[CfgID.SM_OPTIONS_INITIAL_MARGIN_HIGH].push(Rule(0, 0, 0));
    timelocks[CfgID.SM_OPTIONS_INITIAL_MARGIN_LOW].push(Rule(0, 0, 0));
    timelocks[CfgID.SM_OPTIONS_MAINTENANCE_MARGIN_HIGH].push(Rule(0, 0, 0));
    timelocks[CfgID.SM_OPTIONS_MAINTENANCE_MARGIN_LOW].push(Rule(0, 0, 0));
    timelocks[CfgID.SM_OPTIONS_VARIABLE_MARGIN].push(Rule(0, 0, 0));
    timelocks[CfgID.PM_SPOT_MOVE].push(Rule(0, 0, 0));
    timelocks[CfgID.PM_VOL_MOVE_UP].push(Rule(0, 0, 0));
    timelocks[CfgID.PM_VOL_MOVE_DOWN].push(Rule(0, 0, 0));
    timelocks[CfgID.PM_SHORT_TERM_VEGA_POWER].push(Rule(0, 0, 0));
    timelocks[CfgID.PM_LONG_TERM_VEGA_POWER].push(Rule(0, 0, 0));
    timelocks[CfgID.PM_INITIAL_MARGIN_FACTOR].push(Rule(0, 0, 0));
    timelocks[CfgID.PM_NET_SHORT_OPTION_MINIMUM].push(Rule(0, 0, 0));
    // This config doesn't require a timelock
    timelocks[CfgID.ADMIN_RECOVERY_ADDRESS].push(Rule(0, 0, 0));
  }

  /// @notice Schedule a config update preflight. Afterwards, the timestamp at
  /// which the config is enforce is updated. This must be followed by a call
  /// to `setConfig` at some point in the future to actually make the config changes.
  ///
  /// @param timestamp the new system timestamp
  /// @param txID the new system txID
  /// @param key the config key
  /// @param value the config value in bytes32
  /// @param nonce the nonce of the transaction
  /// @param sig the signature of the transaction
  function scheduleConfig(
    uint64 timestamp,
    uint64 txID,
    CfgID key,
    bytes32 value,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setTimestampAndTxID(timestamp, txID);

    // ---------- Signature Verification -----------
    require(sig.signer == _getAddressCfg(CfgID.ADMIN_RECOVERY_ADDRESS), "unauthorized");
    _preventHashReplay(hashScheduleConfig(key, value, nonce), sig);
    // ------- End of Signature Verification -------

    // find the timelock for this config value and update the config
    uint256 lockDuration = _getLockDuration(key, value);
    state.scheduledConfig[key] = ScheduledConfigEntry(timestamp + lockDuration, value);

    // Emit an event
    emit ConfigScheduledEvent(key, value);
  }

  /// @notice Update a specific config. Performs check to ensure that the value
  /// is within the permissible range.
  /// @param timestamp the new system timestamp
  /// @param txID the new system txID
  /// @param key the config key
  /// @param value the config value in bytes32
  /// @param nonce the nonce of the transaction
  /// @param sig the signature of the transaction
  function setConfig(
    uint64 timestamp,
    uint64 txID,
    CfgID key,
    bytes32 value,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setTimestampAndTxID(timestamp, txID);

    // ---------- Signature Verification -----------
    require(sig.signer == _getAddressCfg(CfgID.ADMIN_RECOVERY_ADDRESS), "unauthorized");
    _preventHashReplay(hashSetConfig(key, value, nonce), sig);
    // ------- End of Signature Verification -------

    // find the lock duration
    ScheduledConfigEntry storage preflight = state.scheduledConfig[key];
    // If there is a preflight value, then this config must match that preflight config
    if (_getLockDuration(key, value) != 0) {
      require(preflight.value == value, "not preflighted");
      require(preflight.lockEndTime <= timestamp, "config is still locked");
    }
    state.configs[key] = value;

    // Emit an event
    emit ConfigSetEvent(key, value);
  }

  function _getIntCfg(CfgID key) internal view returns (int256) {
    return int256(uint256(_requireCfg(key)));
  }

  function _getUintCfg(CfgID key) internal view returns (uint256) {
    return uint256(_requireCfg(key));
  }

  // https://ethereum.stackexchange.com/questions/50914/convert-bytes32-to-address
  function _getAddressCfg(CfgID key) internal view returns (address) {
    return address(uint160(uint256(_requireCfg(key))));
  }

  function _getBoolCfg(CfgID key) internal view returns (bool) {
    return uint256(_requireCfg(key)) != 0;
  }

  function _requireCfg(CfgID key) private view returns (bytes32) {
    return state.configs[key];
  }

  /// @notice Find the timelock duration that corresponds to the change in value
  /// Expect the timelocks duration should be in increasing order of delta change and timelock duration
  /// If the delta is out of range, return the duration of the last rule
  function _getLockDuration(CfgID key, bytes32 newVal) private view returns (uint256) {
    // Shift the config type to the right position and mask it with 0xFF (last 8 bits)
    ConfigType typ = ConfigType((_CONFIG_TYPE >> (4 * uint8(key))) & 0xF);
    if (typ == ConfigType.ADDRESS || typ == ConfigType.BOOL) return 0;

    int256 percentage = _getChangePercent(newVal, state.configs[key]);
    Rule[] storage rules = state.configTimelocks[key];
    for (uint256 i = 0; i < rules.length; i++) {
      Rule storage rule = rules[i];
      if (percentage >= 0 && percentage <= int256(rule.deltaPositive)) return rule.lockDuration;
      if (percentage < 0 && uint256(-percentage) <= rule.deltaNegative) return rule.lockDuration;
    }

    // delta is out of range, return the duration of the last rule
    return rules[rules.length - 1].lockDuration;
  }

  /// @notice Get the percentage change between two values
  /// For all practical purposes most value will fit into int256
  function _getChangePercent(bytes32 newVal, bytes32 oldVal) private pure returns (int256) {
    int256 oldValInt = int256(uint(oldVal));
    int256 delta = int256(uint(newVal)) - oldValInt;
    if (oldValInt == 0)
      // 1e6%, just a big number to make sure that this will match the last rule
      return 10000000000;

    // Get the changed percentage, round up
    return (delta * 100 * int256(PERCENT) + oldValInt - 1) / oldValInt;
  }
}
