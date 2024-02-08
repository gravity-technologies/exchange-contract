// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/util/FixedPointMath.sol";
import "../../../contracts/exchange/types/DataStructure.sol";

contract FixedPointMathTest is Test {
  function testAdd() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 18);
    BI memory c = FixedPointMath.add(a, b);
    assertEq(c.val, 2);
    assertEq(c.dec, 18);
  }

  function testSub() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 18);
    BI memory c = FixedPointMath.sub(a, b);
    assertEq(c.val, 0);
    assertEq(c.dec, 18);
  }

  function testMul() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 18);
    BI memory c = FixedPointMath.mul(a, b);
    assertEq(c.val, 1);
    assertEq(c.dec, 36);
  }

  function testDiv() public {
    BI memory a = BI(1, 18);
    BI memory b = BI(1, 18);
    BI memory c = FixedPointMath.div(a, b);
    assertEq(c.val, 1);
    assertEq(c.dec, 18);
  }
}
