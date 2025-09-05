pragma solidity ^0.8.20;

import "../common/Error.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

struct BI {
  int256 val;
  uint256 dec;
}

// TODO: add division test
library BIMath {
  function add(BI memory a, BI memory b) internal pure returns (BI memory) {
    BI memory c;
    if (a.dec == b.dec) {
      c.val = a.val + b.val;
      c.dec = a.dec;
    } else if (a.dec > b.dec) {
      c.val = a.val + b.val * (int256(10) ** (a.dec - b.dec));
      c.dec = a.dec;
    } else {
      c.val = b.val + a.val * (int256(10) ** (b.dec - a.dec));
      c.dec = b.dec;
    }
    return c;
  }

  function sub(BI memory a, BI memory b) internal pure returns (BI memory) {
    return add(a, BI(-b.val, b.dec));
  }

  function mul(BI memory a, BI memory b) internal pure returns (BI memory) {
    BI memory c = BI(a.val * b.val, a.dec + b.dec);
    return c;
  }

  function div(BI memory a, BI memory b) internal pure returns (BI memory) {
    require(b.val != 0, ERR_DIV_BY_ZERO);
    uint256 maxDec = a.dec > b.dec ? a.dec : b.dec;
    uint256 exponent = maxDec + b.dec - a.dec;
    int256 numerator = a.val * (int256(10) ** exponent);
    BI memory c = BI(numerator / b.val, maxDec); // Perform the division
    return c;
  }

  uint256 constant POW_SCALE_DECIMALS = 12;

  /**
   * @dev Calculate base raised to the power of exponent (base^exponent)
   * @param base The base value
   * @param exponent The exponent to raise the base to
   * @return BI value representing base^exponent
   * Uses the binary exponentiation algorithm for O(log n) complexity
   * Scales to POW_SCALE_DECIMALS decimal places before and after each multiplication
   */
  function pow(BI memory base, uint exponent) internal pure returns (BI memory) {
    if (exponent == 0) return one();
    if (exponent == 1) return scale(base, POW_SCALE_DECIMALS); // Scale to 12 decimal places

    BI memory result = one();
    BI memory currentBase = scale(base, POW_SCALE_DECIMALS); // Scale base to 12 decimal places initially

    while (exponent > 0) {
      if (exponent % 2 == 1) {
        // If exponent is odd, multiply result by currentBase
        result = mul(result, currentBase);
        result = scale(result, POW_SCALE_DECIMALS); // Scale result back to 12 decimal places
      }

      // Square the base for the next iteration
      currentBase = mul(currentBase, currentBase);
      currentBase = scale(currentBase, POW_SCALE_DECIMALS); // Scale currentBase back to 12 decimal places

      // Integer division by 2
      exponent /= 2;
    }

    return result;
  }

  function scale(BI memory a, uint256 d) internal pure returns (BI memory) {
    if (a.dec > d) return BI(a.val / SafeCast.toInt256(10 ** (a.dec - d)), d);
    return BI(a.val * SafeCast.toInt256(10 ** (d - a.dec)), d);
  }

  function cmp(BI memory a, BI memory b) internal pure returns (int256) {
    if (a.dec == b.dec) {
      return a.val - b.val;
    }

    if (a.dec > b.dec) {
      return a.val - b.val * (int256(10) ** (a.dec - b.dec));
    }

    return a.val * (int256(10) ** (b.dec - a.dec)) - b.val;
  }

  function neg(BI memory n) internal pure returns (BI memory) {
    return BI(-n.val, n.dec);
  }

  function isPositive(BI memory a) internal pure returns (bool) {
    return a.val > 0;
  }

  function isNegative(BI memory a) internal pure returns (bool) {
    return a.val < 0;
  }

  function isZero(BI memory a) internal pure returns (bool) {
    return a.val == 0;
  }

  function toInt256(BI memory a, uint decimals) internal pure returns (int256) {
    if (a.dec == decimals) return a.val;
    if (a.dec > decimals) return a.val / (int256(10) ** (a.dec - decimals));
    return a.val * (int256(10) ** (decimals - a.dec));
  }

  function toInt64(BI memory a, uint decimals) internal pure returns (int64) {
    int256 c;
    if (a.dec == decimals) {
      c = a.val;
    } else if (a.dec > decimals) {
      c = a.val / int256(10) ** (a.dec - decimals);
    } else {
      c = a.val * int256(10) ** (decimals - a.dec);
    }
    return SafeCast.toInt64(c);
  }

  function toUint64(BI memory a, uint decimals) internal pure returns (uint64) {
    require(a.val >= 0, ERR_UNSAFE_CAST);
    int256 c;
    if (a.dec == decimals) {
      c = a.val;
    } else if (a.dec > decimals) {
      c = a.val / int256(10) ** (a.dec - decimals);
    } else {
      c = a.val * int256(10) ** (decimals - a.dec);
    }
    return SafeCast.toUint64(SafeCast.toUint256(c));
  }

  function zero() internal pure returns (BI memory) {
    return BI(0, 0);
  }

  function one() internal pure returns (BI memory) {
    return BI(1, 0);
  }

  function half() internal pure returns (BI memory) {
    return BI(int256(5), 1);
  }

  function fromUint64(uint64 a, uint decimals) internal pure returns (BI memory) {
    return BI(int(uint(a)), decimals);
  }

  function fromInt64(int64 a, uint decimals) internal pure returns (BI memory) {
    return BI(int(a), decimals);
  }

  function fromUint32(uint32 a, uint decimals) internal pure returns (BI memory) {
    return BI(int(uint(a)), decimals);
  }

  function fromInt32(int32 a, uint decimals) internal pure returns (BI memory) {
    return BI(int(a), decimals);
  }

  function floor(BI memory b) internal pure returns (BI memory) {
    return scale(scale(b, 0), b.dec);
  }

  function roundDown(BI memory b) internal pure returns (BI memory) {
    if (b.val > 0) {
      return floor(b);
    }
    return floor(sub(b, one()));
  }

  function roundUp(BI memory b) internal pure returns (BI memory) {
    BI memory nearOne = sub(one(), BI(int256(1), b.dec));
    if (b.val > 0) {
      return floor(add(b, nearOne));
    }
    return floor(b);
  }

  function round(BI memory b) internal pure returns (BI memory) {
    BI memory halfBI = half();
    if (b.val > 0) {
      return floor(add(b, halfBI));
    }
    return floor(sub(b, halfBI));
  }
}
