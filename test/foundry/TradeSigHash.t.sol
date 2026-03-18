pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import "../../contracts/exchange/api/signature/generated/TradeSig.sol";
import "../../contracts/exchange/types/DataStructure.sol";
import "../../contracts/exchange/types/Enum.sol";

contract TradeSigHarness {
  function hashOrderHarness(Order calldata order) external pure returns (bytes32) {
    return hashOrder(order);
  }

  function hashOrderLegsHarness(OrderLeg[] calldata legs) external pure returns (bytes32) {
    return hashOrderLegs(legs);
  }
}

contract TradeSigReferenceHarness {
  function hashOrderHarness(Order calldata o) external pure returns (bytes32) {
    if (o.builder == address(0) && o.builderFee == 0) {
      return
        keccak256(
          abi.encode(
            _ORDER_H,
            o.subAccountID,
            o.isMarket,
            o.timeInForce,
            o.postOnly,
            o.reduceOnly,
            hashOrderLegsHarness(o.legs),
            o.signature.nonce,
            o.signature.expiration
          )
        );
    }

    return
      keccak256(
        abi.encode(
          _ORDER_WITH_BUILDER_FEE_H,
          o.subAccountID,
          o.isMarket,
          o.timeInForce,
          o.postOnly,
          o.reduceOnly,
          hashOrderLegsHarness(o.legs),
          o.builder,
          o.builderFee,
          o.signature.nonce,
          o.signature.expiration
        )
      );
  }

  function hashOrderLegsHarness(OrderLeg[] calldata legs) public pure returns (bytes32) {
    uint256 numLegs = legs.length;
    bytes32[] memory hashedLegs = new bytes32[](numLegs);
    for (uint256 i; i < numLegs; ++i) {
      OrderLeg calldata leg = legs[i];
      hashedLegs[i] = keccak256(abi.encode(_LEG_H, leg.assetID, leg.size, leg.limitPrice, leg.isBuyingAsset));
    }
    return keccak256(abi.encodePacked(hashedLegs));
  }
}

contract TradeSigHashTest is Test {
  TradeSigHarness internal optimized;
  TradeSigReferenceHarness internal referenceHarness;

  function setUp() public {
    optimized = new TradeSigHarness();
    referenceHarness = new TradeSigReferenceHarness();
  }

  function testHashOrderMatchesReferenceSingleLegNoBuilder() public {
    Order memory order = _makeOrder(1, false, false, -1);
    assertEq(optimized.hashOrderHarness(order), referenceHarness.hashOrderHarness(order));
  }

  function testHashOrderMatchesReferenceSingleLegWithBuilder() public {
    Order memory order = _makeOrder(1, true, true, type(int64).min);
    assertEq(optimized.hashOrderHarness(order), referenceHarness.hashOrderHarness(order));
  }

  function testHashOrderMatchesReferenceMultiLeg() public {
    Order memory order = _makeOrder(3, true, false, -123456789);
    assertEq(optimized.hashOrderHarness(order), referenceHarness.hashOrderHarness(order));
  }

  function testHashOrderLegsMatchesReferenceForOneAndMany() public {
    Order memory singleOrder = _makeOrder(1, false, false, 0);
    assertEq(optimized.hashOrderLegsHarness(singleOrder.legs), referenceHarness.hashOrderLegsHarness(singleOrder.legs));

    Order memory multiOrder = _makeOrder(4, false, true, -999);
    assertEq(optimized.hashOrderLegsHarness(multiOrder.legs), referenceHarness.hashOrderLegsHarness(multiOrder.legs));
  }

  function testHashOrderSingleLegUsesLessGasWithoutBuilder() public {
    Order memory order = _makeOrder(1, false, true, -7);

    uint256 gasStart = gasleft();
    bytes32 optimizedHash = optimized.hashOrderHarness(order);
    uint256 optimizedGas = gasStart - gasleft();

    gasStart = gasleft();
    bytes32 referenceHash = referenceHarness.hashOrderHarness(order);
    uint256 referenceGas = gasStart - gasleft();

    assertEq(optimizedHash, referenceHash);
    assertLt(optimizedGas, referenceGas);
  }

  function testHashOrderSingleLegUsesLessGasWithBuilder() public {
    Order memory order = _makeOrder(1, true, false, -77);

    uint256 gasStart = gasleft();
    bytes32 optimizedHash = optimized.hashOrderHarness(order);
    uint256 optimizedGas = gasStart - gasleft();

    gasStart = gasleft();
    bytes32 referenceHash = referenceHarness.hashOrderHarness(order);
    uint256 referenceGas = gasStart - gasleft();

    assertEq(optimizedHash, referenceHash);
    assertLt(optimizedGas, referenceGas);
  }

  function _makeOrder(uint256 legCount, bool withBuilder, bool isMarket, int64 expiration) internal pure returns (Order memory order) {
    order.subAccountID = type(uint64).max - uint64(legCount);
    order.isMarket = isMarket;
    order.timeInForce = TimeInForce.FILL_OR_KILL;
    order.postOnly = !isMarket;
    order.reduceOnly = withBuilder;
    order.legs = new OrderLeg[](legCount);

    for (uint256 i; i < legCount; ++i) {
      order.legs[i] = OrderLeg({
        assetID: bytes32(uint256(0x1000 + i)),
        size: type(uint64).max - uint64(i),
        limitPrice: uint64(100_000 + i),
        isBuyingAsset: i % 2 == 0
      });
    }

    order.signature = Signature({
      signer: address(0),
      r: bytes32(0),
      s: bytes32(0),
      v: 0,
      expiration: expiration,
      nonce: type(uint32).max - uint32(legCount),
      chainId: 0
    });
    order.builder = withBuilder ? address(0xBEEF) : address(0);
    order.builderFee = withBuilder ? uint32(1234) : uint32(0);
  }
}
