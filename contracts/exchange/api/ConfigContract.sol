// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./HelperContract.sol";
import "../types/DataStructure.sol";
import "./signature/generated/ConfigSig.sol";
import {ConfigID as CfgID, ConfigTimelockRule as Rule} from "../types/DataStructure.sol";
import "../util/Address.sol";

contract ConfigContract is HelperContract {
  // --------------- Constants ---------------
  uint private constant CENTIBEEP = 1;
  uint private constant BEEP = 100;
  uint private constant PERCENT = 10000;

  /**
   * @dev This is a bitmask representation of the type of each config (either bool, address, int, uint)
   * Each config type is represented by 4 bits. Using uint256 we can store up to 64 configs
   * To get the type of each config, we shift the _CONFIG_TYPE to the right by 4 * configID and get the last 4 bit
   * ie: type = (_CONFIG_TYPE >> (4 * configID)) & 0xF
   *
   * Below are the list of config and their types, and the index of the 4-bit that determine the type
   *
   * 4-bit index / ConfigID / Type
   * ---------------------------------------------------
   *  0 / UNSPECIFIED / Unspecified (0)
   *  1 / SM_FUTURES_INITIAL_MARGIN / Uint (4)
   *  2 / SM_FUTURES_MAINTENANCE_MARGIN / Uint (4)
   *  3 / SM_FUTURES_VARIABLE_MARGIN / Uint (4)
   *  4 / SM_OPTIONS_INITIAL_MARGIN_HIGH / Uint (4)
   *  5 / SM_OPTIONS_INITIAL_MARGIN_LOW / Uint (4)
   *  6 / SM_OPTIONS_MAINTENANCE_MARGIN_HIGH / Uint (4)
   *  7 / SM_OPTIONS_MAINTENANCE_MARGIN_LOW / Uint (4)
   *  8 / SM_OPTIONS_VARIABLE_MARGIN / Uint (4)
   *  9 / PM_SPOT_MOVE / Uint (4)
   * 10 / PM_VOL_MOVE_UP / Uint (4)
   * 11 / PM_VOL_MOVE_DOWN / Uint (4)
   * 12 / PM_SPOT_MOVE_EXTREME / Uint (4)
   * 13 / PM_EXTREME_MOVE_DISCOUNT / Uint (4)
   * 14 / PM_SHORT_TERM_VEGA_POWER / Uint (4)
   * 15 / PM_LONG_TERM_VEGA_POWER / Uint (4)
   * 16 / PM_INITIAL_MARGIN_FACTOR / Uint (4)
   * 17 / PM_NET_SHORT_OPTION_MINIMUM / Uint (4)
   * 18 / ADMIN_RECOVERY_ADDRESS / Address (2)
   * 19 / FEE_SUB_ACCOUNT_ID / Address (2)
   * 20 / PERP_FUNDING_RATE / Uint (4)
   */
  uint256 private constant _CONFIG_TYPE = 0x422444444444444444440;

  // ---------------- Events ----------------
  // event ConfigScheduledEvent(CfgID indexed configID, bytes32 value);
  // event ConfigSetEvent(CfgID indexed configID, bytes32 value);

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
    timelocks[CfgID.FEE_SUB_ACCOUNT_ID].push(Rule(0, 0, 0));
  }

  /// @notice Schedule a config update. Afterwards, the timestamp at
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
    int64 timestamp,
    uint64 txID,
    CfgID key,
    bytes32 value,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    require(sig.signer == _getAddressCfg(CfgID.ADMIN_RECOVERY_ADDRESS), "unauthorized");
    _preventReplay(hashScheduleConfig(key, value, nonce), sig);
    // ------- End of Signature Verification -------

    // find the timelock for this config value and update the config
    int256 lockDuration = _getLockDuration(key, value);
    state.scheduledConfig[key] = ScheduledConfigEntry(timestamp + lockDuration, value);
  }

  /// @notice Update a specific config. Performs check to ensure that the value
  /// is within the permissible range.
  ///
  /// @param timestamp the new system timestamp
  /// @param txID the new system txID
  /// @param key the config key
  /// @param value the config value in bytes32
  /// @param nonce the nonce of the transaction
  /// @param sig the signature of the transaction
  function setConfig(
    int64 timestamp,
    uint64 txID,
    CfgID key,
    bytes32 value,
    uint32 nonce,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    require(sig.signer == _getAddressCfg(CfgID.ADMIN_RECOVERY_ADDRESS), "unauthorized");
    _preventReplay(hashSetConfig(key, value, nonce), sig);
    // ------- End of Signature Verification -------

    // find the lock duration
    ScheduledConfigEntry storage schedule = state.scheduledConfig[key];
    // any config change must be scheduled first. LockEndTime must always be positive
    require(schedule.lockEndTime > 0, "not scheduled");

    // If the lock duration is 0, config can be changed immediately without further check.
    // Otherwise, this config value must match the scheduled config value
    if (_getLockDuration(key, value) != 0) {
      require(schedule.value == value, "mismatch scheduled");
      require(schedule.lockEndTime <= timestamp, "config is locked");
    }
    state.configs[key] = value;
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

  /// @dev Find the timelock duration that corresponds to the change in value
  /// Expect the timelocks duration should be in increasing order of delta change and timelock duration
  /// If the delta is out of range, revert the transaction
  function _getLockDuration(CfgID key, bytes32 newVal) private view returns (int256) {
    // Shift the config type to the right position and mask it with 0xF (last 4 bits)
    ConfigType typ = ConfigType((_CONFIG_TYPE >> (4 * uint8(key))) & 0xF);
    Rule[] storage rules = state.configTimelocks[key];
    if (typ == ConfigType.ADDRESS || typ == ConfigType.BOOL) {
      return rules[0].lockDuration;
    }

    // TODO: add support for int config when we have one
    require(typ != ConfigType.INT, "int not supported yet");

    // Check the Uint delta
    (bool positive, uint256 delta) = _getChangeDeltaUint(newVal, state.configs[key]);
    for (uint256 i = 0; i < rules.length; i++) {
      Rule storage rule = rules[i];
      if ((positive && delta <= rule.deltaPositive) || (!positive && delta <= rule.deltaNegative))
        return rule.lockDuration;
    }

    // delta is out of range
    require(false, "out of range");

    // Should never reach here
    return 0;
  }

  /// @dev Get the difference between two uint values
  function _getChangeDeltaUint(bytes32 newVal, bytes32 oldVal) private pure returns (bool positive, uint256 diff) {
    uint oldValUint = uint(oldVal);
    uint newValUint = uint(newVal);
    if (oldValUint > newValUint) return (false, oldValUint - newValUint);
    return (true, newValUint - oldValUint);
  }
}
