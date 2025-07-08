pragma solidity ^0.8.20;

import "./ConfigContract.sol";
import "../types/DataStructure.sol";
import "./signature/generated/MarginSig.sol";
import "../util/BIMath.sol";
import "../interfaces/IMarginConfig.sol";

contract MarginConfigContract is IMarginConfig, ConfigContract {
  using BIMath for BI;

  uint private constant MAX_M_MARGIN_TIERS = 12;
  int64 private constant SIMPLE_CROSS_MAINTENANCE_MARGIN_TIERS_LOCK_DURATION = 2 * 7 * 24 * ONE_HOUR_NANOS; // 2 weeks

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

    // ---------- Signature Verification -----------
    require(_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer)), "not config address");

    _preventReplay(hashScheduleSimpleCrossMaintenanceMarginTiers(kud, tiers, sig.nonce, sig.expiration), sig);
    // ------- End of Signature Verification -------

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

    // ---------- Signature Verification -----------
    require(_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer)), "not config address");

    _preventReplay(hashSetSimpleCrossMaintenanceMarginTiers(kud, tiers, sig.nonce, sig.expiration), sig);
    // ------- End of Signature Verification -------

    ListMarginTiersBI memory tiersBI = _convertToListMarginTiersBI(kud, tiers);

    int64 lockDuration = _getSimpleCrossMaintenanceMarginTiersLockDuration(kud, tiersBI);
    if (lockDuration > 0) {
      int64 lockEndTime = state.simpleCrossMaintenanceMarginTimelockEndTime[kud];
      require(lockEndTime > 0 && lockEndTime <= timestamp, "not scheduled or still locked");
    }

    _setListMarginTiersBIToStorage(kud, tiersBI);
    delete state.simpleCrossMaintenanceMarginTimelockEndTime[kud];

    state.configVersion++;
    _sendConfigProofMessageToL1(abi.encode(timestamp, kud, tiers));
  }

  function _validateAssetKUQ(bytes32 kuq) private pure {
    require(assetIsKUQ(kuq), "must be KUQ");
    Kind kind = assetGetKind(kuq);
    require(kind == Kind.SPOT || kind == Kind.PERPS || kind == Kind.FUTURES, "wrong kind");
  }

  function _requireValidMarginTiers(MarginTier[] calldata marginTiers) private pure {
    require(marginTiers.length > 0, "empty margin tiers");
    require(marginTiers.length <= MAX_M_MARGIN_TIERS, "too many margin tiers");

    require(marginTiers[0].bracketStart == 0, "first bracket must start at 0");

    uint64 prevBracketStart = marginTiers[0].bracketStart;
    uint32 prevRate = marginTiers[0].rate;

    for (uint i = 1; i < marginTiers.length; i++) {
      require(marginTiers[i].bracketStart > prevBracketStart, "brackets not increasing");
      require(marginTiers[i].rate > prevRate, "margin rates not increasing");

      prevBracketStart = marginTiers[i].bracketStart;
      prevRate = marginTiers[i].rate;
    }
  }

  function _convertToListMarginTiersBI(
    bytes32 kud,
    MarginTier[] calldata tiers
  ) internal pure returns (ListMarginTiersBI memory) {
    MarginTierBI[] memory biTiers = new MarginTierBI[](tiers.length);

    for (uint i = 0; i < tiers.length; i++) {
      biTiers[i] = MarginTierBI({
        bracketStart: BI(int256(uint256(tiers[i].bracketStart)), _getBalanceDecimal(assetGetQuote(kud))),
        rate: BI(int256(uint256(tiers[i].rate)), CENTIBEEP_DECIMALS)
      });
    }

    return ListMarginTiersBI({kud: kud, tiers: biTiers});
  }

  function _getListMarginTiersBIStorageRef(bytes32 kud) internal view returns (ListMarginTiersBIStorage storage) {
    return state.simpleCrossMaintenanceMarginTiers[kud];
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

  function _getSimpleCrossMaintenanceMarginTiersLockDuration(
    bytes32 kud,
    ListMarginTiersBI memory toMt
  ) private view returns (int64) {
    ListMarginTiersBIStorage storage fromMtStorage = _getListMarginTiersBIStorageRef(kud);

    if (_isMarginRequirementIncreasedAtSomeSize(fromMtStorage, toMt)) {
      return SIMPLE_CROSS_MAINTENANCE_MARGIN_TIERS_LOCK_DURATION;
    }
    return 0;
  }

  function _isMarginRequirementIncreasedAtSomeSize(
    ListMarginTiersBIStorage storage fromMtStorage,
    ListMarginTiersBI memory toMt
  ) private view returns (bool) {
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

  function _getPositionMM(
    ListMarginTiersBI memory mt,
    BI memory sizeBI,
    BI memory markPriceBI
  ) internal view returns (BI memory) {
    BI memory notional = sizeBI.mul(markPriceBI);
    return _blendedMM(mt, notional);
  }

  function _getPositionMMFromStorage(
    ListMarginTiersBIStorage storage mt,
    BI memory sizeBI,
    BI memory markPriceBI
  ) internal view returns (BI memory) {
    BI memory notional = sizeBI.mul(markPriceBI);
    return _blendedMMFromStorage(mt, notional);
  }

  function _blendedMM(ListMarginTiersBI memory mt, BI memory notional) internal pure returns (BI memory) {
    if (mt.tiers.length == 0) {
      return BIMath.zero();
    }

    BI memory margin = BIMath.zero();
    BI memory prevStart = BIMath.zero();
    BI memory prevRate = mt.tiers[0].rate;
    BI memory bracketSize;

    for (uint i = 0; i < mt.tiers.length; i++) {
      if (BIMath.cmp(notional, mt.tiers[i].bracketStart) <= 0) {
        bracketSize = BIMath.sub(notional, prevStart);
        margin = BIMath.add(margin, BIMath.mul(bracketSize, prevRate));
        return margin;
      }

      bracketSize = BIMath.sub(mt.tiers[i].bracketStart, prevStart);
      margin = BIMath.add(margin, BIMath.mul(bracketSize, prevRate));

      prevStart = mt.tiers[i].bracketStart;
      prevRate = mt.tiers[i].rate;
    }

    BI memory lastBracketSize = BIMath.sub(notional, prevStart);
    margin = BIMath.add(margin, BIMath.mul(lastBracketSize, prevRate));

    return margin;
  }

  function _blendedMMFromStorage(
    ListMarginTiersBIStorage storage mt,
    BI memory notional
  ) internal view returns (BI memory) {
    if (mt.tiers.length == 0) {
      return BIMath.zero();
    }

    BI memory margin = BIMath.zero();
    BI memory prevStart = BIMath.zero();
    BI memory prevRate = mt.tiers[0].rate;
    BI memory bracketSize;

    for (uint i = 0; i < mt.tiers.length; i++) {
      if (BIMath.cmp(notional, mt.tiers[i].bracketStart) <= 0) {
        bracketSize = BIMath.sub(notional, prevStart);
        margin = BIMath.add(margin, BIMath.mul(bracketSize, prevRate));
        return margin;
      }

      bracketSize = BIMath.sub(mt.tiers[i].bracketStart, prevStart);
      margin = BIMath.add(margin, BIMath.mul(bracketSize, prevRate));

      prevStart = mt.tiers[i].bracketStart;
      prevRate = mt.tiers[i].rate;
    }

    BI memory lastBracketSize = BIMath.sub(notional, prevStart);
    margin = BIMath.add(margin, BIMath.mul(lastBracketSize, prevRate));

    return margin;
  }
}
