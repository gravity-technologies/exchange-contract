pragma solidity ^0.8.20;

import "../api/ConfigContract.sol";
import "../api/signature/generated/OracleSig.sol";
import "../interfaces/IFundingConfig.sol";
import "../types/DataStructure.sol";
import "../common/Error.sol";

contract FundingConfigFacet is IFundingConfig, ConfigContract {
  function updateFundingInfo(
    int64 timestamp,
    uint64 txID,
    AssetFundingInfo[] calldata fundingInfos,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    if (!_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer))) revert NotConfigAddress();

    // ---------- Signature Verification -----------
    bytes32 hash = hashUpdateFundingInfo(fundingInfos, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    // ------- End of Signature Verification -------

    for (uint i; i < fundingInfos.length; ++i) {
      AssetFundingInfo calldata info = fundingInfos[i];
      state.fundingConfigs[info.asset] = FundingInfo({
        updateTime: info.updateTime,
        fundingRateHighCentiBeeps: info.fundingRateHighCentiBeeps,
        fundingRateLowCentiBeeps: info.fundingRateLowCentiBeeps,
        intervalHours: info.intervalHours
      });
    }
  }
}
