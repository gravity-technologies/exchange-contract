// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/exchange/util/Asset.sol";
import "../../../contracts/exchange/types/DataStructure.sol";

struct AssetTestCase {
  Asset asset;
  string name;
  bytes32 expectedID;
}

contract AssetHelperTest is Test {
  function testParseAssetID() public {
    AssetTestCase[8] memory testCases;
    uint id = 0;

    // Empty
    testCases[id] = AssetTestCase({
      name: "ETH USDC Perp",
      asset: Asset({
        kind: Kind.UNSPECIFIED,
        underlying: Currency.UNSPECIFIED,
        quote: Currency.UNSPECIFIED,
        expiration: int64(0),
        strikePrice: uint64(0)
      }),
      expectedID: bytes32(uint(0x0000000000000000000000000000000000000000000000000000000000000000))
    });
    id++;

    // Perp
    testCases[id] = AssetTestCase({
      name: "ETH USDC Perp",
      asset: Asset({
        kind: Kind.PERPS,
        underlying: Currency.ETH,
        quote: Currency.USDC,
        expiration: int64(0),
        strikePrice: uint64(0)
      }),
      expectedID: bytes32(uint(0x0000000000000000000000000000000000000000000000000000000000020401))
    });
    id++;

    // Future
    testCases[id] = AssetTestCase({
      name: "BTC USDT Fut 20Oct23",
      asset: Asset({
        kind: Kind.FUTURES,
        underlying: Currency.BTC,
        quote: Currency.USDT,
        expiration: int64(1697801813_000_000_000),
        strikePrice: uint64(0)
      }),
      expectedID: bytes32(0x0000000000000000000000000000000000000000178fcdc0eae1120000030502)
    });
    id++;

    // Call
    testCases[id] = AssetTestCase({
      name: "ETH USDC Call 20Oct23 4123",
      asset: Asset({
        kind: Kind.CALL,
        underlying: Currency.ETH,
        quote: Currency.USDC,
        expiration: int64(1697801813_000_000_000),
        strikePrice: uint64(4123_000_000)
      }),
      expectedID: bytes32(0x00000000000000000000000000000000f5bffcc0178fcdc0eae1120000020403)
    });
    id++;

    // Put
    testCases[id] = AssetTestCase({
      name: "USDT BTC Put 20Oct23 4123",
      asset: Asset({
        kind: Kind.PUT,
        quote: Currency.BTC,
        underlying: Currency.USDT,
        expiration: int64(1697801813_000_000_000),
        strikePrice: uint64(4123_000_000_000)
      }),
      expectedID: bytes32(0x000000000000000000000000000003bff5f34e00178fcdc0eae1120000050304)
    });
    id++;

    // Spot
    testCases[id] = AssetTestCase({
      name: "USDC Spot",
      asset: Asset({
        kind: Kind.SPOT,
        underlying: Currency.USDC,
        quote: Currency.UNSPECIFIED,
        expiration: int64(0),
        strikePrice: uint64(0)
      }),
      expectedID: bytes32(0x0000000000000000000000000000000000000000000000000000000000000205)
    });
    id++;

    // Settlement
    testCases[id] = AssetTestCase({
      name: "ETH Sett 20Oct23",
      asset: Asset({
        kind: Kind.SETTLEMENT,
        underlying: Currency.ETH,
        quote: Currency.USD,
        expiration: int64(1697801813_000_000_000),
        strikePrice: uint64(0)
      }),
      expectedID: bytes32(0x0000000000000000000000000000000000000000178fcdc0eae1120000010406)
    });
    id++;

    // Rate
    testCases[id] = AssetTestCase({
      name: "ETH Rate 20Oct23",
      asset: Asset({
        kind: Kind.RATE,
        underlying: Currency.ETH,
        quote: Currency.USD,
        expiration: int64(1697801813_000_000_000),
        strikePrice: uint64(0)
      }),
      expectedID: bytes32(0x0000000000000000000000000000000000000000178fcdc0eae1120000010407)
    });
    id++;

    for (uint i = 0; i < testCases.length; i++) {
      AssetTestCase memory tc = testCases[i];
      Asset memory asset = tc.asset;
      bytes32 expectedID = tc.expectedID;
      bytes32 actualID = bytes32(assetToID(asset));
      assertEq(expectedID, actualID, concat(tc.name, " ids mismatch"));
      assertEq(uint(asset.kind), uint(assetGetKind(actualID)), concat(tc.name, " kind mismatch"));
      assertEq(uint(asset.underlying), uint(assetGetUnderlying(actualID)), concat(tc.name, " underlying mismatch"));
      assertEq(uint(asset.quote), uint(assetGetQuote(actualID)), concat(tc.name, " quote mismatch"));
      assertEq(asset.expiration, assetGetExpiration(actualID), concat(tc.name, " expiration mismatch"));
      assertEq(asset.strikePrice, assetGetStrikePrice(actualID), concat(tc.name, " strike price mismatch"));
    }
  }

  function concat(string memory a, string memory b) public pure returns (string memory) {
    return string(abi.encodePacked(a, b));
  }
}
