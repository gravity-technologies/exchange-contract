pragma solidity ^0.8.20;

import "./ConfigContract.sol";
import "../types/DataStructure.sol";
import "./signature/generated/MarginSig.sol";

contract MarginConfigContract is ConfigContract {
  uint private constant MAX_M_MARGIN_TIERS = 12;
  int64 private constant SIMPLE_CROSS_MAINTENANCE_MARGIN_TIERS_LOCK_DURATION = 2 * 7 * 24 * ONE_HOUR_NANOS; // 2 weeks

  function scheduleSimpleCrossMaintenanceMarginTiers(
    int64 timestamp,
    uint64 txID,
    bytes32 kud,
    MarginTier[] calldata tiers,
    Signature calldata sig
  ) external onlyRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    _requireValidMarginTiers(tiers);

    // ---------- Signature Verification -----------
    require(_getBoolConfig2D(ConfigID.CONFIG_ADDRESS, _addressToConfig(sig.signer)), "not config address");

    _preventReplay(hashScheduleSimpleCrossMaintenanceMarginTiers(kud, tiers, sig.nonce, sig.expiration), sig);
    // ------- End of Signature Verification -------

    ListMarginTiersBI memory tiersBI = _convertToListMarginTiersBI(kud, tiers);

    state.simpleCrossMaintenanceMarginTimelockEndTime[kud] =
      timestamp +
      _getSimpleCrossMaintenanceMarginTiersLockDuration(kud, tiersBI);
  }

  function setSimpleCrossMaintenanceMarginTiers(
    int64 timestamp,
    uint64 txID,
    bytes32 kud,
    MarginTier[] calldata tiers,
    Signature calldata sig
  ) external onlyRole(CHAIN_SUBMITTER_ROLE) {
    _setSequence(timestamp, txID);
    require(assetIsKUQ(kud), "must be KUQ");

    uint kind = uint(assetGetKind(kud));
    require(kind > 0 && kind < 6, "wrong kind");

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

    state.simpleCrossMaintenanceMarginTiers[kud] = tiersBI;
    delete state.simpleCrossMaintenanceMarginTimelockEndTime[kud];
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
        bracketStart: BI(int256(uint256(tiers[i].bracketStart)), _getBalanceDecimal(assetGetUnderlying(kud))),
        rate: BI(int256(uint256(tiers[i].rate)), BASIS_POINTS_DECIMALS)
      });
    }

    return ListMarginTiersBI({kud: kud, tiers: biTiers});
  }

  function _getSimpleCrossMaintenanceMarginTiersLockDuration(
    bytes32 kud,
    ListMarginTiersBI memory toMt
  ) private view returns (int64) {
    ListMarginTiersBI memory fromMt = state.simpleCrossMaintenanceMarginTiers[kud];

    if (fromMt.tiers.length == 0) {
      return 0;
    }

    if (_isMarginRequirementIncreasedAtSomeSize(fromMt, toMt)) {
      return SIMPLE_CROSS_MAINTENANCE_MARGIN_TIERS_LOCK_DURATION;
    }
    return 0;
  }

  function _isMarginRequirementIncreasedAtSomeSize(
    ListMarginTiersBI memory fromMt,
    ListMarginTiersBI memory toMt
  ) private pure returns (bool) {
    if (fromMt.tiers.length == 0 || toMt.tiers.length == 0) {
      return false;
    }

    // Check at each bracket start
    for (uint i = 0; i < fromMt.tiers.length; i++) {
      if (
        BIMath.cmp(
          _calculateSimpleCrossMMSize(toMt, fromMt.tiers[i].bracketStart),
          _calculateSimpleCrossMMSize(fromMt, fromMt.tiers[i].bracketStart)
        ) > 0
      ) {
        return true;
      }
    }
    for (uint i = 0; i < toMt.tiers.length; i++) {
      if (
        BIMath.cmp(
          _calculateSimpleCrossMMSize(toMt, toMt.tiers[i].bracketStart),
          _calculateSimpleCrossMMSize(fromMt, toMt.tiers[i].bracketStart)
        ) > 0
      ) {
        return true;
      }
    }

    // Compare the last tier's rate
    return BIMath.cmp(toMt.tiers[toMt.tiers.length - 1].rate, fromMt.tiers[fromMt.tiers.length - 1].rate) > 0;
  }

  function _calculateSimpleCrossMMSize(ListMarginTiersBI memory mt, BI memory size) internal pure returns (BI memory) {
    if (mt.tiers.length == 0) {
      return BI(0, 0);
    }

    BI memory margin = BI(0, 0);
    BI memory prevStart = BI(0, 0);
    BI memory prevRate = mt.tiers[0].rate;
    BI memory bracketSize;

    for (uint i = 0; i < mt.tiers.length; i++) {
      if (BIMath.cmp(size, mt.tiers[i].bracketStart) <= 0) {
        bracketSize = BIMath.sub(size, prevStart);
        margin = BIMath.add(margin, BIMath.mul(bracketSize, prevRate));
        return margin;
      }

      bracketSize = BIMath.sub(mt.tiers[i].bracketStart, prevStart);
      margin = BIMath.add(margin, BIMath.mul(bracketSize, prevRate));

      prevStart = mt.tiers[i].bracketStart;
      prevRate = mt.tiers[i].rate;
    }

    BI memory lastBracketSize = BIMath.sub(size, prevStart);
    margin = BIMath.add(margin, BIMath.mul(lastBracketSize, prevRate));

    return margin;
  }
}
