// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/common/Error.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "../../../contracts/exchange/util/Address.sol";
import "../../../contracts/exchange/util/BIMath.sol";

contract BIMathTest is Test {
  using BIMath for BI;

  function testAdd() public {
    // Test Case 1: 1+2, same decimals
    BI memory a = BI(1_000_000_000, 9);
    BI memory b = BI(2_000_000_000, 9);
    BI memory c = a.add(b);
    BI memory want = BI(3_000_000_000, 9);
    assertTrue(c.cmp(want) == 0);

    // Test Case 2: 1+2, different decimals
    a = BI(100, 2);
    b = BI(2_000_000_000, 9);
    want = BI(3_000_000_000, 9);
    c = a.add(b);
    assertTrue(c.cmp(want) == 0);
  }

  function testSub() public {
    // Test Case 1: 5-3, same decimals
    BI memory a = BI(5_000_000_000, 9);
    BI memory b = BI(3_000_000_000, 9);
    BI memory want = BI(2_000_000_000, 9);
    BI memory c = a.sub(b);
    assertTrue(c.cmp(want) == 0);

    // Test Case 2: 5-3, different decimals
    a = BI(500, 2);
    b = BI(3_000_000_000, 9);
    want = BI(2_000_000_000, 9);
    c = a.sub(b);
    assertTrue(c.cmp(want) == 0);
  }

  function testMul() public {
    // Test Case 1: 5*3, same decimals
    BI memory a = BI(5_000_000_000, 9);
    BI memory b = BI(3_000_000_000, 9);
    BI memory want = BI(15, 0); // Note: decimals adjusted
    BI memory c = a.mul(b);
    assertTrue(c.cmp(want) == 0);

    // Test Case 2: 5*3, different decimals
    a = BI(500, 2);
    b = BI(3_000_000_000, 9);
    want = BI(15, 0); // Note: decimals adjusted
    c = a.mul(b);
    assertTrue(c.cmp(want) == 0);

    // Test Case 3: 5*0, different decimals
    a = BI(500, 2);
    b = BI(0, 9);
    want = BI(0, 0);
    c = a.mul(b);
    assertTrue(c.cmp(want) == 0);

    // Test Case 4: 5*1, different decimals
    a = BI(500, 2);
    b = BI(1_000_000_000, 9);
    want = BI(5, 0); // Note: decimals adjusted
    c = a.mul(b);
    assertTrue(c.cmp(want) == 0);
  }

  function testDiv() public {
    // Test Case 1: 5/1, same decimals
    BI memory a = BI(5_000_000_000, 9);
    BI memory b = BI(1_000_000_000, 9);
    BI memory want = BI(5, 0);
    BI memory c = a.div(b);
    assertTrue(c.cmp(want) == 0);

    // Test Case 2: 5/2, same decimals
    a = BI(5_000_000_000, 9);
    b = BI(2_000_000_000, 9);
    want = BI(25, 1);
    c = a.div(b);
    assertTrue(c.cmp(want) == 0);

    // Test Case 3: 5/2, different decimals
    a = BI(500, 2);
    b = BI(2_000_000_000, 9);
    want = BI(25, 1);
    c = a.div(b);
    assertTrue(c.cmp(want) == 0);

    // Test Case 4: 5/10, different decimals
    a = BI(500, 2);
    b = BI(10_000_000_000, 9);
    want = BI(5, 1);
    c = a.div(b);
    assertTrue(c.cmp(want) == 0);

    // Test Case 5: Division by zero
    a = BI(1, 0);
    b = BI(0, 0);

    // Replace with the appropriate assertion mechanism
    vm.expectRevert(bytes(ERR_DIV_BY_ZERO)); // Or adjust based on BIMath error handling
    a.div(b);
  }

  function testNegSub() public {
    BI memory a = BI(-10, 1);
    BI memory b = BI(5, 1);
    BI memory want = BI(-15, 1);
    BI memory c = a.sub(b);
    assertTrue(c.cmp(want) == 0);
  }
}
