pragma solidity ^0.8.20;

import "../api/ConfigContract.sol";
import "../interfaces/IConfig.sol";

contract ConfigFacet is IConfig, ConfigContract {
  /**
   * @dev Sends a message to L1 containing the latest config version.
   * This function is used to prove that no config updates have occurred
   * since the config operation with the version sent to L1.
   * Note that the timestamp used is the block timestamp at the time of the call
   * as opposed to cluster timestamp in other config update operations.
   * This is sufficient to prove that no config updates have occurred before a certain
   * L2 block timestamp.
   */
  function proveConfig() external override {
    _sendConfigProofMessageToL1("");
  }

  function initializeConfig(
    int64 timestamp,
    uint64 txID,
    InitializeConfigItem[] calldata items,
    Signature calldata sig
  ) external override onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequenceInitializeConfig(timestamp, txID);

    // ---------- Signature Verification -----------
    require(sig.signer == state.initializeConfigSigner, "not initializeConfig signer");
    _preventReplay(hashInitializeConfig(items, sig.nonce, sig.expiration), sig);
    // ------- End of Signature Verification -------

    for (uint256 i = 0; i < items.length; i++) {
      ConfigID key = items[i].key;
      bytes32 subKey = items[i].subKey;
      bytes32 value = items[i].value;

      ConfigSetting storage setting = _requireValidConfigSetting(key, subKey);
      _setConfigValue(key, subKey, value, setting);
    }

    state.configVersion++;
    _sendConfigProofMessageToL1(abi.encode(timestamp, items));
  }

  function scheduleConfig(
    int64 timestamp,
    uint64 txID,
    ConfigID key,
    bytes32 subKey,
    bytes32 value,
    Signature calldata sig
  ) external override onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    // ---------- Signature Verification -----------
    require(_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer)), "not config address");

    _preventReplay(hashScheduleConfig(key, subKey, value, sig.nonce, sig.expiration), sig);
    // ------- End of Signature Verification -------

    ConfigSetting storage setting = _requireValidConfigSetting(key, subKey);
    ConfigSchedule storage sched = setting.schedules[subKey];
    sched.lockEndTime = timestamp + _getLockDuration(key, subKey, value);

    state.configVersion++;
    _sendConfigProofMessageToL1(abi.encode(timestamp, key, subKey, value));
  }

  function setConfig(
    int64 timestamp,
    uint64 txID,
    ConfigID key,
    bytes32 subKey,
    bytes32 value,
    Signature calldata sig
  ) external override onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);

    require(_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer)), "not config address");

    // ---------- Signature Verification -----------
    _preventReplay(hashSetConfig(key, subKey, value, sig.nonce, sig.expiration), sig);
    // ------- End of Signature Verification -------

    _initializeNewConfigSettingIfNeeded();
    ConfigSetting storage setting = _requireValidConfigSetting(key, subKey);

    int64 lockDuration = _getLockDuration(key, subKey, value);
    if (lockDuration > 0) {
      int64 lockEndTime = setting.schedules[subKey].lockEndTime;
      require(lockEndTime > 0 && lockEndTime <= timestamp, "not scheduled or still locked");
    }

    _setConfigValue(key, subKey, value, setting);

    // Must delete the schedule after the config is set (to prevent replays)
    delete setting.schedules[subKey];

    state.configVersion++;
    _sendConfigProofMessageToL1(abi.encode(timestamp, key, subKey, value));
  }
}
