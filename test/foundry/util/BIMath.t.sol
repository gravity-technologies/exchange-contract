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
    assertEq(c.cmp(want), 0);

    // Test Case 2: 1+2, different decimals
    a = BI(100, 2);
    b = BI(2_000_000_000, 9);
    want = BI(3_000_000_000, 9);
    c = a.add(b);
    assertEq(c.cmp(want), 0);
  }

  function testSub() public {
    // Test Case 1: 5-3, same decimals
    BI memory a = BI(5_000_000_000, 9);
    BI memory b = BI(3_000_000_000, 9);
    BI memory want = BI(2_000_000_000, 9);
    BI memory c = a.sub(b);
    assertEq(c.cmp(want), 0);

    // Test Case 2: 5-3, different decimals
    a = BI(500, 2);
    b = BI(3_000_000_000, 9);
    want = BI(2_000_000_000, 9);
    c = a.sub(b);
    assertEq(c.cmp(want), 0);
  }

  function testMul() public {
    // Test Case 1: 5*3, same decimals
    BI memory a = BI(5_000_000_000, 9);
    BI memory b = BI(3_000_000_000, 9);
    BI memory want = BI(15, 0); // Note: decimals adjusted
    BI memory c = a.mul(b);
    assertEq(c.cmp(want), 0);

    // Test Case 2: 5*3, different decimals
    a = BI(500, 2);
    b = BI(3_000_000_000, 9);
    want = BI(15, 0); // Note: decimals adjusted
    c = a.mul(b);
    assertEq(c.cmp(want), 0);

    // Test Case 3: 5*0, different decimals
    a = BI(500, 2);
    b = BI(0, 9);
    want = BIMath.zero();
    c = a.mul(b);
    assertEq(c.cmp(want), 0);

    // Test Case 4: 5*1, different decimals
    a = BI(500, 2);
    b = BI(1_000_000_000, 9);
    want = BI(5, 0); // Note: decimals adjusted
    c = a.mul(b);
    assertEq(c.cmp(want), 0);
  }

  function testDiv() public {
    // Test Case 1: 5/1, same decimals
    BI memory a = BI(5_000_000_000, 9);
    BI memory b = BI(1_000_000_000, 9);
    BI memory want = BI(5, 0);
    BI memory c = a.div(b);
    assertEq(c.cmp(want), 0);

    // Test Case 2: 5/2, same decimals
    a = BI(5_000_000_000, 9);
    b = BI(2_000_000_000, 9);
    want = BI(25, 1);
    c = a.div(b);
    assertEq(c.cmp(want), 0);

    // Test Case 3: 5 / 2, different decimals
    a = BI(500, 2); // Represents 5.00
    b = BI(2_000_000_000, 9); // Represents 2.0
    c = a.div(b);
    want = BI(25, 1);
    assertEq(c.cmp(want), 0);

    // Test Case 4: 5 / 10, different decimals
    a = BI(500, 2); // Represents 5.00
    b = BI(10_000_000_000, 9); // Represents 10.0
    c = a.div(b);
    want = BI(5, 1);
    assertEq(c.cmp(want), 0);

    // Test Case 5: Withdrawal fee
    a = BI(25_000_000, 6); // Represents 25.0
    b = BI(60_000_000_000_000, 9); // Represents 60000.0
    c = a.div(b);
    want = BI(416_666, 9); // Expected result: 0.000416
    assertEq(c.cmp(want), 0);

    // Test Case 6: Negative numerator
    a = BI(-5_000_000_000, 9); // Represents -5.0
    b = BI(2_000_000_000, 9); // Represents 2.0
    c = a.div(b);
    want = BI(-2_500_000_000, 9); // Expected result: -2.5
    assertEq(c.cmp(want), 0);

    // Test Case 7: Negative denominator
    a = BI(5_000_000_000, 9); // Represents 5.0
    b = BI(-2_000_000_000, 9); // Represents -2.0
    c = a.div(b);
    want = BI(-2_500_000_000, 9); // Expected result: -2.5
    assertEq(c.cmp(want), 0);

    // Test Case 8: Both numerator and denominator negative
    a = BI(-5_000_000_000, 9); // Represents -5.0
    b = BI(-2_000_000_000, 9); // Represents -2.0
    c = a.div(b);
    want = BI(2_500_000_000, 9); // Expected result: 2.5
    assertEq(c.cmp(want), 0);

    // Test Case 9: Large decimals difference
    a = BIMath.one(); // Represents 1
    b = BI(1, 18); // Represents 1e-18
    c = a.div(b);
    want = BI(1_000_000_000_000_000_000, 0); // Expected result: 1e18
    assertEq(c.cmp(want), 0);

    // Test Case 10: Zero numerator
    a = BI(0, 9); // Represents 0.0
    b = BI(1_000_000_000, 9); // Represents 1.0
    c = a.div(b);
    want = BI(0, 9); // Expected result: 0.0
    assertEq(c.cmp(want), 0);

    // Test Case 11: Fractional result with larger decimals
    a = BI(1_000_000_000, 9); // Represents 1.0
    b = BI(3_000_000_000, 9); // Represents 3.0
    c = a.div(b);
    want = BI(333_333_333, 9); // Expected result: ~0.333333333
    assertEq(c.cmp(want), 0);

    // Test Case 12: Division resulting in a repeating decimal
    a = BI(10_000_000_000, 9); // Represents 10.0
    b = BI(3_000_000_000, 9); // Represents 3.0
    c = a.div(b);
    want = BI(3_333_333_333, 9); // Expected result: ~3.333333333
    assertEq(c.cmp(want), 0);

    // Test Case 13: Dividing by a larger number
    a = BI(1_000_000_000, 9); // Represents 1.0
    b = BI(2_000_000_000, 9); // Represents 2.0
    c = a.div(b);
    want = BI(500_000_000, 9); // Expected result: 0.5
    assertEq(c.cmp(want), 0);

    // Test Case 14: Dividing numbers with significant decimal difference
    a = BI(1_000_000_000, 9); // Represents 1.0
    b = BIMath.one(); // Represents 1.0
    c = a.div(b);
    want = BI(1_000_000_000_000_000_000, 18); // Expected result: 1e9
    assertEq(c.cmp(want), 0);

    // Test Case 15: Division by zero
    a = BIMath.one();
    b = BIMath.zero();
    vm.expectRevert(bytes(ERR_DIV_BY_ZERO));
    a.div(b);
  }

  function testScale() public {
    // Test Case 1: Scale up by 2 decimals
    BI memory a = BIMath.one();
    BI memory want = BI(100, 2);
    BI memory c = BIMath.scale(a, 2);
    assertEq(c.cmp(want), 0);

    // Test Case 2: Scale down by 2 decimals
    a = BI(100, 2);
    want = BIMath.one();
    c = BIMath.scale(a, 0);
    assertEq(c.cmp(want), 0);

    // Test Case 3: Scale up by 10 decimals
    a = BIMath.one();
    want = BI(1_000_000_000_000, 12);
    c = BIMath.scale(a, 12);
    assertEq(c.cmp(want), 0);

    // Test Case 4: Scale down by 10 decimals
    a = BI(1_000_000_000_000, 12);
    want = BIMath.one();
    c = BIMath.scale(a, 0);
    assertEq(c.cmp(want), 0);

    // Test Case 5: Scale to the same decimal
    a = BI(1_000_000_000, 9);
    want = BI(1_000_000_000, 9);
    c = BIMath.scale(a, 9);
    assertEq(c.cmp(want), 0);

    // Test Case 6: Scale up and down multiple steps
    a = BI(123456, 3);
    want = BI(123456000000, 9);
    c = BIMath.scale(a, 9);
    assertEq(c.cmp(want), 0);

    // Test Case 7: Scale down with remainder
    a = BI(123456, 3);
    want = BI(123, 0);
    c = BIMath.scale(a, 0);
    assertEq(c.cmp(want), 0);

    // Test Case 8: Scale up with initial non-zero decimals
    a = BI(123456, 3);
    want = BI(123456000000, 9);
    c = BIMath.scale(a, 9);
    assertEq(c.cmp(want), 0);
  }

  function testNegSub() public {
    BI memory a = BI(-10, 1);
    BI memory b = BI(5, 1);
    BI memory want = BI(-15, 1);
    BI memory c = a.sub(b);
    assertEq(c.cmp(want), 0);
  }
}
