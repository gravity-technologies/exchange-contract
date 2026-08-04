// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {TransferContract} from "../../contracts/exchange/api/TransferContract.sol";
import {
  ConfigID,
  ConfigValue,
  WithdrawalQueue,
  PendingWithdrawalRequest
} from "../../contracts/exchange/types/DataStructure.sol";
import {CCY_USDT, CCY_USDC, CCY_ETH, CCY_USD, CCY_UNSPECIFIED} from "../../contracts/exchange/types/Enum.sol";
import {ITransfer} from "../../contracts/exchange/interfaces/ITransfer.sol";
import {IL2SharedBridge} from "../../lib/era-contracts/l2-contracts/contracts/bridge/interfaces/IL2SharedBridge.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract SweepHarness is TransferContract {
  function init(address admin) external initializer {
    __ReentrancyGuard_init();
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
  }

  function setCurrencyERC20Address(uint8 currency, address token) external {
    state.config2DValues[ConfigID.ERC20_ADDRESSES][_currencyToConfig(currency)] = ConfigValue({
      val: _addressToConfig(token),
      isSet: true
    });
  }

  function setL2SharedBridgeAddress(address bridge) external {
    state.config1DValues[ConfigID.L2_SHARED_BRIDGE_ADDRESS] = ConfigValue({
      val: _addressToConfig(bridge),
      isSet: true
    });
  }

  function setTotalSpotBalance(uint8 currency, int64 amount) external {
    state.totalSpotBalances[currency] = amount;
  }

  function pushPendingWithdrawal(address recipient, uint8 currency, int64 amount) external {
    WithdrawalQueue storage q = state.pendingWithdrawalQueue;
    q.requests[q.tail] = PendingWithdrawalRequest({
      recipient: recipient,
      currency: currency,
      amountToSend: amount,
      enqueuedTimestampNs: 0
    });
    q.tail = q.tail + 1;
  }
}

contract SweepOverCollateralizedFundTest is Test {
  SweepHarness internal exchange;

  address internal constant ADMIN = address(0xA11CE);
  address internal constant NON_ADMIN = address(0xBAD);
  address internal constant DESTINATION = address(0xDEF1);
  address internal constant ALT_DESTINATION = address(0xDEF2);
  address internal constant USDT_L2 = address(0x1001);
  address internal constant L2_SHARED_BRIDGE = address(0x2002);

  // USDT: internal balance-decimals = 6, ERC20 decimals = 6 => internal int64 1e6 == 1 USDT.
  uint8 internal constant USDT_ERC20_DECIMALS = 6;

  event OverCollateralizedFundDestinationSet(address indexed destination);
  event OverCollateralizedFundSwept(
    uint8 indexed currency,
    address indexed erc20Address,
    address indexed destination,
    uint256 amount
  );

  function setUp() public {
    exchange = new SweepHarness();
    exchange.init(ADMIN);
    exchange.setCurrencyERC20Address(CCY_USDT, USDT_L2);
    exchange.setL2SharedBridgeAddress(L2_SHARED_BRIDGE);

    // ERC20 decimals() used by scaleToERC20Amount.
    vm.mockCall(USDT_L2, abi.encodeWithSelector(IERC20MetadataUpgradeable.decimals.selector), abi.encode(USDT_ERC20_DECIMALS));

    // IL2SharedBridge.withdraw returns nothing; mock to succeed.
    vm.mockCall(L2_SHARED_BRIDGE, abi.encodeWithSelector(IL2SharedBridge.withdraw.selector), bytes(""));
  }

  function _mockBalance(uint256 bal) internal {
    vm.mockCall(
      USDT_L2,
      abi.encodeWithSelector(IERC20Upgradeable.balanceOf.selector, address(exchange)),
      abi.encode(bal)
    );
  }

  // ---------- setOverCollateralizedFundDestination ----------

  function testSetDestinationByAdminEmitsEventAndUpdatesGetter() public {
    vm.prank(ADMIN);
    vm.expectEmit(true, false, false, false, address(exchange));
    emit OverCollateralizedFundDestinationSet(DESTINATION);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    assertEq(exchange.getOverCollateralizedFundDestination(), DESTINATION);
  }

  function testSetDestinationRevertsForNonAdmin() public {
    vm.prank(NON_ADMIN);
    vm.expectRevert();
    exchange.setOverCollateralizedFundDestination(DESTINATION);
  }

  function testSetDestinationRevertsOnZeroAddress() public {
    vm.prank(ADMIN);
    vm.expectRevert(bytes("invalid destination"));
    exchange.setOverCollateralizedFundDestination(address(0));
  }

  function testSetDestinationIsUpdatable() public {
    vm.startPrank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);
    exchange.setOverCollateralizedFundDestination(ALT_DESTINATION);
    vm.stopPrank();

    assertEq(exchange.getOverCollateralizedFundDestination(), ALT_DESTINATION);
  }

  // ---------- sweepOverCollateralizedFund ----------

  function testSweepHappyPathBridgesFullSurplus() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    // Tracked: 1,000 USDT internal (1e9) -> 1,000 USDT ERC20 (1e9 at 6 dec).
    exchange.setTotalSpotBalance(CCY_USDT, 1_000_000_000);
    // On-contract: 1,100 USDT -> surplus 100 USDT = 100_000_000 raw.
    _mockBalance(1_100_000_000);

    uint256 sweepAmount = 100_000_000;

    // Expect L2SharedBridge.withdraw(DESTINATION, USDT_L2, sweepAmount).
    vm.expectCall(
      L2_SHARED_BRIDGE,
      abi.encodeWithSelector(IL2SharedBridge.withdraw.selector, DESTINATION, USDT_L2, sweepAmount)
    );
    vm.expectEmit(true, true, true, true, address(exchange));
    emit OverCollateralizedFundSwept(CCY_USDT, USDT_L2, DESTINATION, sweepAmount);

    vm.prank(ADMIN);
    exchange.sweepOverCollateralizedFund(CCY_USDT, sweepAmount);
  }

  function testSweepAllowsPartialSweep() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 1_000_000_000);
    _mockBalance(1_100_000_000); // surplus = 1e8

    vm.expectCall(
      L2_SHARED_BRIDGE,
      abi.encodeWithSelector(IL2SharedBridge.withdraw.selector, DESTINATION, USDT_L2, uint256(40_000_000))
    );

    vm.prank(ADMIN);
    exchange.sweepOverCollateralizedFund(CCY_USDT, 40_000_000);
  }

  function testSweepRevertsWhenAmountExceedsSurplus() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 1_000_000_000);
    _mockBalance(1_100_000_000); // surplus = 1e8

    vm.prank(ADMIN);
    vm.expectRevert(bytes("amount exceeds over-collateralized balance"));
    exchange.sweepOverCollateralizedFund(CCY_USDT, 100_000_001);
  }

  function testSweepRevertsWhenBalanceEqualsTracked() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 1_000_000_000);
    _mockBalance(1_000_000_000); // surplus = 0

    vm.prank(ADMIN);
    vm.expectRevert(bytes("amount exceeds over-collateralized balance"));
    exchange.sweepOverCollateralizedFund(CCY_USDT, 1);
  }

  function testSweepRevertsWhenBalanceLessThanTracked() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    // Under-collateralized (liquidity in vault). surplus = 0.
    exchange.setTotalSpotBalance(CCY_USDT, 1_000_000_000);
    _mockBalance(500_000_000);

    vm.prank(ADMIN);
    vm.expectRevert(bytes("amount exceeds over-collateralized balance"));
    exchange.sweepOverCollateralizedFund(CCY_USDT, 1);
  }

  function testSweepWithZeroTrackedTreatsFullBalanceAsSurplus() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 0);
    _mockBalance(12_345_678);

    vm.expectCall(
      L2_SHARED_BRIDGE,
      abi.encodeWithSelector(IL2SharedBridge.withdraw.selector, DESTINATION, USDT_L2, uint256(12_345_678))
    );

    vm.prank(ADMIN);
    exchange.sweepOverCollateralizedFund(CCY_USDT, 12_345_678);
  }

  function testSweepWithNegativeTrackedTreatsFullBalanceAsSurplus() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, -1_000_000);
    _mockBalance(500_000);

    vm.expectCall(
      L2_SHARED_BRIDGE,
      abi.encodeWithSelector(IL2SharedBridge.withdraw.selector, DESTINATION, USDT_L2, uint256(500_000))
    );

    vm.prank(ADMIN);
    exchange.sweepOverCollateralizedFund(CCY_USDT, 500_000);
  }

  function testSweepRevertsOnZeroAmount() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    vm.prank(ADMIN);
    vm.expectRevert(bytes("invalid amount"));
    exchange.sweepOverCollateralizedFund(CCY_USDT, 0);
  }

  function testSweepRevertsOnInvalidCurrency() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    vm.prank(ADMIN);
    vm.expectRevert(bytes("invalid currency"));
    exchange.sweepOverCollateralizedFund(CCY_UNSPECIFIED, 1);
  }

  function testSweepRevertsWhenDestinationUnset() public {
    exchange.setTotalSpotBalance(CCY_USDT, 0);
    _mockBalance(1_000_000);

    vm.prank(ADMIN);
    vm.expectRevert(bytes("destination not set"));
    exchange.sweepOverCollateralizedFund(CCY_USDT, 1);
  }

  function testSweepRevertsWhenQueueNonEmpty() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 0);
    _mockBalance(1_000_000);
    exchange.pushPendingWithdrawal(address(0xBEEF), CCY_USDT, 1000);

    vm.prank(ADMIN);
    vm.expectRevert(bytes("pending withdrawal queue must be empty"));
    exchange.sweepOverCollateralizedFund(CCY_USDT, 1);
  }

  function testSweepRevertsForNonAdmin() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 0);
    _mockBalance(1_000_000);

    vm.prank(NON_ADMIN);
    vm.expectRevert();
    exchange.sweepOverCollateralizedFund(CCY_USDT, 1);
  }

  // ---------- getOverCollateralizedAmount ----------

  function testGetOverCollateralizedAmountReturnsSurplus() public {
    exchange.setTotalSpotBalance(CCY_USDT, 1_000_000_000);
    _mockBalance(1_100_000_000);

    assertEq(exchange.getOverCollateralizedAmount(CCY_USDT), 100_000_000);
  }

  function testGetOverCollateralizedAmountReturnsZeroWhenUnderCollateralized() public {
    exchange.setTotalSpotBalance(CCY_USDT, 1_000_000_000);
    _mockBalance(500_000_000);

    assertEq(exchange.getOverCollateralizedAmount(CCY_USDT), 0);
  }

  function testGetOverCollateralizedAmountReturnsZeroWhenBalancesEqual() public {
    exchange.setTotalSpotBalance(CCY_USDT, 1_000_000_000);
    _mockBalance(1_000_000_000);

    assertEq(exchange.getOverCollateralizedAmount(CCY_USDT), 0);
  }

  function testGetOverCollateralizedAmountWithNonPositiveTrackedReturnsFullBalance() public {
    exchange.setTotalSpotBalance(CCY_USDT, -42);
    _mockBalance(7_777);

    assertEq(exchange.getOverCollateralizedAmount(CCY_USDT), 7_777);
  }

  function testGetOverCollateralizedAmountRevertsOnInvalidCurrency() public {
    vm.expectRevert(bytes("invalid currency"));
    exchange.getOverCollateralizedAmount(CCY_UNSPECIFIED);
  }

  // ---------- sweepAllOverCollateralizedFund ----------

  function testSweepAllBridgesEntireSurplusAndReturnsSwept() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 1_000_000_000);
    _mockBalance(1_100_000_000); // surplus = 1e8

    uint256 expected = 100_000_000;

    vm.expectCall(
      L2_SHARED_BRIDGE,
      abi.encodeWithSelector(IL2SharedBridge.withdraw.selector, DESTINATION, USDT_L2, expected)
    );
    vm.expectEmit(true, true, true, true, address(exchange));
    emit OverCollateralizedFundSwept(CCY_USDT, USDT_L2, DESTINATION, expected);

    vm.prank(ADMIN);
    uint256 swept = exchange.sweepAllOverCollateralizedFund(CCY_USDT);
    assertEq(swept, expected);
  }

  function testSweepAllWithZeroTrackedBridgesFullBalance() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 0);
    _mockBalance(99_999);

    vm.expectCall(
      L2_SHARED_BRIDGE,
      abi.encodeWithSelector(IL2SharedBridge.withdraw.selector, DESTINATION, USDT_L2, uint256(99_999))
    );

    vm.prank(ADMIN);
    uint256 swept = exchange.sweepAllOverCollateralizedFund(CCY_USDT);
    assertEq(swept, 99_999);
  }

  function testSweepAllRevertsWhenSurplusIsZero() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 1_000_000_000);
    _mockBalance(1_000_000_000);

    vm.prank(ADMIN);
    vm.expectRevert(bytes("no over-collateralized balance"));
    exchange.sweepAllOverCollateralizedFund(CCY_USDT);
  }

  function testSweepAllRevertsWhenUnderCollateralized() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 1_000_000_000);
    _mockBalance(500_000_000);

    vm.prank(ADMIN);
    vm.expectRevert(bytes("no over-collateralized balance"));
    exchange.sweepAllOverCollateralizedFund(CCY_USDT);
  }

  function testSweepAllRevertsOnInvalidCurrency() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    vm.prank(ADMIN);
    vm.expectRevert(bytes("invalid currency"));
    exchange.sweepAllOverCollateralizedFund(CCY_UNSPECIFIED);
  }

  function testSweepAllRevertsWhenDestinationUnset() public {
    exchange.setTotalSpotBalance(CCY_USDT, 0);
    _mockBalance(1_000_000);

    vm.prank(ADMIN);
    vm.expectRevert(bytes("destination not set"));
    exchange.sweepAllOverCollateralizedFund(CCY_USDT);
  }

  function testSweepAllRevertsWhenQueueNonEmpty() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 0);
    _mockBalance(1_000_000);
    exchange.pushPendingWithdrawal(address(0xBEEF), CCY_USDT, 1000);

    vm.prank(ADMIN);
    vm.expectRevert(bytes("pending withdrawal queue must be empty"));
    exchange.sweepAllOverCollateralizedFund(CCY_USDT);
  }

  function testSweepAllRevertsForNonAdmin() public {
    vm.prank(ADMIN);
    exchange.setOverCollateralizedFundDestination(DESTINATION);

    exchange.setTotalSpotBalance(CCY_USDT, 0);
    _mockBalance(1_000_000);

    vm.prank(NON_ADMIN);
    vm.expectRevert();
    exchange.sweepAllOverCollateralizedFund(CCY_USDT);
  }
}
