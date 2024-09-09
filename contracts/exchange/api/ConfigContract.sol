// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "../types/DataStructure.sol";
import "./signature/generated/ConfigSig.sol";
import {ConfigID, ConfigTimelockRule as Rule} from "../types/DataStructure.sol";

struct MarginTierBI {
  BI bracketStart;
  BI maintenanceMarginRate;
}


// The bit mask for the least significant 32 bits
uint256 constant LSB_32_MASK = 0xFFFFFFFF;
// The bit mask for the least significant 24 bits, used for Kind, Underlying, Quote encoding in determining the insurance fund subaccount ID
bytes32 constant KUQ_MASK = bytes32(uint256(0xFFFFFF));

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
  using BIMath for BI;

  // --------------- Constants ---------------
  int32 private constant ONE_CENTIBEEP = 1;
  int32 private constant ONE_BEEP = 100;
  int32 private constant ONE_PERCENT = 10000;
  int32 private constant ONE_HUNDRED_PERCENT = 1000000;
  bytes32 private constant TRUE_BYTES32 = bytes32(uint256(1));
  bytes32 private constant FALSE_BYTES32 = bytes32(uint256(0));
  // The default fallback value which is a zero value array
  bytes32 internal constant DEFAULT_CONFIG_ENTRY = bytes32(uint256(0));
  uint64 internal constant DEFAULT_WITHDRAWAL_FEE_USD = 25;
  bytes32 internal immutable UNUSED_MARGIN_TIER_VALUE =
    _getMaintenanceMarginBytes32(type(uint32).max, type(uint32).max);
  uint256 internal constant MAX_M_MARGIN_TIERS = 12;

  ///////////////////////////////////////////////////////////////////
  /// Config Accessors
  ///////////////////////////////////////////////////////////////////

  // function _intToConfig(int64 v) internal pure returns (bytes32) {
  //   return bytes32(uint256(uint64(v)));
  // }

  function _configToInt(bytes32 v) internal pure returns (int64) {
    return int64(uint64(uint256(v)));
  }

  function _getIntConfig(ConfigID key) internal view returns (int64, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (int64(uint64(uint256(c.val))), c.isSet);
  }

  // function _getIntConfig2D(ConfigID key, bytes32 subKey) internal view returns (int64, bool) {
  //   (uint64 val, bool isSet) = _getUintConfig2D(key, subKey);
  //   return (int64(val), isSet);
  // }

  function _centiBeepToConfig(int32 v) internal pure returns (bytes32) {
    return bytes32(uint256(uint32(v)));
  }

  function _getCentibeepConfig(ConfigID key) internal view returns (int32, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (int32(uint32(uint256(c.val))), c.isSet);
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
    return uint64(uint256(v));
  }

  function _getUintConfig(ConfigID key) internal view returns (uint64, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (uint64(uint256(c.val)), c.isSet);
  }

  function _getSubAccountFromUintConfig(ConfigID key) internal view returns (SubAccount storage, bool) {
    SubAccount storage sub;
    (uint64 subID, bool isSubConfigured) = _getUintConfig(key);
    sub = state.subAccounts[subID];

    if (!isSubConfigured) {
      return (sub, false);
    }

    return (sub, sub.id != 0);
  }

  function _getUintConfig2D(ConfigID key, bytes32 subKey) internal view returns (uint64, bool) {
    ConfigValue storage c = state.config2DValues[key][subKey];
    if (!c.isSet) {
      c = state.config2DValues[key][DEFAULT_CONFIG_ENTRY];
    }
    return (uint64(uint256(c.val)), c.isSet);
  }

  function _getByte32Config(ConfigID key) internal view returns (bytes32, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (c.val, c.isSet);
  }

  function _getByte32Config2D(ConfigID key, bytes32 subKey) internal view returns (bytes32, bool) {
    ConfigValue storage c = state.config2DValues[key][subKey];
    if (!c.isSet) {
      c = state.config2DValues[key][DEFAULT_CONFIG_ENTRY];
    }
    return (c.val, c.isSet);
  }

  // function _boolToConfig(bool v) internal pure returns (bytes32) {
  //   return v ? TRUE_BYTES32 : FALSE_BYTES32;
  // }

  // function _configToBool(bytes32 v) internal pure returns (bool) {
  //   return v == TRUE_BYTES32;
  // }

  // function _getBoolConfig(ConfigID key) internal view returns (bool) {
  //   return state.config1DValues[key].val == TRUE_BYTES32;
  // }

  function _getBoolConfig2D(ConfigID key, bytes32 subKey) internal view returns (bool) {
    return state.config2DValues[key][subKey].val == TRUE_BYTES32;
  }

  function _addressToConfig(address v) internal pure returns (bytes32) {
    return bytes32(uint256(uint160(v)));
  }

  // function _configToAddress(bytes32 v) internal pure returns (address) {
  //   return address(uint160(uint256(v)));
  // }

  function _currencyToConfig(Currency v) internal pure returns (bytes32) {
    return bytes32(uint256(uint(v)));
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

    _requireConfigIDUpdatableViaGenericAPI(key);

    // ---------- Signature Verification -----------
    require(_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer)), "not config address");

    _preventReplay(hashScheduleConfig(key, subKey, value, sig.nonce, sig.expiration), sig);
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

    _requireConfigIDUpdatableViaGenericAPI(key);

    require(_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer)), "not config address");

    // ---------- Signature Verification -----------
    _preventReplay(hashSetConfig(key, subKey, value, sig.nonce, sig.expiration), sig);
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

  function scheduleCurrencyMarginTiers(
    int64 timestamp,
    uint64 txID,
    Currency currency,
    MarginTier[] calldata marginTiers,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    _requireValidCurrencyMarginTiers(marginTiers);

    // ---------- Signature Verification -----------
    require(_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer)), "not config address");

    _preventReplay(hashScheduleCurrencyMarginTiers(currency, marginTiers, sig.nonce, sig.expiration), sig);
    // ------- End of Signature Verification -------

    ConfigSetting storage setting = state.configSettings[_currencyMarginTiersTimelockKey()];
    ConfigSchedule storage sched = setting.schedules[_currencyToConfig(currency)];
    sched.lockEndTime = timestamp + _getCurrencyMarginTiersLockDuration(currency, marginTiers);
  }

  function setCurrencyMarginTiers(
    int64 timestamp,
    uint64 txID,
    Currency currency,
    MarginTier[] calldata marginTiers,
    Signature calldata sig
  ) external {
    _setSequence(timestamp, txID);

    _requireValidCurrencyMarginTiers(marginTiers);

    // ---------- Signature Verification -----------
    require(_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer)), "not config address");

    _preventReplay(hashSetCurrencyMarginTiers(currency, marginTiers, sig.nonce, sig.expiration), sig);
    // ------- End of Signature Verification -------

    ConfigSetting storage setting = state.configSettings[_currencyMarginTiersTimelockKey()];

    int64 lockDuration = _getCurrencyMarginTiersLockDuration(currency, marginTiers);
    if (lockDuration > 0) {
      int64 lockEndTime = setting.schedules[_currencyToConfig(currency)].lockEndTime;
      require(lockEndTime > 0 && lockEndTime <= timestamp, "not scheduled or still locked");
    }

    // set config
    for (uint i = 0; i < marginTiers.length; i++) {
      ConfigValue storage config = state.config2DValues[ConfigID(uint(ConfigID.MAINTENANCE_MARGIN_TIER_01) + i)][
        _currencyToConfig(currency)
      ];
      config.isSet = true;
      config.val = _getMaintenanceMarginBytes32(marginTiers[i].bracketStart, marginTiers[i].maintenanceMarginRate);
    }

    for (uint i = marginTiers.length; i < _currencyMarginTiersCount(); i++) {
      ConfigValue storage config = state.config2DValues[ConfigID(uint(ConfigID.MAINTENANCE_MARGIN_TIER_01) + i)][
        _currencyToConfig(currency)
      ];
      config.isSet = true;
      config.val = UNUSED_MARGIN_TIER_VALUE;
    }

    delete setting.schedules[_currencyToConfig(currency)];
  }

  function _getMaintenanceMargin(
    BI memory size,
    MarginTierBI[MAX_M_MARGIN_TIERS] memory configs
  ) internal pure returns (BI memory) {
    BI memory margin = BI(0, 0);
    BI memory prevStart = BI(0, 0);
    BI memory prevRate = configs[0].maintenanceMarginRate;
    BI memory bracketSize = BI(0, 0);

    for (uint i = 0; i < configs.length; i++) {
      if (size.cmp(configs[i].bracketStart) <= 0) {
        bracketSize = size.sub(prevStart);
        margin = margin.add(bracketSize.mul(prevRate));
        return margin;
      }

      bracketSize = configs[i].bracketStart.sub(prevStart);
      margin = margin.add(bracketSize.mul(prevRate));

      prevStart = configs[i].bracketStart;
      prevRate = configs[i].maintenanceMarginRate;
    }

    // Handle the last bracket
    BI memory lastBracketSize = size.sub(prevStart);
    margin = margin.add(lastBracketSize.mul(prevRate));

    return margin;
  }

  function _getCurrenciesWithMMConfig() internal view returns (Currency[] memory) {
    Currency[] memory currencies = new Currency[](2);
    currencies[0] = Currency.BTC;
    currencies[1] = Currency.ETH;
    return currencies;
  }

  function _getMMConfigCurrencyIndex(Currency currency) internal view returns (uint) {
    Currency[] memory currencies = _getCurrenciesWithMMConfig();
    for (uint i = 0; i < currencies.length; i++) {
      if (currencies[i] == currency) {
        return i;
      }
    }
    revert("Currency not found in maintenance margin config");
  }

  /**
   * @dev Returns the maintenance margin config for all currency
   * @return The maintenance margin config for all currency, indexed by (currency_enum_value - ETH_enum_value)
   */
  function _getAllMarginTierBI() internal view returns (MarginTierBI[MAX_M_MARGIN_TIERS][] memory) {
    Currency[] memory currencies = _getCurrenciesWithMMConfig();

    MarginTierBI[MAX_M_MARGIN_TIERS][] memory configs = new MarginTierBI[MAX_M_MARGIN_TIERS][](currencies.length);


    // Add the maintenance margin config for each currency
    for (uint i = 0; i < currencies.length; i++) {
      configs[i] = _getMarginTierBIByCurrency(currencies[i]);
    }
    return configs;
  }

  /**
   * @dev Returns the maintenance margin config for a given currency
   * Each maintenance margin tier config value is stored as a bytes32 value
   * The encoding of that value is as follows, where size and ratio are fixed point numbers with 4 decimals:
   * +-------------------------------+
   * |    Size    |       Ratio      |
   * |  (32 bits) |      (32 bits)   |
   * +--------------------------------+
   *
   * @param currency The currency to get the maintenance margin config for
   * @return The maintenance margin config for the currency
   */
  function _getMarginTierBIByCurrency(
    Currency currency
  ) private view returns (MarginTierBI[MAX_M_MARGIN_TIERS] memory) {
    bytes32 currencyConfig = _currencyToConfig(currency);
    MarginTierBI[MAX_M_MARGIN_TIERS] memory configs;
    uint hi = uint(ConfigID.MAINTENANCE_MARGIN_TIER_12);
    uint lo = uint(ConfigID.MAINTENANCE_MARGIN_TIER_01);
    for (uint i = lo; i <= hi; i++) {
      (bytes32 mmBytes32, bool found) = _getByte32Config2D(ConfigID(i), currencyConfig);
      if (!found) {
        break;
      }
      uint256 mm = uint256(mmBytes32);
      configs[i - lo].bracketStart = BI(int256(uint256((mm >> 224) & LSB_32_MASK)), 4);
      configs[i - lo].maintenanceMarginRate = BI(int256(uint256((mm >> 160) & LSB_32_MASK)), 4);
    }
    return configs;
  }

  function _requireConfigIDUpdatableViaGenericAPI(ConfigID key) private view {
    require(!_isConfigIDCurrencyMarginTier(key), "config ID not updatable via generic API");
  }

  function _requireValidCurrencyMarginTiers(MarginTier[] calldata marginTiers) private pure {
    require(marginTiers.length > 0, "empty margin tiers");
    require(marginTiers.length <= _currencyMarginTiersCount(), "too many margin tiers");

    require(marginTiers[0].bracketStart == 0, "first bracket must start at 0");

    uint32 prevBracketStart = marginTiers[0].bracketStart;
    uint32 prevMaintenanceMarginRate = marginTiers[0].maintenanceMarginRate;

    for (uint i = 1; i < marginTiers.length; i++) {
      require(marginTiers[i].bracketStart > prevBracketStart, "brackets not increasing");
      require(marginTiers[i].maintenanceMarginRate > prevMaintenanceMarginRate, "margin rates not increasing");

      prevBracketStart = marginTiers[i].bracketStart;
      prevMaintenanceMarginRate = marginTiers[i].maintenanceMarginRate;
    }
  }

  function _currencyMarginTiersTimelockKey() private pure returns (ConfigID) {
    return ConfigID.MAINTENANCE_MARGIN_TIER_01;
  }

  function _currencyMarginTiersCount() private pure returns (uint256) {
    return uint256(ConfigID.MAINTENANCE_MARGIN_TIER_12) - uint256(ConfigID.MAINTENANCE_MARGIN_TIER_01) + 1;
  }

  function _isConfigIDCurrencyMarginTier(ConfigID key) private pure returns (bool) {
    return key >= ConfigID.MAINTENANCE_MARGIN_TIER_01 && key <= ConfigID.MAINTENANCE_MARGIN_TIER_12;
  }

  function _getCurrencyMarginTiersLockDuration(
    Currency currency,
    MarginTier[] calldata marginTiers
  ) private view returns (int64) {
    return 2 * 7 * 24 * ONE_HOUR_NANOS;
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

  function _getMaintenanceMarginBytes32(
    uint32 bracketStart,
    uint32 maintenanceMarginRate
  ) internal pure returns (bytes32) {
    return bytes32((uint(bracketStart) << 224) | (uint(maintenanceMarginRate) << 160));
  }

  ///////////////////////////////////////////////////////////////////
  /// Default Config Settings
  ///////////////////////////////////////////////////////////////////
  // The default config settings are hardcoded in the contract
  // This should be called only once during the proxy contract deployment, in the initialize function
  function _setDefaultConfigSettings() internal {
    mapping(ConfigID => ConfigSetting) storage settings = state.configSettings;

    mapping(ConfigID => ConfigValue) storage values1D = state.config1DValues;
    mapping(ConfigID => mapping(bytes32 => ConfigValue)) storage values2D = state.config2DValues;

    bytes32 btc = _currencyToConfig(Currency.BTC);
    bytes32 eth = _currencyToConfig(Currency.ETH);

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
    v2d[btc].isSet = true;
    v2d[btc].val = _centiBeepToConfig(50 * ONE_CENTIBEEP);
    v2d[eth].isSet = true;
    v2d[eth].val = _centiBeepToConfig(4 * ONE_CENTIBEEP);

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

    id = ConfigID.ERC20_ADDRESSES;
    settings[id].typ = ConfigType.ADDRESS2D;

    id = ConfigID.L2_SHARED_BRIDGE_ADDRESS;
    settings[id].typ = ConfigType.ADDRESS;

    id = ConfigID.MAINTENANCE_MARGIN_TIER_01;
    settings[id].typ = ConfigType.BYTE322D;
    v2d = values2D[id];
    v2d[btc].isSet = true;
    v2d[btc].val = _getMaintenanceMarginBytes32(10_0000, 75);
    v2d[eth].isSet = true;
    v2d[eth].val = _getMaintenanceMarginBytes32(100_0000, 75);

    id = ConfigID.MAINTENANCE_MARGIN_TIER_02;
    settings[id].typ = ConfigType.BYTE322D;
    v2d = values2D[id];
    v2d[btc].isSet = true;
    v2d[btc].val = _getMaintenanceMarginBytes32(50_0000, 125);
    v2d[eth].isSet = true;
    v2d[eth].val = _getMaintenanceMarginBytes32(500_0000, 125);

    id = ConfigID.MAINTENANCE_MARGIN_TIER_03;
    settings[id].typ = ConfigType.BYTE322D;
    v2d = values2D[id];
    v2d[btc].isSet = true;
    v2d[btc].val = _getMaintenanceMarginBytes32(100_0000, 175);
    v2d[eth].isSet = true;
    v2d[eth].val = _getMaintenanceMarginBytes32(1000_0000, 175);

    // ADMIN_FEE_SUB_ACCOUNT_ID
    id = ConfigID.ADMIN_FEE_SUB_ACCOUNT_ID;
    settings[id].typ = ConfigType.UINT;

    // ADMIN_LIQUIDATION_SUB_ACCOUNT_ID
    id = ConfigID.ADMIN_LIQUIDATION_SUB_ACCOUNT_ID;
    settings[id].typ = ConfigType.UINT;
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

    id = ConfigID.WITHDRAWAL_FEE;
    settings[id].typ = ConfigType.UINT;
    values1D[id].isSet = true;
    values1D[id].val = _uintToConfig(DEFAULT_WITHDRAWAL_FEE_USD * _getBalanceMultiplier(Currency.USD));

    // MAINTENANCE MARGIN TIERS
    uint hi = uint(ConfigID.MAINTENANCE_MARGIN_TIER_12);
    for (uint i = uint(ConfigID.MAINTENANCE_MARGIN_TIER_01); i <= hi; i++) {
      settings[ConfigID(i)].typ = ConfigType.BYTE322D;
    }

    // INSURANCE FUND ID
    id = ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID;
    settings[id].typ = ConfigType.UINT2D;

    // BRIDGING PARTNER ADDRESSES
    id = ConfigID.BRIDGING_PARTNER_ADDRESSES;
    settings[id].typ = ConfigType.BOOL2D;
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
