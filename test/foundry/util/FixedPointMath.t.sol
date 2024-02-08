// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/util/FixedPointMath.sol";
import "../../../contracts/exchange/types/DataStructure.sol";

contract FixedPointMathTest is Test {
  function testAddEqualDecimals() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 18);
    BI memory c = FixedPointMath.add(a, b);
    assertEq(c.val, 2);
    assertEq(c.dec, 18);
  }

  function testAddFirstOperandGreaterDecimals() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 15);
    BI memory c = FixedPointMath.add(a, b);
    assertEq(c.val, 1001);
    assertEq(c.dec, 18);
  }

  function testAddSecondOperandGreaterDecimals() public {
    BI memory a = BI(1, 15);
    BI memory b = BI(1, 18);
    BI memory c = FixedPointMath.add(a, b);
    assertEq(c.val, 1001);
    assertEq(c.dec, 18);
  }

  function testSubEqualDecimals() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 18);
    BI memory c = FixedPointMath.sub(a, b);
    assertEq(c.val, 0);
    assertEq(c.dec, 18);
  }

  function testSubFirstOperandGreaterDecimals() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 15);
    BI memory c = FixedPointMath.sub(a, b);
    assertEq(c.val, -999);
    assertEq(c.dec, 18);
  }

  function testSubSecondOperandGreaterDecimals() public {
    BI memory a = BI(1, 15);
    BI memory b = BI(1, 18);
    BI memory c = FixedPointMath.sub(a, b);
    assertEq(c.val, 999);
    assertEq(c.dec, 18);
  }

  function testMulEqualDecimals() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 18);
    BI memory c = FixedPointMath.mul(a, b);
    assertEq(c.val, 1);
    assertEq(c.dec, 36);
  }

  function testMulFirstOperandGreaterDecimals() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 15);
    BI memory c = FixedPointMath.mul(a, b);
    assertEq(c.val, 1);
    assertEq(c.dec, 33);
  }

  function testMulSecondOperandGreaterDecimals() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 15);
    BI memory c = FixedPointMath.mul(a, b);
    assertEq(c.val, 1);
    assertEq(c.dec, 33);
  }

  function testDiv() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 18);
    BI memory c = FixedPointMath.div(a, b);
    assertEq(c.val, 1000000000000000000);
    assertEq(c.dec, 18);
  }

  function testCmp() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 18);
    int256 c = FixedPointMath.cmp(a, b);
    assertEq(c, 0);

    BI memory d = BI(1, 18);
    BI memory e = BI(2, 18);
    int256 f = FixedPointMath.cmp(d, e);
    int256 g = FixedPointMath.cmp(e, d);
    assertEq(f, -1);
    assertEq(g, 1);
  }
}
