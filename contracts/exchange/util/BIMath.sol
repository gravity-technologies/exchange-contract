// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../common/Error.sol";

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
    BI memory c = BI((a.val * (int256(10) ** b.dec)) / b.val, a.dec);
    return c;
  }

  function scale(BI memory a, uint256 d) internal pure returns (BI memory) {
    if (a.dec > d) return BI(a.val / int256(10 ** (a.dec - d)), d);
    return BI(a.val / int256(10 ** (d - a.dec)), d);
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
    return int64(uint64(uint(c)));
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
    return uint64(uint256(c));
  }
}
