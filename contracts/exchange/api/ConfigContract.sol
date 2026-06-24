pragma solidity ^0.8.20;

import "./BaseContract.sol";
import "../types/DataStructure.sol";
import "./signature/generated/ConfigSig.sol";
import {ConfigID, FeatureFlagID, ConfigTimelockRule as Rule} from "../types/DataStructure.sol";

import {L2ContractHelper} from "../../../lib/era-contracts/l2-contracts/contracts/L2ContractHelper.sol";
// IConfig implemented in ConfigFacet to avoid exposing config selectors from the base

struct ConfigProofMessage {
  uint256 blockTimestamp;
  uint256 configVersion;
  bytes4 selector;
  bytes data;
}

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
///  - ConfigEntry's are represented as bytes32, which can be converted to other types
///    using the conversion functions defined below. They are interpreted by looking only
///    at the lower n bytes necessary for the type(e.g. n=8 for uint64), and any upper bytes
///    are ignored. This is why unsafe casting is used in the conversion functions
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
abstract contract ConfigContract is BaseContract {
  using BIMath for BI;

  // --------------- Constants ---------------
  int32 private constant ONE_CENTIBEEP = 1;
  int32 private constant ONE_BEEP = 100;
  int32 private constant ONE_PERCENT = 10000;
  uint64 private constant ONE_HUNDRED_PERCENT = 1000000;
  // The default fallback value which is a zero value array
  bytes32 internal constant DEFAULT_CONFIG_ENTRY = bytes32(uint256(0));
  uint64 internal constant ONE_WEEK_NANOS = 7 * 24 * 60 * 60 * 1e9;

  event ConfigUpdateMessageSent(uint256 configVersion, bytes4 selector, bytes data);

  ///////////////////////////////////////////////////////////////////
  /// Config Accessors
  ///////////////////////////////////////////////////////////////////

  // unsafe casting here is expected, as the byte32 value represents an signed integer
  function _configToInt(bytes32 v) internal pure returns (int64) {
    return int64(SafeCast.toUint64(uint256(v)));
  }

  function _getIntConfig(ConfigID key) internal view returns (int64, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (_configToInt(c.val), c.isSet);
  }

  // unsafe casting here is expected, as the byte32 value represents an signed integer
  function _centiBeepToConfig(int32 v) internal pure returns (bytes32) {
    return bytes32(uint256(uint32(v)));
  }

  // unsafe casting here is expected, as the byte32 value represents an signed integer
  function _configToCentibeep(bytes32 v) internal pure returns (int32) {
    return int32(uint32(uint256(v)));
  }

  // unsafe casting here is expected, as the byte32 value represents an signed integer
  function _getCentibeepConfig(ConfigID key) internal view returns (int32, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (_configToCentibeep(c.val), c.isSet);
  }

  function _getCentibeepConfig2D(ConfigID key, bytes32 subKey) internal view returns (int32, bool) {
    ConfigValue storage c = state.config2DValues[key][subKey];
    if (!c.isSet) {
      c = state.config2DValues[key][DEFAULT_CONFIG_ENTRY];
    }
    return (_configToCentibeep(c.val), c.isSet);
  }

  function _configToUint(bytes32 v) internal pure returns (uint64) {
    return uint64(uint(v));
  }

  function _getUintConfig(ConfigID key) internal view returns (uint64, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (_configToUint(c.val), c.isSet);
  }

  function _getTradingFeeSubAccount(bool isLiquidation) internal view returns (SubAccount storage, bool) {
    if (isLiquidation) {
      return _getInsuranceFundSubAccount();
    } else {
      return _getAdminFeeSubAccount();
    }
  }

  function _getInsuranceFundSubAccount() internal view returns (SubAccount storage, bool) {
    return _getSubAccountFromUintConfig(ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID);
  }

  function _getAdminFeeSubAccount() internal view returns (SubAccount storage, bool) {
    return _getSubAccountFromUintConfig(ConfigID.ADMIN_FEE_SUB_ACCOUNT_ID);
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
    return (_configToUint(c.val), c.isSet);
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

  function _getBoolConfig(ConfigID key) internal view returns (bool) {
    return state.config1DValues[key].val == TRUE_BYTES32;
  }

  function _currencyToConfig(uint8 v) internal pure returns (bytes32) {
    return bytes32(uint256(v));
  }

  function _addressToConfig(address v) internal pure returns (bytes32) {
    return bytes32(uint(uint160(v)));
  }

  // https://ethereum.stackexchange.com/questions/50914/convert-bytes32-to-address
  function _configToAddress(bytes32 v) internal pure returns (address) {
    return address(uint160(uint(v)));
  }

  function _getAddressConfig(ConfigID key) internal view returns (address, bool) {
    ConfigValue storage c = state.config1DValues[key];
    return (_configToAddress(c.val), c.isSet);
  }

  function _getAddressConfig2D(ConfigID key, bytes32 subKey) internal view returns (address, bool) {
    ConfigValue storage c = state.config2DValues[key][subKey];
    if (!c.isSet) {
      c = state.config2DValues[key][DEFAULT_CONFIG_ENTRY];
    }
    return (_configToAddress(c.val), c.isSet);
  }

  function _sendConfigProofMessageToL1(bytes memory data) internal {
    L2ContractHelper.sendMessageToL1(
      abi.encode(
        ConfigProofMessage({
          blockTimestamp: block.timestamp,
          configVersion: state.configVersion,
          selector: msg.sig,
          data: data
        })
      )
    );
    emit ConfigUpdateMessageSent(state.configVersion, msg.sig, data);
  }

  function _isUserAccount(address account) internal view returns (bool) {
    return !_isBridgingPartnerAccount(account) && !_isInternalAccount(account);
  }

  function _isBridgingPartnerAccount(address account) internal view returns (bool) {
    return _getBoolConfig2D(ConfigID.BRIDGING_PARTNER_ADDRESSES, _addressToConfig(account));
  }

  function _isWithdrawalFeeExempt(address account) internal view returns (bool) {
    return _getBoolConfig2D(ConfigID.WITHDRAWAL_FEE_EXEMPT_ACCOUNTS, _addressToConfig(account));
  }

  function _isInternalAccount(address account) internal view returns (bool) {
    (SubAccount storage insuranceFund, bool isInsuranceFundSet) = _getInsuranceFundSubAccount();
    if (isInsuranceFundSet && insuranceFund.accountID == account) {
      return true;
    }

    (SubAccount storage feeSubAcc, bool isFeeSubAccIdSet) = _getAdminFeeSubAccount();
    if (isFeeSubAccIdSet && feeSubAcc.accountID == account) {
      return true;
    }

    return false;
  }

  function _setConfigValue(ConfigID key, bytes32 subKey, bytes32 value, ConfigSetting storage settings) internal {
    if (key == ConfigID.BRIDGING_PARTNER_ADDRESSES) {
      address partnerAddress = _configToAddress(subKey);
      _validateBridgingPartnerChange(partnerAddress);
      if (value == TRUE_BYTES32) {
        addAddress(state.bridgingPartners, partnerAddress);
      } else {
        removeAddress(state.bridgingPartners, partnerAddress, false);
      }
    } else if (key == ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID || key == ConfigID.ADMIN_FEE_SUB_ACCOUNT_ID) {
      _validateInternalSubAccountChange(_configToUint(value));
    } else if (key == ConfigID.ERC20_ADDRESSES) {
      _addErc20Currency(uint8(uint(subKey)));
    }

    ConfigValue storage config = _is2DConfig(settings) ? state.config2DValues[key][subKey] : state.config1DValues[key];
    config.isSet = true;
    config.val = value;
  }

  function _addErc20Currency(uint8 currency) internal {
    // Base spot currencies are always included; don't store them
    if (currency == CCY_USDT || currency == CCY_USDC || currency == CCY_ETH) return;
    // After deletion of the closed Currency enum, the runtime-registry check is the only
    // way to reject junk subKeys. The currency must have been registered via addCurrency
    // before its ERC20 address can be configured.
    require(_currencyIsRegistered(currency), "currency not registered");
    // Skip if already tracked (e.g. re-setting the same ERC20 address)
    uint8[] storage stored = state.erc20Currencies;
    for (uint i; i < stored.length; ++i) {
      if (stored[i] == currency) return;
    }
    stored.push(currency);
  }

  function _validateBridgingPartnerChange(address partnerAddress) internal view {
    Account storage acc = state.accounts[partnerAddress];
    if (acc.id == address(0)) {
      // setting acc to a non-existent account is allowed because the account
      // may be created in the future, and newly created account has 0 value
      return;
    }
    Account storage partnerAccount = _requireAccount(partnerAddress);
    _requireAccountNoBalance(partnerAccount);
    require(partnerAccount.subAccounts.length == 0, "partner account has subaccounts");
  }

  function _validateInternalSubAccountChange(uint64 newSubAccountId) internal view {
    SubAccount storage newSubAcc = _requireSubAccount(newSubAccountId);
    if (_isInternalAccount(newSubAcc.accountID)) {
      // if the new subaccount is already under an internal account
      // this won't decrease the total client equity, therefore it's allowed
      return;
    }

    Account storage account = _requireAccount(newSubAcc.accountID);
    require(
      _getFundingAccountEquityInUSDT(account).toInt64(_getBalanceDecimal(CCY_USDT)) == 0,
      "new internal acc must have 0 value"
    );
  }

  function _initializeNewConfigSettingIfNeeded() internal {
    ConfigSetting storage setting = state.configSettings[ConfigID.FEATURE_FLAGS];
    if (setting.typ == ConfigType.UNSPECIFIED) {
      setting.typ = ConfigType.BOOL2D;
      Rule[] storage rules = setting.rules;
      // This config does not have timelock as it is controlled by GRVT
      ConfigTimelockRule storage rule = rules.push();
      rule.lockDuration = 0;
      rule.deltaPositive = 0;
      rule.deltaNegative = 0;
    }

    setting = state.configSettings[ConfigID.EIP712_CHAIN_ID];
    if (setting.typ == ConfigType.UNSPECIFIED) {
      setting.typ = ConfigType.BOOL2D;
      Rule[] storage rules = setting.rules;
      // This config does not have timelock as it is controlled by GRVT
      ConfigTimelockRule storage rule = rules.push();
      rule.lockDuration = 0;
      rule.deltaPositive = 0;
      rule.deltaNegative = 0;
    }

    setting = state.configSettings[ConfigID.WITHDRAWAL_FEE_EXEMPT_ACCOUNTS];
    if (setting.typ == ConfigType.UNSPECIFIED) {
      setting.typ = ConfigType.BOOL2D;
      Rule[] storage rules = setting.rules;
      // This config does not have timelock as it is controlled by GRVT
      ConfigTimelockRule storage rule = rules.push();
      rule.lockDuration = 0;
      rule.deltaPositive = 0;
      rule.deltaNegative = 0;
    }
  }

  function _requireValidConfigSetting(ConfigID key, bytes32 subKey) internal view returns (ConfigSetting storage) {
    ConfigSetting storage setting = state.configSettings[key];
    ConfigType typ = setting.typ;
    require(typ != ConfigType.UNSPECIFIED, "config not found 404");

    // For 1D config settings, subKey must be 0
    // For 2D config, there's no such restriction
    // 2D configs are always placed at odd indices in the enum. See ConfigID
    require(_is2DConfig(setting) || subKey == 0, "invalid 1D subKey");
    return setting;
  }

  function _is2DConfig(ConfigSetting storage settings) internal view returns (bool) {
    return uint256(settings.typ) % 2 == 0;
  }

  /// @dev Find the timelock duration in nanoseconds that corresponds to the change in value
  /// Expect the timelocks duration should be in increasing order of delta change and timelock duration
  function _getLockDuration(ConfigID key, bytes32 subKey, bytes32 newVal) internal view returns (int64) {
    ConfigType typ = state.configSettings[key].typ;
    require(typ != ConfigType.UNSPECIFIED, "404");

    Rule[] storage rules = state.configSettings[key].rules;
    // If there are no rules for the config setting, return 0 (no lock duration)
    if (rules.length == 0) {
      return 0;
    }

    if (key == ConfigID.BRIDGING_PARTNER_ADDRESSES) {
      return newVal == TRUE_BYTES32 ? int64(0) : rules[0].lockDuration;
    }

    if (key == ConfigID.ORACLE_ADDRESS) {
      return rules[0].lockDuration;
    }

    // always allow decreasing min fee immediately
    if (
      key == ConfigID.FUTURES_MAKER_FEE_MINIMUM ||
      key == ConfigID.FUTURES_TAKER_FEE_MINIMUM ||
      key == ConfigID.OPTIONS_MAKER_FEE_MINIMUM ||
      key == ConfigID.OPTIONS_TAKER_FEE_MINIMUM
    ) {
      (int32 currentVal, bool ok) = _getCentibeepConfig2D(key, subKey);
      if (!ok) {
        return 0;
      }
      int32 newValInt = _configToCentibeep(newVal);
      if (newValInt < currentVal) {
        return 0;
      }
    }

    if (key == ConfigID.WITHDRAWAL_FEE) {
      (uint64 currentVal, bool ok) = _getUintConfig(ConfigID.WITHDRAWAL_FEE);
      if (!ok) {
        return 0;
      }
      uint64 newValInt = _configToUint(newVal);
      if (newValInt < currentVal) {
        return 0;
      }
    }

    // These 4 config types are not numerical and have a fixed lock duration
    // There should be only 1 timelock rule for these config types
    if (typ == ConfigType.ADDRESS) {
      (, bool isSet) = _getAddressConfig(key);
      if (isSet) return rules[0].lockDuration;
      return 0;
    }
    if (typ == ConfigType.ADDRESS2D) {
      (address currentAddr, bool isSet) = _getAddressConfig2D(key, subKey);
      if (isSet) {
        // Allow setConfig calls that don't change the value
        if (_configToAddress(newVal) == currentAddr) return 0;
        return rules[0].lockDuration;
      }
      return 0;
    }
    if (typ == ConfigType.BOOL) {
      bool oldVal = _getBoolConfig(key);
      if (oldVal) return rules[0].lockDuration;
      return 0;
    }
    if (typ == ConfigType.BOOL2D) {
      bool oldVal = _getBoolConfig2D(key, subKey);
      if (oldVal) return rules[0].lockDuration;
      return 0;
    }

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
      if (isSet) return _getIntConfigLockDuration(key, int64(oldVal), _configToCentibeep(newVal));
      return 0;
    }
    if (typ == ConfigType.CENTIBEEP2D) {
      (int32 oldVal, bool isSet) = _getCentibeepConfig2D(key, subKey);
      if (isSet) return _getIntConfigLockDuration(key, int64(oldVal), _configToCentibeep(newVal));
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
    // No change in value, no lock duration
    if (newVal == oldVal) return 0;

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
        if (SafeCast.toUint64(SafeCast.toUint256(int(oldVal - newVal))) <= rules[i].deltaNegative)
          return rules[i].lockDuration;
      return rules[rulesLen - 1].lockDuration; // Default to last timelock rule
    } else if (newVal > oldVal) {
      for (uint i; i < rulesLen; ++i)
        if (SafeCast.toUint64(SafeCast.toUint256(int(newVal - oldVal))) <= rules[i].deltaPositive)
          return rules[i].lockDuration;
      return rules[rulesLen - 1].lockDuration; // Default to last timelock rule
    }
    return 0; // no change = no timelock
  }

  ///////////////////////////////////////////////////////////////////
  /// Default Config Settings
  ///////////////////////////////////////////////////////////////////
  // The default config settings are hardcoded in the contract
  // This should be called only once during the proxy contract deployment, in the initialize function
  function _setDefaultConfigSettings() internal {
    mapping(ConfigID => ConfigSetting) storage settings = state.configSettings;

    Rule[] storage rules;
    ConfigID id;

    ///////////////////////////////////////////////////////////////////
    /// Simple Cross Margin
    ///////////////////////////////////////////////////////////////////

    // SIMPLE_CROSS_FUTURES_INITIAL_MARGIN
    id = ConfigID.SIMPLE_CROSS_FUTURES_INITIAL_MARGIN;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    rules = settings[id].rules;
    ConfigTimelockRule storage rule = rules.push();
    rule.lockDuration = int64(2 * ONE_WEEK_NANOS);
    rule.deltaPositive = 0;
    rule.deltaNegative = 0;

    ///////////////////////////////////////////////////////////////////
    /// ADMIN addresses
    ///////////////////////////////////////////////////////////////////

    // ORACLE_ADDRESS
    id = ConfigID.ORACLE_ADDRESS;
    settings[id].typ = ConfigType.BOOL2D;
    rules = settings[id].rules;
    rule = rules.push();
    rule.lockDuration = int64(2 * ONE_WEEK_NANOS);
    rule.deltaPositive = 0;
    rule.deltaNegative = 0;

    // CONFIG_ADDRESS
    id = ConfigID.CONFIG_ADDRESS;
    settings[id].typ = ConfigType.BOOL2D;
    rules = settings[id].rules;
    // This config does not have timelock as it is controlled by GRVT
    rule = rules.push();
    rule.lockDuration = 0;
    rule.deltaPositive = 0;
    rule.deltaNegative = 0;

    // MARKET_DATA_ADDRESS
    id = ConfigID.MARKET_DATA_ADDRESS;
    settings[id].typ = ConfigType.BOOL2D;
    rules = settings[id].rules;
    // This config does not have timelock as it is controlled by GRVT
    rule = rules.push();
    rule.lockDuration = 0;
    rule.deltaPositive = 0;
    rule.deltaNegative = 0;

    ///////////////////////////////////////////////////////////////////
    /// Smart Contract Addresses
    ///////////////////////////////////////////////////////////////////
    id = ConfigID.ERC20_ADDRESSES;
    settings[id].typ = ConfigType.ADDRESS2D;
    rules = settings[id].rules;
    // This config is immutable once set
    rule = rules.push();
    rule.lockDuration = type(int64).max;
    rule.deltaPositive = 0;
    rule.deltaNegative = 0;

    id = ConfigID.L2_SHARED_BRIDGE_ADDRESS;
    settings[id].typ = ConfigType.ADDRESS;
    rules = settings[id].rules;
    // This config is immutable once set
    rule = rules.push();
    rule.lockDuration = type(int64).max;
    rule.deltaPositive = 0;
    rule.deltaNegative = 0;

    // ADMIN_FEE_SUB_ACCOUNT_ID
    id = ConfigID.ADMIN_FEE_SUB_ACCOUNT_ID;
    settings[id].typ = ConfigType.UINT;
    rules = settings[id].rules;
    // This config does not have timelock as it is controlled by GRVT
    rule = rules.push();
    rule.lockDuration = 0;
    rule.deltaPositive = 0;
    rule.deltaNegative = 0;

    // INSURANCE_FUND_SUB_ACCOUNT_ID
    id = ConfigID.INSURANCE_FUND_SUB_ACCOUNT_ID;
    settings[id].typ = ConfigType.UINT;
    rules = settings[id].rules;
    // This config does not have timelock as it is controlled by GRVT
    rule = rules.push();
    rule.lockDuration = 0;
    rule.deltaPositive = 0;
    rule.deltaNegative = 0;

    ///////////////////////////////////////////////////////////////////
    /// Funding rate settings
    ///////////////////////////////////////////////////////////////////

    // FUNDING_RATE_HIGH
    id = ConfigID.FUNDING_RATE_HIGH;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    rules = settings[id].rules;
    rule = rules.push();
    rule.lockDuration = int64(2 * ONE_WEEK_NANOS);
    rule.deltaPositive = 0;
    rule.deltaNegative = ONE_HUNDRED_PERCENT;

    // FUNDING_RATE_LOW
    id = ConfigID.FUNDING_RATE_LOW;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    rules = settings[id].rules;
    rule = rules.push();
    rule.lockDuration = int64(2 * ONE_WEEK_NANOS);
    rule.deltaPositive = 0;
    rule.deltaNegative = ONE_HUNDRED_PERCENT;

    ///////////////////////////////////////////////////////////////////
    /// Fee settings
    ///////////////////////////////////////////////////////////////////

    // FUTURES_MAKER_FEE_MINIMUM
    id = ConfigID.FUTURES_MAKER_FEE_MINIMUM;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    rules = settings[id].rules;
    rule = rules.push();
    rule.lockDuration = int64(2 * ONE_WEEK_NANOS);
    rule.deltaPositive = 0;
    rule.deltaNegative = ONE_HUNDRED_PERCENT;

    // FUTURES_TAKER_FEE_MINIMUM
    id = ConfigID.FUTURES_TAKER_FEE_MINIMUM;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    rules = settings[id].rules;
    rule = rules.push();
    rule.lockDuration = int64(2 * ONE_WEEK_NANOS);
    rule.deltaPositive = 0;
    rule.deltaNegative = ONE_HUNDRED_PERCENT;

    // OPTIONS_MAKER_FEE_MINIMUM
    id = ConfigID.OPTIONS_MAKER_FEE_MINIMUM;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    rules = settings[id].rules;
    rule = rules.push();
    rule.lockDuration = int64(2 * ONE_WEEK_NANOS);
    rule.deltaPositive = 0;
    rule.deltaNegative = ONE_HUNDRED_PERCENT;

    // OPTIONS_TAKER_FEE_MINIMUM
    id = ConfigID.OPTIONS_TAKER_FEE_MINIMUM;
    settings[id].typ = ConfigType.CENTIBEEP2D;
    rules = settings[id].rules;
    rule = rules.push();
    rule.lockDuration = int64(2 * ONE_WEEK_NANOS);
    rule.deltaPositive = 0;
    rule.deltaNegative = ONE_HUNDRED_PERCENT;

    id = ConfigID.WITHDRAWAL_FEE;
    settings[id].typ = ConfigType.UINT;
    rules = settings[id].rules;
    rule = rules.push();
    rule.lockDuration = int64(2 * ONE_WEEK_NANOS);
    rule.deltaPositive = 0;
    rule.deltaNegative = ONE_HUNDRED_PERCENT;

    // BRIDGING PARTNER ADDRESSES
    id = ConfigID.BRIDGING_PARTNER_ADDRESSES;
    settings[id].typ = ConfigType.BOOL2D;
    rules = settings[id].rules;
    rule = rules.push();
    rule.lockDuration = int64(2 * ONE_WEEK_NANOS);
    rule.deltaPositive = 0;
    rule.deltaNegative = ONE_HUNDRED_PERCENT;
  }
}
