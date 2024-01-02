// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct BI {
  int256 val;
  uint256 dec;
}

library FixedPointMath {
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
    c.val = a.val * int256(10) ** b.dec;
    c.val /= b.val;
    c.dec = b.dec;
    return c;
  }

  function cmp(BI memory a, BI memory b) internal pure returns (int256) {
    if (a.dec == b.dec) {
      return a.val - b.val;
    } else if (a.dec > b.dec) {
      return a.val - b.val * (int256(10) ** (a.dec - b.dec));
    } else {
      return a.val * (int256(10) ** (b.dec - a.dec)) - b.val;
    }
  }
}
