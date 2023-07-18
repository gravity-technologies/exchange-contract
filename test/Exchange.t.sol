// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Exchange.sol";

contract TokenTest is Test {
    GRVTExchange ex;

    function setUp() public {
        ex = new GRVTExchange();
    }

    function testName() public {
        assertEq(ex.hello(), "hi");
    }
}
