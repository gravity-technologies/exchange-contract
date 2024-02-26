// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "../types/DataStructure.sol";
import "./signature/generated/ConfigSig.sol";
import {ConfigID, ConfigTimelockRule as Rule} from "../types/DataStructure.sol";
import "../util/Address.sol";

///////////////////////////////////////////////////////////////////
/// Config Contract supports
///  - (1) retrieving the current value for a config type
///  - (2) changing the value of a config type
///
/// Terms
///   - 1-dimensional Config
///       Store the current value of all 1 dimensional config. 1D config is a simple key -> value mapping
///       Eg: (AdminFeeSubAccountID) = 1357902468
///           (AdminRecoveryAddress) = 0xc0ffee254729296a45a3885639AC7E10F9d54979
///
///   - 2-dimensional Config
///      Store the current value of all 2 dimensional config.
///      A 2D config needs to be referred by both (key, subKey)
///      This is mainly to support risk configs for different underlying currency
///      Eg: (PortfolioInitialMarginFactor, BTC) = 1.2
///          (PortfolioInitialMarginFactor, DOGE) = 1.5
///
/// Reading a config value
///  - Every config value is encoded as a byte32. Storing uint, int, address,
///    hash will convert the value to a bytes32 representation internally
///  - The value of 1D config is stored in `config1DValues` mapping
///    To read this we need only the (key) of the config
///  - The value of 2D config is stored in `config2DValues` mapping.
///    To read this we need both the (key, subKey) of the config
///
/// Changing config
///  - Every config change is timelocked. The timelock duration is determined
///    by the magnitude of change in value (for numerical config) and the config type
///  - The hardcoded timelock rules for each ConfigID determine the timelock duration
///  - In order to make changes to a config value, the operator needs to first
///    schedule the change by calling `scheduleConfig. The contract will `lock`
///    the config for the duration of the timelock
///  - After the timelock duration has passed, the operator can then change to
///    the new value by calling `setConfig`
///
///////////////////////////////////////////////////////////////////
contract ConfigContract is BaseContract {
  // --------------- Constants ---------------
  uint private constant CENTIBEEP = 1;
  uint private constant BEEP = 100;
  uint private constant PERCENT = 10000;

  ///////////////////////////////////////////////////////////////////
  /// Config Accessors
  ///////////////////////////////////////////////////////////////////

  function _configToInt(bytes32 v) internal pure returns (int64) {
    return int64(uint64((uint256(v))));
  }

  function _getIntConfig(ConfigID key) internal view returns (int64, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (int64(uint64((uint256(c.val)))), c.isSet);
  }

  function _getIntConfig2D(ConfigID key, uint64 subKey) internal view returns (int64, bool) {
    ConfigValue storage c = state.config2DValues[key][subKey];
    return (int64(uint64((uint256(c.val)))), c.isSet);
  }

  function _configToUint(bytes32 v) internal pure returns (uint64) {
    return uint64((uint256(v)));
  }

  function _getUintConfig(ConfigID key) internal view returns (uint64, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (uint64(uint256(c.val)), c.isSet);
  }

  function _getUintConfig2D(ConfigID key, uint64 subKey) internal view returns (uint64, bool) {
    ConfigValue storage c = state.config2DValues[key][subKey];
    return (uint64(uint256(c.val)), c.isSet);
  }

  function _configToAddress(bytes32 v) internal pure returns (address) {
    return address(uint160(uint256(v)));
  }

  // https://ethereum.stackexchange.com/questions/50914/convert-bytes32-to-address
  function _getAddressConfig(ConfigID key) internal view returns (address, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (address(uint160(uint256(c.val))), c.isSet);
  }

  function _getAddressConfig2D(ConfigID key, uint64 subKey) internal view returns (address, bool) {
    ConfigValue storage c = state.config2DValues[key][subKey];
    return (address(uint160(uint256(c.val))), c.isSet);
  }

  ///////////////////////////////////////////////////////////////////
  /// Config APIs
  ///////////////////////////////////////////////////////////////////

  /// @notice Schedule a config update. Afterwards, the timestamp at
  /// which the config is enforce is updated. This must be followed by a call
  /// to `setConfig` at some point in the future to actually make the config changes.
  ///
  /// @param timestamp the new system timestamp
  /// @param txID the new system txID
  /// @param key the config key
  /// @param subKey the config subKey, 0 for 1D config
  /// @param value the config value in bytes32
  /// @param sig the signature of the transaction
  function scheduleConfig(
    int64 timestamp,
    uint64 txID,
    ConfigID key,
    uint64 subKey,
    bytes32 value,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // // ---------- Signature Verification -----------
    // require(sig.signer == _getAddressConfig(ConfigID.ADMIN_RECOVERY_ADDRESS), "unauthorized");
    _preventReplay(hashScheduleConfig(key, subKey, value, sig.nonce), sig);
    // // ------- End of Signature Verification -------

    ConfigSetting storage setting = state.configSettings[key];
    require(setting.typ != ConfigType.UNSPECIFIED, "404");
    // For 1D config settings, subKey must be 0
    // For 2D config, there's no such restriction
    // ie: NOT (uint256(setting.typ) % 2 == 1 && subKey == 0).
    // We expanded the condition to make it more efficient (2 comparisons instead of 3)
    require(uint256(setting.typ) % 2 == 0 || subKey != 0, "invalid subKey");

    ConfigSchedule storage sched = setting.schedules[subKey];
    sched.lockEndTime = timestamp + _getLockDuration(key, subKey, value);
  }

  /// @notice Update a specific config. Performs check to ensure that the value
  /// is within the permissible range.
  ///
  /// @param timestamp the new system timestamp
  /// @param txID the new system txID
  /// @param key the config key
  /// @param subKey the config sub key, for 1D config it must be 0
  /// @param value the config value in bytes32
  /// @param sig the signature of the transaction
  function setConfig(
    int64 timestamp,
    uint64 txID,
    ConfigID key,
    uint64 subKey,
    bytes32 value,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);
    // ---------- Signature Verification -----------
    // (address adminRecoveryAddr, ) = _getAddressConfig(ConfigID.ADMIN_RECOVERY_ADDRESS);
    // require(sig.signer == adminRecoveryAddr, "unauthorized");
    _preventReplay(hashSetConfig(key, subKey, value, sig.nonce), sig);
    // ------- End of Signature Verification -------

    ConfigSetting storage setting = state.configSettings[key];
    ConfigType typ = setting.typ;
    require(typ != ConfigType.UNSPECIFIED, "404");

    // For 1D config settings, subKey must be 0
    // For 2D config, there's no such restriction
    // ie: NOT (uint256(setting.typ) % 2 == 1 && subKey == 0).
    // We expanded the condition to make it more efficient (2 comparisons instead of 3)
    require(uint256(setting.typ) % 2 != 0 || subKey != 0, "invalid 1D subKey");
    int64 lockEndTime = setting.schedules[subKey].lockEndTime;
    require(lockEndTime > 0 && lockEndTime <= timestamp, "not scheduled or still locked");

    // 2D configs are always placed at odd indices in the enum. See ConfigID
    if (uint(typ) % 2 == 0) {
      mapping(uint64 => ConfigValue) storage config = state.config2DValues[key];
      config[subKey].isSet = true;
      config[subKey].val = value;
    } else {
      ConfigValue storage config = state.config1DValues[key];
      config.isSet = true;
      config.val = value;
    }

    // Must delete the schedule after the config is set (to prevent replays)
    delete setting.schedules[subKey];
  }

  /// @dev Find the timelock duration in nanoseconds that corresponds to the change in value
  /// Expect the timelocks duration should be in increasing order of delta change and timelock duration
  function _getLockDuration(ConfigID key, uint64 subKey, bytes32 newVal) private view returns (int64) {
    ConfigType typ = state.configSettings[key].typ;
    require(typ != ConfigType.UNSPECIFIED, "404");

    Rule[] storage rules = state.configSettings[key].rules;
    // If there are no rules for the config setting, return 0 (no lock duration)
    if (rules.length == 0) return 0;

    // These config types are not numerical and have a fixed lock duration
    // There should be only 1 timelock rule for these config types
    if (typ == ConfigType.ADDRESS || typ == ConfigType.ADDRESS2D || typ == ConfigType.BOOL || typ == ConfigType.BOOL2D)
      return rules[0].lockDuration;

    if (typ == ConfigType.INT || typ == ConfigType.CENTIBEEP) {
      (int64 oldVal, bool isSet) = _getIntConfig(key);
      if (isSet) return _getIntConfigLockDuration(key, oldVal, _configToInt(newVal));
      return 0;
    } else if (typ == ConfigType.INT2D || typ == ConfigType.CENTIBEEP2D) {
      (int64 oldVal, bool isSet) = _getIntConfig2D(key, subKey);
      if (isSet) return _getIntConfigLockDuration(key, oldVal, _configToInt(newVal));
      return 0;
    } else if (typ == ConfigType.UINT) {
      (uint64 oldVal, bool isSet) = _getUintConfig(key);
      if (isSet) return _getUintConfigLockDuration(key, oldVal, _configToUint(newVal));
      return 0;
    } else if (typ == ConfigType.UINT2D) {
      (uint64 oldVal, bool isSet) = _getUintConfig2D(key, subKey);
      if (isSet) return _getUintConfigLockDuration(key, oldVal, _configToUint(newVal));
      return 0;
    }

    // Should never reach here
    require(false, "404");
    return 0;
  }

  /// @dev Find the timelock duration in nanoseconds that corresponds to the change in `uint` value
  /// We expect the timelocks duration should be in increasing order of delta change and
  /// timelock duration, ie:
  ///    rules[i].deltaPositive < rules[i+1].deltaPositive AND rules[i].deltaNegative < rules[i+1].deltaNegative
  /// If the change in value is not within the range of any rule, the duration of the last rule
  /// (which is the `maximal rule`) is returned
  ///
  /// @param key the config key
  /// @param oldVal the old value
  /// @param newVal the new value
  function _getUintConfigLockDuration(ConfigID key, uint64 oldVal, uint64 newVal) private view returns (int64) {
    if (newVal == oldVal) return 0; // No change in value, no lock duration

    Rule[] storage rules = state.configSettings[key].rules;
    uint rulesLen = rules.length;

    if (newVal < oldVal) {
      for (uint i; i < rulesLen; ++i) {
        if (oldVal - newVal <= rules[i].deltaNegative) return rules[i].lockDuration;
      }
    } else {
      for (uint i; i < rulesLen; ++i) {
        if (newVal - oldVal <= rules[i].deltaPositive) return rules[i].lockDuration;
      }
    }

    return rules[rulesLen - 1].lockDuration; // Default to last timelock rule
  }

  /// @dev Find the timelock duration in nanoseconds that corresponds to the change in `int` value
  /// We expect the timelocks duration should be in increasing order of delta change and
  /// timelock duration, ie:
  ///    rules[i].deltaPositive < rules[i+1].deltaPositive AND rules[i].deltaNegative < rules[i+1].deltaNegative
  /// If the change in value is not within the range of any rule, the duration of the last rule
  /// (which is the `maximal rule`) is returned
  ///
  function _getIntConfigLockDuration(ConfigID key, int64 oldVal, int64 newVal) private view returns (int64) {
    if (newVal == oldVal) return 0; // No change in value, no lock duration

    Rule[] storage rules = state.configSettings[key].rules;
    uint rulesLen = rules.length;

    if (newVal < oldVal) {
      for (uint i; i < rulesLen; ++i)
        if (uint64(oldVal - newVal) <= rules[i].deltaNegative) return rules[i].lockDuration;
    } else if (newVal > oldVal) {
      for (uint i; i < rulesLen; ++i)
        if (uint64(newVal - oldVal) <= rules[i].deltaPositive) return rules[i].lockDuration;
    }
    return rules[rulesLen - 1].lockDuration; // Default to last timelock rule
  }
}
