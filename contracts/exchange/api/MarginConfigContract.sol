pragma solidity ^0.8.20;

import "./ConfigContract.sol";
import "../types/DataStructure.sol";
import "../util/BIMath.sol";
import "../common/Error.sol";

contract MarginConfigContractGetter is ConfigContract {
  using BIMath for BI;

  function _getListMarginTiersBIStorageRef(bytes32 kud) internal view returns (ListMarginTiersBIStorage storage) {
    return state.simpleCrossMaintenanceMarginTiers[kud];
  }

  function _getPositionMM(
    ListMarginTiersBI memory mt,
    BI memory sizeBI,
    BI memory markPriceBI
  ) internal pure returns (BI memory) {
    return _blendedMM(mt, sizeBI.mul(markPriceBI));
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
