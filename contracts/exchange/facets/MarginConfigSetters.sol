pragma solidity ^0.8.20;

import "../api/MarginConfigContract.sol";
import "../api/signature/generated/MarginSig.sol";
import "../interfaces/IMarginConfig.sol";
import "../common/Error.sol";

contract MarginConfigSettersFacet is IMarginConfig, MarginConfigContractGetter {
  uint private constant _MAX_M_MARGIN_TIERS = 12;
  int64 private constant _SIMPLE_CROSS_MAINTENANCE_MARGIN_TIERS_LOCK_DURATION = 2 * 7 * 24 * ONE_HOUR_NANOS; // 2 weeks

  function scheduleSimpleCrossMaintenanceMarginTiers(
    int64 timestamp,
    uint64 txID,
    bytes32 kud,
    MarginTier[] calldata tiers,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    _validateAssetKUQ(kud);
    _requireValidMarginTiers(tiers);

    if (!_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer))) revert NotConfigAddress();

    bytes32 hash = hashScheduleSimpleCrossMaintenanceMarginTiers(kud, tiers, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);

    ListMarginTiersBI memory tiersBI = _convertToListMarginTiersBI(kud, tiers);

    state.simpleCrossMaintenanceMarginTimelockEndTime[kud] =
      timestamp +
      _getSimpleCrossMaintenanceMarginTiersLockDuration(kud, tiersBI);

    state.configVersion++;
    _sendConfigProofMessageToL1(abi.encode(timestamp, kud, tiers));
  }

  function setSimpleCrossMaintenanceMarginTiers(
    int64 timestamp,
    uint64 txID,
    bytes32 kud,
    MarginTier[] calldata tiers,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    _validateAssetKUQ(kud);

    _requireValidMarginTiers(tiers);

    if (!_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer))) revert NotConfigAddress();

    bytes32 hash = hashSetSimpleCrossMaintenanceMarginTiers(kud, tiers, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);

    ListMarginTiersBI memory tiersBI = _convertToListMarginTiersBI(kud, tiers);

    int64 lockDuration = _getSimpleCrossMaintenanceMarginTiersLockDuration(kud, tiersBI);
    if (lockDuration > 0) {
      int64 lockEndTime = state.simpleCrossMaintenanceMarginTimelockEndTime[kud];
      if (!(lockEndTime > 0 && lockEndTime <= timestamp)) revert MarginLockActive();
    }

    _setListMarginTiersBIToStorage(kud, tiersBI);
    delete state.simpleCrossMaintenanceMarginTimelockEndTime[kud];

    state.configVersion++;
    _sendConfigProofMessageToL1(abi.encode(timestamp, kud, tiers));
  }

  function _setListMarginTiersBIToStorage(bytes32 kud, ListMarginTiersBI memory tiersBI) private {
    ListMarginTiersBIStorage storage storageTiers = state.simpleCrossMaintenanceMarginTiers[kud];
    storageTiers.kud = tiersBI.kud;
    delete storageTiers.tiers;
    storageTiers.tiers = new MarginTierBIStorage[](tiersBI.tiers.length);
    for (uint i = 0; i < tiersBI.tiers.length; i++) {
      storageTiers.tiers[i].bracketStart = tiersBI.tiers[i].bracketStart;
      storageTiers.tiers[i].rate = tiersBI.tiers[i].rate;
    }
  }

  function _convertToListMarginTiersBI(
    bytes32 kud,
    MarginTier[] calldata tiers
  ) private pure returns (ListMarginTiersBI memory) {
    MarginTierBI[] memory biTiers = new MarginTierBI[](tiers.length);

    for (uint i = 0; i < tiers.length; i++) {
      biTiers[i] = MarginTierBI({
        bracketStart: BI(int256(uint256(tiers[i].bracketStart)), _getBalanceDecimal(assetGetQuote(kud))),
        rate: BI(int256(uint256(tiers[i].rate)), CENTIBEEP_DECIMALS)
      });
    }

    return ListMarginTiersBI({kud: kud, tiers: biTiers});
  }

  function _getSimpleCrossMaintenanceMarginTiersLockDuration(
    bytes32 kud,
    ListMarginTiersBI memory toMt
  ) internal view returns (int64) {
    ListMarginTiersBIStorage storage fromMtStorage = _getListMarginTiersBIStorageRef(kud);

    if (_isMarginRequirementIncreasedAtSomeSize(fromMtStorage, toMt)) {
      return _SIMPLE_CROSS_MAINTENANCE_MARGIN_TIERS_LOCK_DURATION;
    }
    return 0;
  }

  function _isMarginRequirementIncreasedAtSomeSize(
    ListMarginTiersBIStorage storage fromMtStorage,
    ListMarginTiersBI memory toMt
  ) internal view returns (bool) {
    if (fromMtStorage.tiers.length == 0 || toMt.tiers.length == 0) {
      return false;
    }

    // Check at each bracket start
    for (uint i = 0; i < fromMtStorage.tiers.length; i++) {
      if (
        BIMath.cmp(
          _blendedMM(toMt, fromMtStorage.tiers[i].bracketStart),
          _blendedMMFromStorage(fromMtStorage, fromMtStorage.tiers[i].bracketStart)
        ) > 0
      ) {
        return true;
      }
    }
    for (uint i = 0; i < toMt.tiers.length; i++) {
      if (
        BIMath.cmp(
          _blendedMM(toMt, toMt.tiers[i].bracketStart),
          _blendedMMFromStorage(fromMtStorage, toMt.tiers[i].bracketStart)
        ) > 0
      ) {
        return true;
      }
    }

    // Compare the last tier's rate
    return
      BIMath.cmp(toMt.tiers[toMt.tiers.length - 1].rate, fromMtStorage.tiers[fromMtStorage.tiers.length - 1].rate) > 0;
  }

  function _validateAssetKUQ(bytes32 kuq) internal pure {
    if (!assetIsKUQ(kuq)) revert NotKUQAsset();
    Kind kind = assetGetKind(kuq);
    if (!(kind == Kind.SPOT || kind == Kind.PERPS || kind == Kind.FUTURES)) revert WrongKind();
  }

  function _requireValidMarginTiers(MarginTier[] calldata marginTiers) internal pure {
    if (marginTiers.length == 0) revert EmptyMarginTiers();
    if (marginTiers.length > _MAX_M_MARGIN_TIERS) revert TooManyMarginTiers();

    if (marginTiers[0].bracketStart != 0) revert MarginFirstBracketMustStartAtZero();

    uint64 prevBracketStart = marginTiers[0].bracketStart;
    uint32 prevRate = marginTiers[0].rate;

    for (uint i = 1; i < marginTiers.length; i++) {
      if (marginTiers[i].bracketStart <= prevBracketStart) revert MarginBracketNotIncreasing();
      if (marginTiers[i].rate <= prevRate) revert MarginRateNotIncreasing();

      prevBracketStart = marginTiers[i].bracketStart;
      prevRate = marginTiers[i].rate;
    }
  }
}
