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
  int32 private constant ONE_CENTIBEEP = 1;
  int32 private constant ONE_BEEP = 100;
  int32 private constant ONE_PERCENT = 10000;
  int32 private constant ONE_HUNDRED_PERCENT = 1000000;
  bytes32 private constant TRUE_BYTES32 = bytes32(uint256(1));
  bytes32 private constant FALSE_BYTES32 = bytes32(uint256(0));
  // The default fallback value which is a zero value array
  bytes32 internal constant DEFAULT_CONFIG_ENTRY = bytes32(uint256(0));
  int64 private constant ONE_HOUR_NANOS = 60 * 60 * 1e9;

  ///////////////////////////////////////////////////////////////////
  /// Config Accessors
  ///////////////////////////////////////////////////////////////////

  function _intToConfig(int64 v) internal pure returns (bytes32) {
    return bytes32(uint256(uint64(v)));
  }

  function _configToInt(bytes32 v) internal pure returns (int64) {
    return int64(uint64((uint256(v))));
  }

  function _getIntConfig(ConfigID key) internal view returns (int64, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (int64(uint64((uint256(c.val)))), c.isSet);
  }

  function _getIntConfig2D(ConfigID key, bytes32 subKey) internal view returns (int64, bool) {
    (uint64 val, bool isSet) = _getUintConfig2D(key, subKey);
    return (int64(val), isSet);
  }

  function _centiBeepToConfig(int32 v) internal pure returns (bytes32) {
    return bytes32(uint256(uint32(v)));
  }

  function _getCentibeepConfig(ConfigID key) internal view returns (int32, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (int32(uint32((uint256(c.val)))), c.isSet);
  }

  function _getCentibeepConfig2D(ConfigID key, bytes32 subKey) internal view returns (int32, bool) {
    ConfigValue storage c = state.config2DValues[key][subKey];
    if (!c.isSet) {
      c = state.config2DValues[key][DEFAULT_CONFIG_ENTRY];
    }
    return (int32(uint32(uint256(c.val))), c.isSet);
  }

  function _uintToConfig(uint64 v) internal pure returns (bytes32) {
    return bytes32(uint256(v));
  }

  function _configToUint(bytes32 v) internal pure returns (uint64) {
    return uint64((uint256(v)));
  }

  function _getUintConfig(ConfigID key) internal view returns (uint64, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (uint64(uint256(c.val)), c.isSet);
  }

  function _getUintConfig2D(ConfigID key, bytes32 subKey) internal view returns (uint64, bool) {
    ConfigValue storage c = state.config2DValues[key][subKey];
    if (!c.isSet) {
      c = state.config2DValues[key][DEFAULT_CONFIG_ENTRY];
    }
    return (uint64(uint256(c.val)), c.isSet);
  }

  function _boolToConfig(bool v) internal pure returns (bytes32) {
    return v ? TRUE_BYTES32 : FALSE_BYTES32;
  }

  function _configToBool(bytes32 v) internal pure returns (bool) {
    return v == TRUE_BYTES32;
  }

  function _getBoolConfig(ConfigID key) internal view returns (bool) {
    return state.config1DValues[key].val == TRUE_BYTES32;
  }

  function _getBoolConfig2D(ConfigID key, bytes32 subKey) internal view returns (bool) {
    return state.config2DValues[key][subKey].val == TRUE_BYTES32;
  }

  function _addressToConfig(address v) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(v)));
  }

  function _configToAddress(bytes32 v) internal pure returns (address) {
    return address(uint160(uint256(v)));
  }

  // https://ethereum.stackexchange.com/questions/50914/convert-bytes32-to-address
  function _getAddressConfig(ConfigID key) internal view returns (address, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (address(uint160(uint256(c.val))), c.isSet);
  }

  function _getAddressConfig2D(ConfigID key, bytes32 subKey) internal view returns (address, bool) {
    ConfigValue storage c = state.config2DValues[key][subKey];
    if (!c.isSet) {
      c = state.config2DValues[key][DEFAULT_CONFIG_ENTRY];
    }
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
  /// @param subKey the config subKey, 0x0 for 1D config
  /// @param value the config value in bytes32
  /// @param sig the signature of the transaction
  function scheduleConfig(
    int64 timestamp,
    uint64 txID,
    ConfigID key,
    bytes32 subKey,
    bytes32 value,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    require(_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer)), "not config address");

    _preventReplay(hashScheduleConfig(key, subKey, value, sig.nonce), sig);
    // ------- End of Signature Verification -------

    ConfigSetting storage setting = state.configSettings[key];
    require(setting.typ != ConfigType.UNSPECIFIED, "404");
    // For 1D config settings, subKey must be 0
    // For 2D config, there's no such restriction
    bool is2DConfig = uint256(setting.typ) % 2 == 0;
    require(is2DConfig || subKey == 0, "invalid subKey");

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
    bytes32 subKey,
    bytes32 value,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    require(_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer)), "not config address");

    // ---------- Signature Verification -----------
    _preventReplay(hashSetConfig(key, subKey, value, sig.nonce), sig);
    // ------- End of Signature Verification -------

    ConfigSetting storage setting = state.configSettings[key];
    ConfigType typ = setting.typ;
    require(typ != ConfigType.UNSPECIFIED, "config not found 404");

    // For 1D config settings, subKey must be 0
    // For 2D config, there's no such restriction
    bool is2DConfig = uint256(typ) % 2 == 0;
    require(is2DConfig || subKey == 0, "invalid 1D subKey");

    int64 lockDuration = _getLockDuration(key, subKey, value);
    if (lockDuration > 0) {
      int64 lockEndTime = setting.schedules[subKey].lockEndTime;
      require(lockEndTime > 0 && lockEndTime <= timestamp, "not scheduled or still locked");
    }
    // 2D configs are always placed at odd indices in the enum. See ConfigID
    ConfigValue storage config = is2DConfig ? state.config2DValues[key][subKey] : state.config1DValues[key];
    config.isSet = true;
    config.val = value;

    // Must delete the schedule after the config is set (to prevent replays)
    delete setting.schedules[subKey];
  }

  /// @dev Find the timelock duration in nanoseconds that corresponds to the change in value
  /// Expect the timelocks duration should be in increasing order of delta change and timelock duration
  function _getLockDuration(ConfigID key, bytes32 subKey, bytes32 newVal) private view returns (int64) {
    ConfigType typ = state.configSettings[key].typ;
    require(typ != ConfigType.UNSPECIFIED, "404");

    Rule[] storage rules = state.configSettings[key].rules;
    // If there are no rules for the config setting, return 0 (no lock duration)
    if (rules.length == 0) return 0;

    // These config types are not numerical and have a fixed lock duration
    // There should be only 1 timelock rule for these config types
    if (typ == ConfigType.ADDRESS || typ == ConfigType.ADDRESS2D || typ == ConfigType.BOOL || typ == ConfigType.BOOL2D)
      return rules[0].lockDuration;

    if (typ == ConfigType.INT) {
      (int64 oldVal, bool isSet) = _getIntConfig(key);
      if (isSet) return _getIntConfigLockDuration(key, oldVal, _configToInt(newVal));
      return 0;
    }
    if (typ == ConfigType.INT2D) {
      (int64 oldVal, bool isSet) = _getCentibeepConfig2D(key, subKey);
      if (isSet) return _getIntConfigLockDuration(key, oldVal, _configToInt(newVal));
      return 0;
    }
    if (typ == ConfigType.CENTIBEEP) {
      (int32 oldVal, bool isSet) = _getCentibeepConfig(key);
      if (isSet) return _getIntConfigLockDuration(key, int64(oldVal), int64(_configToInt(newVal)));
      return 0;
    }
    if (typ == ConfigType.CENTIBEEP2D) {
      (int32 oldVal, bool isSet) = _getCentibeepConfig2D(key, subKey);
      if (isSet) return _getIntConfigLockDuration(key, int64(oldVal), int64(_configToInt(newVal)));
      return 0;
    }
    if (typ == ConfigType.UINT) {
      (uint64 oldVal, bool isSet) = _getUintConfig(key);
      if (isSet) return _getUintConfigLockDuration(key, oldVal, _configToUint(newVal));
      return 0;
    }
    if (typ == ConfigType.UINT2D) {
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

  ///////////////////////////////////////////////////////////////////
  /// Default Config Settings
  ///////////////////////////////////////////////////////////////////
  // The default config settings are hardcoded in the contract
  // This should be called only once during the proxy contract deployment, in the initialize function
  function _setDefaultConfigSettings() internal {
    mapping(ConfigID => ConfigSetting) storage settings = state.configSettings;
    mapping(ConfigID => mapping(bytes32 => ConfigValue)) storage values2D = state.config2DValues;

    // This is a special value that represents an empty value for a config
    // bytes32 emptyValue = bytes32(uint256(0));

    ///////////////////////////////////////////////////////////////////
    /// Simple Margin
    ///////////////////////////////////////////////////////////////////

    // SM_FUTURES_INITIAL_MARGIN
    ConfigID id = ConfigID.SM_FUTURES_INITIAL_MARGIN;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    mapping(bytes32 => ConfigValue) storage v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(2 * ONE_PERCENT);
    Rule[] storage rules = settings[id].rules;
    rules.push(Rule(0, 0, uint64(int64((100 * ONE_HUNDRED_PERCENT)))));
    rules.push(Rule(int64(ONE_HOUR_NANOS), uint64(int64((10 * ONE_BEEP))), 0));
    rules.push(Rule(int64(4 * ONE_HOUR_NANOS), uint64(int64((1 * ONE_PERCENT))), 0));
    rules.push(Rule(int64(24 * ONE_HOUR_NANOS), uint64(int64((10 * ONE_PERCENT))), 0));
    rules.push(Rule(int64(7 * 24 * ONE_HOUR_NANOS), uint64(int64((1 * ONE_HUNDRED_PERCENT))), 0));

    // SM_FUTURES_MAINTENANCE_MARGIN
    id = ConfigID.SM_FUTURES_MAINTENANCE_MARGIN;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(ONE_PERCENT);

    // SM_FUTURES_VARIABLE_MARGIN
    id = ConfigID.SM_FUTURES_VARIABLE_MARGIN;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(50 * ONE_CENTIBEEP);
    v2d[bytes32(uint256(Currency.BTC))].isSet = true;
    v2d[bytes32(uint256(Currency.BTC))].val = _centiBeepToConfig(50 * ONE_CENTIBEEP);
    v2d[bytes32(uint256(Currency.ETH))].isSet = true;
    v2d[bytes32(uint256(Currency.ETH))].val = _centiBeepToConfig(4 * ONE_CENTIBEEP);

    // SM_OPTIONS_INITIAL_MARGIN_HIGH
    id = ConfigID.SM_OPTIONS_INITIAL_MARGIN_HIGH;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(15 * ONE_PERCENT);

    // SM_OPTIONS_INITIAL_MARGIN_LOW
    id = ConfigID.SM_OPTIONS_INITIAL_MARGIN_LOW;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(10 * ONE_PERCENT);

    // SM_OPTIONS_MAINTENANCE_MARGIN
    id = ConfigID.SM_OPTIONS_MAINTENANCE_MARGIN;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(750 * ONE_BEEP);

    ///////////////////////////////////////////////////////////////////
    /// Portfolio Margin
    ///////////////////////////////////////////////////////////////////

    // PM_SPOT_MOVE
    id = ConfigID.PM_SPOT_MOVE;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(20 * ONE_PERCENT);

    // PM_VOL_MOVE_DOWN
    id = ConfigID.PM_VOL_MOVE_DOWN;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(45 * ONE_PERCENT);

    // PM_VOL_MOVE_UP
    id = ConfigID.PM_VOL_MOVE_UP;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(45 * ONE_PERCENT);

    // PM_SPOT_MOVE_EXTREME
    id = ConfigID.PM_SPOT_MOVE_EXTREME;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(60 * ONE_PERCENT);

    // PM_EXTREME_MOVE_DISCOUNT
    id = ConfigID.PM_EXTREME_MOVE_DISCOUNT;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(67 * ONE_PERCENT);

    // PM_SHORT_TERM_VEGA_POWER
    id = ConfigID.PM_SHORT_TERM_VEGA_POWER;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(30 * ONE_PERCENT);

    // PM_LONG_TERM_VEGA_POWER
    id = ConfigID.PM_LONG_TERM_VEGA_POWER;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(13 * ONE_PERCENT);

    // PM_INITIAL_MARGIN_FACTOR
    id = ConfigID.PM_INITIAL_MARGIN_FACTOR;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(130 * ONE_PERCENT);

    // PM_FUTURES_CONTINGENCY_MARGIN
    id = ConfigID.PM_FUTURES_CONTINGENCY_MARGIN;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(60 * ONE_BEEP);

    // PM_OPTIONS_CONTINGENCY_MARGIN
    id = ConfigID.PM_OPTIONS_CONTINGENCY_MARGIN;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(ONE_PERCENT);

    ///////////////////////////////////////////////////////////////////
    /// ADMIN addresses. Commented out because they are empty for now
    ///////////////////////////////////////////////////////////////////
    DefaultAddress memory defaultAddresses = _getDefaultAddresses();

    // ADMIN_RECOVERY_ADDRESS
    bytes32 addr;

    id = ConfigID.ADMIN_RECOVERY_ADDRESS;
    settings[id].typ = ConfigType.BOOL2D;
    addr = _addressToConfig(defaultAddresses.Recovery);
    v2d = values2D[id];
    v2d[addr].isSet = true;
    v2d[addr].val = TRUE_BYTES32;

    // ORACLE_ADDRESS
    id = ConfigID.ORACLE_ADDRESS;
    settings[id].typ = ConfigType.BOOL2D;
    addr = _addressToConfig(defaultAddresses.Oracle);
    v2d = values2D[id];
    v2d[addr].isSet = true;
    v2d[addr].val = TRUE_BYTES32;

    // CONFIG_ADDRESS
    id = ConfigID.CONFIG_ADDRESS;
    settings[id].typ = ConfigType.BOOL2D;
    addr = _addressToConfig(defaultAddresses.Config);
    v2d = values2D[id];
    v2d[addr].isSet = true;
    v2d[addr].val = TRUE_BYTES32;

    // MARKET_DATA_ADDRESS
    id = ConfigID.MARKET_DATA_ADDRESS;
    settings[id].typ = ConfigType.BOOL2D;
    addr = _addressToConfig(defaultAddresses.MarketData);
    v2d = values2D[id];
    v2d[addr].isSet = true;
    v2d[addr].val = TRUE_BYTES32;

    // // ADMIN_FEE_SUB_ACCOUNT_ID
    // id = ConfigID.ADMIN_FEE_SUB_ACCOUNT_ID;
    // settings[id].typ = ConfigType.UINT;
    // values1D[id].val = 0;

    // // ADMIN_LIQUIDATION_SUB_ACCOUNT_ID
    // id = ConfigID.ADMIN_LIQUIDATION_SUB_ACCOUNT_ID;
    // settings[id].typ = ConfigType.UINT;
    // values1D[id].val = 0;

    ///////////////////////////////////////////////////////////////////
    /// Funding rate settings
    ///////////////////////////////////////////////////////////////////

    // FUNDING_RATE_HIGH
    id = ConfigID.FUNDING_RATE_HIGH;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(5 * ONE_PERCENT);

    // FUNDING_RATE_LOW
    id = ConfigID.FUNDING_RATE_LOW;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(-5 * ONE_PERCENT);

    ///////////////////////////////////////////////////////////////////
    /// Fee settings
    ///////////////////////////////////////////////////////////////////

    // FUTURE_MAKER_FEE_MINIMUM
    id = ConfigID.FUTURE_MAKER_FEE_MINIMUM;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(-30 * ONE_CENTIBEEP);

    // FUTURE_TAKER_FEE_MINIMUM
    id = ConfigID.FUTURE_TAKER_FEE_MINIMUM;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(140 * ONE_CENTIBEEP);

    // OPTION_MAKER_FEE_MINIMUM
    id = ConfigID.OPTION_MAKER_FEE_MINIMUM;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(-30 * ONE_CENTIBEEP);

    // OPTION_TAKER_FEE_MINIMUM
    id = ConfigID.OPTION_TAKER_FEE_MINIMUM;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    v2d = values2D[id];
    v2d[DEFAULT_CONFIG_ENTRY].isSet = true;
    v2d[DEFAULT_CONFIG_ENTRY].val = _centiBeepToConfig(120 * ONE_CENTIBEEP);
  }

  struct DefaultAddress {
    address Config;
    address Oracle;
    address MarketData;
    address Recovery;
  }

  function _getDefaultAddresses() private pure returns (DefaultAddress memory) {
    // This is for dev environment
    return
      DefaultAddress({
        Config: 0xA08Ee13480C410De20Ea3d126Ee2a7DaA2a30b7D,
        Oracle: 0x47ebFBAda4d85Dac6b9018C0CE75774556A8243f,
        MarketData: 0x215ec976846B3C68daedf93bA35d725A0E2c98e3,
        Recovery: 0x84b3Bc75232C9F880c79EFCc5d98e8C6E44f95Ae
      });
  }
}
