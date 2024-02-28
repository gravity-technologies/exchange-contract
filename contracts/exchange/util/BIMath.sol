// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../common/Error.sol";

struct BI {
  int256 val;
  uint256 dec;
}

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
    BI memory c;
    c.val = a.val * b.val;
    c.dec = a.dec + b.dec;
    return c;
  }

  function div(BI memory a, BI memory b) internal pure returns (BI memory) {
    BI memory c;
    c.val = ((a.val * int256(10) ** b.dec) / b.val);
    c.dec = b.dec;
    return c;
  }

  function neg(BI memory a) internal pure returns (BI memory) {
    return BI(-a.val, a.dec);
  }

  function abs(BI memory a) internal pure returns (BI memory) {
    return BI(a.val < 0 ? -a.val : a.val, a.dec);
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

  function toInt256(BI memory a, uint decimals) internal pure returns (int256) {
    if (a.dec == decimals) return a.val;
    if (a.dec > decimals) return a.val / int256(10) ** (a.dec - decimals);
    return a.val * int256(10) ** (decimals - a.dec);
  }

  function toInt64(BI memory a, uint decimals) internal pure returns (int64) {
    int256 res = toInt256(a, decimals);
    require(res >= type(int64).min && res <= type(int64).max, ERR_OVERFLOW);
    return int64(res);
  }

  function toUint64(BI memory a, uint decimals) internal pure returns (uint64) {
    require(a.val >= 0, ERR_UNSAFE_CAST);
    uint256 res = uint256(toInt256(a, decimals));
    require(res >= type(uint64).min && res <= type(uint64).max, ERR_OVERFLOW);
    return uint64(res);
  }
}
