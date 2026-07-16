// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GetterFacet} from "../../contracts/exchange/facets/GetterFacet.sol";
import {ConfigID, ConfigType, ConfigSetting, ConfigValue} from "../../contracts/exchange/types/DataStructure.sol";
import {CCY_USDT, CCY_ETH} from "../../contracts/exchange/types/Enum.sol";

// The `Currency` enum was removed in d63b209 (currencies are plain uint8 IDs via the runtime
// registry). ETH (4) is a named constant in Enum.sol; BTC/SOL are arbitrary distinct IDs used
// only as config subKeys in these round-trip/fallback tests.
uint8 constant CCY_BTC = 5;
uint8 constant CCY_SOL = 6;

/// @dev Test harness over GetterFacet. GetterFacet -> RiskCheck -> MarginConfigContractGetter
/// -> ConfigContract -> BaseContract, so it inherits every internal config helper plus the new
/// typed MAM getters. We expose the internal config plumbing so we can drive the same flow
/// `ConfigFacet.setConfig` uses (register settings, check lock duration, write value) without
/// the EIP-712 signature machinery — matching the existing Foundry harness convention.
contract MAMConfigHarness is GetterFacet {
  function init(address admin) external initializer {
    __ReentrancyGuard_init();
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
    // Fresh-deploy defaults only. The MAM configs (TRADE-1127) are registered by
    // _initializeNewConfigSettingIfNeeded, which production runs at the top of every
    // ConfigFacet.setConfig — mirrored here by setConfigDirect below.
    _setDefaultConfigSettings();
  }

  /// @dev Exposes the upgrade-path registrar to prove it is idempotent and registers the
  /// MAM slots on an already-deployed diamond (without re-running the full deploy initializer).
  function initializeNewConfigSettingIfNeeded() external {
    _initializeNewConfigSettingIfNeeded();
  }

  function getConfigType(ConfigID id) external view returns (ConfigType) {
    return state.configSettings[id].typ;
  }

  function getRulesLength(ConfigID id) external view returns (uint256) {
    return state.configSettings[id].rules.length;
  }

  function lockDuration(ConfigID id, bytes32 subKey, bytes32 value) external view returns (int64) {
    return _getLockDuration(id, subKey, value);
  }

  /// @dev Mirrors the core of `ConfigFacet.setConfig`: require a valid setting, enforce the
  /// timelock gate (no schedule needed when lockDuration == 0), then persist the value.
  /// Reverts "not scheduled or still locked" if the config has a positive lock and no schedule —
  /// i.e. a green run here proves the config is settable instantly with no prior scheduleConfig.
  function setConfigDirect(int64 timestamp, ConfigID key, bytes32 subKey, bytes32 value) external {
    _initializeNewConfigSettingIfNeeded();
    ConfigSetting storage setting = _requireValidConfigSetting(key, subKey);
    int64 dur = _getLockDuration(key, subKey, value);
    if (dur > 0) {
      int64 lockEndTime = setting.schedules[subKey].lockEndTime;
      require(lockEndTime > 0 && lockEndTime <= timestamp, "not scheduled or still locked");
    }
    _setConfigValue(key, subKey, value, setting);
    delete setting.schedules[subKey];
  }

  function currencyToConfig(uint8 c) external pure returns (bytes32) {
    return _currencyToConfig(c);
  }
}

contract MAMConfigTest is Test {
  MAMConfigHarness internal exchange;

  address internal constant ADMIN = address(0xA11CE);
  int64 internal constant TS = 1_000_000;

  function setUp() public {
    exchange = new MAMConfigHarness();
    exchange.init(ADMIN);
  }

  // ------------------------------------------------------------------
  // Ordinal alignment: the contract enum value MUST equal the platform
  // capnp field number (raw uint8 pass-through in the encoder). A drift
  // here silently writes to the wrong slot / stalls the chain.
  // ------------------------------------------------------------------

  function testOrdinalAlignment() public {
    assertEq(uint8(ConfigID.SPOT_TAKER_FEE_MINIMUM), 20, "SPOT_TAKER_FEE_MINIMUM");
    assertEq(uint8(ConfigID.SPOT_MAKER_FEE_MINIMUM), 21, "SPOT_MAKER_FEE_MINIMUM");
    assertEq(uint8(ConfigID.REPAYMENT_FLOOR_RATIO), 22, "REPAYMENT_FLOOR_RATIO");
    assertEq(uint8(ConfigID.LIQUIDATION_REPAYMENT_DIVISOR), 23, "LIQUIDATION_REPAYMENT_DIVISOR");
    assertEq(uint8(ConfigID.AUTOMATED_REPAYMENT_DIVISOR), 24, "AUTOMATED_REPAYMENT_DIVISOR");
    assertEq(uint8(ConfigID.MANUAL_REPAYMENT_DIVISOR), 25, "MANUAL_REPAYMENT_DIVISOR");
    assertEq(uint8(ConfigID.SPOT_ASSET_CVR), 26, "SPOT_ASSET_CVR");
    assertEq(uint8(ConfigID.SPOT_ASSET_CDR), 27, "SPOT_ASSET_CDR");
    assertEq(uint8(ConfigID.SPOT_ASSET_MBA), 28, "SPOT_ASSET_MBA");
    assertEq(uint8(ConfigID.DEFAULT_DISABLED_CURRENCIES), 29, "DEFAULT_DISABLED_CURRENCIES");
    assertEq(uint8(ConfigID.SPOT_ASSET_CDC), 30, "SPOT_ASSET_CDC");
  }

  // Spot-check the unchanged tail of the existing enum, so an accidental
  // insertion before the MAM block (which would renumber everything) is caught.
  function testExistingOrdinalsUnchanged() public {
    assertEq(uint8(ConfigID.FEATURE_FLAGS), 18, "FEATURE_FLAGS");
    assertEq(uint8(ConfigID.EIP712_CHAIN_ID), 19, "EIP712_CHAIN_ID");
  }

  // ------------------------------------------------------------------
  // Config types registered correctly, with NO timelock rules.
  // ------------------------------------------------------------------

  function testConfigTypesRegistered() public {
    // Not registered at fresh deploy; the upgrade-path registrar (run by every
    // setConfig in production) registers them.
    assertEq(uint8(exchange.getConfigType(ConfigID.SPOT_ASSET_CVR)), uint8(ConfigType.UNSPECIFIED));
    exchange.initializeNewConfigSettingIfNeeded();
    assertEq(uint8(exchange.getConfigType(ConfigID.REPAYMENT_FLOOR_RATIO)), uint8(ConfigType.CENTIBEEP));
    assertEq(uint8(exchange.getConfigType(ConfigID.LIQUIDATION_REPAYMENT_DIVISOR)), uint8(ConfigType.UINT));
    assertEq(uint8(exchange.getConfigType(ConfigID.AUTOMATED_REPAYMENT_DIVISOR)), uint8(ConfigType.UINT));
    assertEq(uint8(exchange.getConfigType(ConfigID.MANUAL_REPAYMENT_DIVISOR)), uint8(ConfigType.UINT));
    assertEq(uint8(exchange.getConfigType(ConfigID.SPOT_ASSET_CVR)), uint8(ConfigType.CENTIBEEP2D));
    assertEq(uint8(exchange.getConfigType(ConfigID.SPOT_ASSET_CDR)), uint8(ConfigType.UINT2D));
    assertEq(uint8(exchange.getConfigType(ConfigID.SPOT_ASSET_MBA)), uint8(ConfigType.CENTIBEEP2D));
    assertEq(uint8(exchange.getConfigType(ConfigID.DEFAULT_DISABLED_CURRENCIES)), uint8(ConfigType.BOOL2D));
    assertEq(uint8(exchange.getConfigType(ConfigID.SPOT_ASSET_CDC)), uint8(ConfigType.UINT2D));
  }

  function testZeroTimelockRuleRegistered() public {
    // House style: each config gets exactly one explicit zero-lock rule
    // (lockDuration 0 -> instant setConfig, no schedule needed).
    exchange.initializeNewConfigSettingIfNeeded();
    assertEq(exchange.getRulesLength(ConfigID.SPOT_ASSET_CVR), 1);
    assertEq(exchange.getRulesLength(ConfigID.SPOT_ASSET_CDC), 1);
    assertEq(exchange.getRulesLength(ConfigID.SPOT_ASSET_MBA), 1);
    assertEq(exchange.getRulesLength(ConfigID.SPOT_ASSET_CDR), 1);
    assertEq(exchange.getRulesLength(ConfigID.DEFAULT_DISABLED_CURRENCIES), 1);
    assertEq(exchange.getRulesLength(ConfigID.REPAYMENT_FLOOR_RATIO), 1);
    assertEq(exchange.getRulesLength(ConfigID.LIQUIDATION_REPAYMENT_DIVISOR), 1);
    assertEq(exchange.getRulesLength(ConfigID.AUTOMATED_REPAYMENT_DIVISOR), 1);
    assertEq(exchange.getRulesLength(ConfigID.MANUAL_REPAYMENT_DIVISOR), 1);
  }

  function testLockDurationIsZeroForAllMAMConfigs() public {
    exchange.initializeNewConfigSettingIfNeeded();
    bytes32 ethKey = exchange.currencyToConfig(CCY_ETH);
    assertEq(exchange.lockDuration(ConfigID.SPOT_ASSET_CVR, ethKey, _centibeep(900000)), 0);
    assertEq(exchange.lockDuration(ConfigID.SPOT_ASSET_CDC, ethKey, _uint(1_000_000)), 0);
    assertEq(exchange.lockDuration(ConfigID.SPOT_ASSET_MBA, ethKey, _centibeep(500000)), 0);
    assertEq(exchange.lockDuration(ConfigID.SPOT_ASSET_CDR, ethKey, _uint(7)), 0);
    assertEq(exchange.lockDuration(ConfigID.DEFAULT_DISABLED_CURRENCIES, ethKey, _bool(true)), 0);
    assertEq(exchange.lockDuration(ConfigID.REPAYMENT_FLOOR_RATIO, bytes32(0), _centibeep(100000)), 0);
    assertEq(exchange.lockDuration(ConfigID.LIQUIDATION_REPAYMENT_DIVISOR, bytes32(0), _uint(2)), 0);
    assertEq(exchange.lockDuration(ConfigID.AUTOMATED_REPAYMENT_DIVISOR, bytes32(0), _uint(3)), 0);
    assertEq(exchange.lockDuration(ConfigID.MANUAL_REPAYMENT_DIVISOR, bytes32(0), _uint(4)), 0);
  }

  // ------------------------------------------------------------------
  // Instant setConfig with NO prior scheduleConfig (no timelock).
  // setConfigDirect mirrors setConfig's lock gate; a non-revert proves
  // the value is settable instantly without scheduling.
  // ------------------------------------------------------------------

  function testInstantSetConfigNoSchedule2D() public {
    bytes32 ethKey = exchange.currencyToConfig(CCY_ETH);
    // No scheduleConfig called first; this must succeed.
    exchange.setConfigDirect(TS, ConfigID.SPOT_ASSET_CVR, ethKey, _centibeep(900000));
    (int32 cvr, bool isSet) = exchange.getSpotAssetCVR(CCY_ETH);
    assertTrue(isSet);
    assertEq(cvr, 900000);
  }

  function testInstantSetConfigNoSchedule1D() public {
    exchange.setConfigDirect(TS, ConfigID.REPAYMENT_FLOOR_RATIO, bytes32(0), _centibeep(123456));
    (int32 ratio, bool isSet) = exchange.getRepaymentFloorRatio();
    assertTrue(isSet);
    assertEq(ratio, 123456);
  }

  // ------------------------------------------------------------------
  // Round-trip through each typed getter / decoder.
  // ------------------------------------------------------------------

  function testCVRRoundTrip() public {
    bytes32 ethKey = exchange.currencyToConfig(CCY_ETH);
    exchange.setConfigDirect(TS, ConfigID.SPOT_ASSET_CVR, ethKey, _centibeep(850000));
    (int32 cvr, bool isSet) = exchange.getSpotAssetCVR(CCY_ETH);
    assertTrue(isSet);
    assertEq(cvr, 850000);
  }

  function testMBARoundTrip() public {
    bytes32 btcKey = exchange.currencyToConfig(CCY_BTC);
    exchange.setConfigDirect(TS, ConfigID.SPOT_ASSET_MBA, btcKey, _centibeep(750000));
    (int32 mba, bool isSet) = exchange.getSpotAssetMBA(CCY_BTC);
    assertTrue(isSet);
    assertEq(mba, 750000);
  }

  function testDefaultDisabledCurrencyRoundTrip() public {
    bytes32 ethKey = exchange.currencyToConfig(CCY_ETH);
    assertFalse(exchange.getDefaultDisabledCurrency(CCY_ETH));
    exchange.setConfigDirect(TS, ConfigID.DEFAULT_DISABLED_CURRENCIES, ethKey, _bool(true));
    assertTrue(exchange.getDefaultDisabledCurrency(CCY_ETH));
  }

  /// @dev Mirrors the platform's GetBoolCfg2D: a currency without an explicit row falls
  /// back to the catchall DEFAULT_CONFIG_ENTRY (subKey 0) row, and an explicit row wins
  /// over the catchall.
  function testDefaultDisabledCurrencyFallsBackToCatchall() public {
    // No rows at all: false.
    assertFalse(exchange.getDefaultDisabledCurrency(CCY_ETH));

    // Catchall row set to true: every currency without an explicit row reads true.
    exchange.setConfigDirect(TS, ConfigID.DEFAULT_DISABLED_CURRENCIES, bytes32(0), _bool(true));
    assertTrue(exchange.getDefaultDisabledCurrency(CCY_ETH));
    assertTrue(exchange.getDefaultDisabledCurrency(CCY_USDT));

    // Explicit per-currency row wins over the catchall.
    bytes32 ethKey = exchange.currencyToConfig(CCY_ETH);
    exchange.setConfigDirect(TS, ConfigID.DEFAULT_DISABLED_CURRENCIES, ethKey, _bool(false));
    assertFalse(exchange.getDefaultDisabledCurrency(CCY_ETH));
    assertTrue(exchange.getDefaultDisabledCurrency(CCY_USDT), "catchall still applies to others");
  }

  function testRepaymentDivisorsRoundTrip() public {
    exchange.setConfigDirect(TS, ConfigID.LIQUIDATION_REPAYMENT_DIVISOR, bytes32(0), _uint(2));
    exchange.setConfigDirect(TS, ConfigID.AUTOMATED_REPAYMENT_DIVISOR, bytes32(0), _uint(3));
    exchange.setConfigDirect(TS, ConfigID.MANUAL_REPAYMENT_DIVISOR, bytes32(0), _uint(4));

    (uint64 lrr, bool lrrSet) = exchange.getLiquidationRepaymentDivisor();
    (uint64 arr, bool arrSet) = exchange.getAutomatedRepaymentDivisor();
    (uint64 mrr, bool mrrSet) = exchange.getManualRepaymentDivisor();

    assertTrue(lrrSet && arrSet && mrrSet);
    assertEq(lrr, 2);
    assertEq(arr, 3);
    assertEq(mrr, 4);
  }

  // ------------------------------------------------------------------
  // CDC: store-only round trip + confirm it is NOT enforced anywhere.
  // ------------------------------------------------------------------

  function testCDCStoreRoundTrip() public {
    bytes32 ethKey = exchange.currencyToConfig(CCY_ETH);
    exchange.setConfigDirect(TS, ConfigID.SPOT_ASSET_CDC, ethKey, _uint(5_000_000));
    (uint64 cap, bool isSet) = exchange.getSpotAssetCDC(CCY_ETH);
    assertTrue(isSet);
    assertEq(cap, 5_000_000);
  }

  /// CDC is store-only: setting a tiny cap must not gate / revert any other action.
  /// We prove "not enforced" by showing a second, unrelated config write succeeds and
  /// the CDC value is purely a stored read with no side effects (no balance, no guard).
  function testCDCNotEnforced() public {
    bytes32 ethKey = exchange.currencyToConfig(CCY_ETH);
    // Set a deliberately tiny CDC cap.
    exchange.setConfigDirect(TS, ConfigID.SPOT_ASSET_CDC, ethKey, _uint(1));
    (uint64 cap, ) = exchange.getSpotAssetCDC(CCY_ETH);
    assertEq(cap, 1);

    // A subsequent CVR write for the same currency is unaffected by the tiny CDC cap
    // (no enforcement path reads CDC to block anything).
    exchange.setConfigDirect(TS, ConfigID.SPOT_ASSET_CVR, ethKey, _centibeep(1000000));
    (int32 cvr, bool cvrSet) = exchange.getSpotAssetCVR(CCY_ETH);
    assertTrue(cvrSet);
    assertEq(cvr, 1000000);

    // Overwriting CDC with a large value also just round-trips; no monotonicity / lock.
    exchange.setConfigDirect(TS, ConfigID.SPOT_ASSET_CDC, ethKey, _uint(type(uint64).max));
    (uint64 cap2, ) = exchange.getSpotAssetCDC(CCY_ETH);
    assertEq(cap2, type(uint64).max);
  }

  // ------------------------------------------------------------------
  // Default fallback (subKey 0 / DEFAULT_CONFIG_ENTRY).
  // ------------------------------------------------------------------

  function testDefaultFallback2D() public {
    // Set only the default entry (subKey 0); a currency with no explicit value reads it.
    exchange.setConfigDirect(TS, ConfigID.SPOT_ASSET_CVR, bytes32(0), _centibeep(800000));

    // BTC has no explicit CVR -> falls back to the default entry.
    (int32 cvr, bool isSet) = exchange.getSpotAssetCVR(CCY_BTC);
    assertTrue(isSet);
    assertEq(cvr, 800000);
  }

  function testExplicitOverridesDefault() public {
    exchange.setConfigDirect(TS, ConfigID.SPOT_ASSET_CVR, bytes32(0), _centibeep(800000));
    bytes32 ethKey = exchange.currencyToConfig(CCY_ETH);
    exchange.setConfigDirect(TS, ConfigID.SPOT_ASSET_CVR, ethKey, _centibeep(950000));

    (int32 ethCvr, ) = exchange.getSpotAssetCVR(CCY_ETH);
    (int32 btcCvr, ) = exchange.getSpotAssetCVR(CCY_BTC);
    assertEq(ethCvr, 950000); // explicit
    assertEq(btcCvr, 800000); // default fallback
  }

  function testUnsetReturnsNotSet() public {
    (int32 cvr, bool isSet) = exchange.getSpotAssetCVR(CCY_SOL);
    assertFalse(isSet);
    assertEq(cvr, 0);
  }

  // ------------------------------------------------------------------
  // Upgrade path: _initializeNewConfigSettingIfNeeded registers the MAM
  // slots idempotently on an already-deployed diamond.
  // ------------------------------------------------------------------

  function testUpgradePathRegistersMAMSlotsIdempotently() public {
    // Fresh deploy: MAM slots not yet registered.
    assertEq(uint8(exchange.getConfigType(ConfigID.SPOT_ASSET_CVR)), uint8(ConfigType.UNSPECIFIED));
    // First run registers with a single zero-lock rule.
    exchange.initializeNewConfigSettingIfNeeded();
    assertEq(uint8(exchange.getConfigType(ConfigID.SPOT_ASSET_CVR)), uint8(ConfigType.CENTIBEEP2D));
    assertEq(uint8(exchange.getConfigType(ConfigID.SPOT_ASSET_CDC)), uint8(ConfigType.UINT2D));
    assertEq(exchange.getRulesLength(ConfigID.SPOT_ASSET_CVR), 1);
    // Re-running must not clobber the typ or push a duplicate rule.
    exchange.initializeNewConfigSettingIfNeeded();
    assertEq(uint8(exchange.getConfigType(ConfigID.SPOT_ASSET_CVR)), uint8(ConfigType.CENTIBEEP2D));
    assertEq(exchange.getRulesLength(ConfigID.SPOT_ASSET_CVR), 1);
    assertEq(exchange.getRulesLength(ConfigID.SPOT_ASSET_CDC), 1);
  }

  // ---------------------------- helpers ----------------------------

  function _centibeep(int32 v) internal pure returns (bytes32) {
    return bytes32(uint256(uint32(v)));
  }

  function _uint(uint64 v) internal pure returns (bytes32) {
    return bytes32(uint256(v));
  }

  function _bool(bool v) internal pure returns (bytes32) {
    return v ? bytes32(uint256(1)) : bytes32(uint256(0));
  }
}
