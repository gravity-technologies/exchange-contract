// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _ORACLE_H = keccak256("Data(Values[] values,int256 timestamp)Values(int256 sid,int256 v)");
bytes32 constant _ORACLE_VALUE_H = keccak256("Values(int256 sid,int256 v)");

bytes32 constant _UPDATE_FUNDING_INFO_H = keccak256(
  "UpdateFundingInfo(FundingInfo[] byAsset,uint32 nonce,int64 expiration)FundingInfo(uint256 asset,uint8 intervalHours,int32 fundingRateHighCentiBeeps,int32 fundingRateLowCentiBeeps,int64 updateTime)"
);
bytes32 constant _FUNDING_INFO_H = keccak256(
  "FundingInfo(uint256 asset,uint8 intervalHours,int32 fundingRateHighCentiBeeps,int32 fundingRateLowCentiBeeps,int64 updateTime)"
);

bytes32 constant _FUNDING_TICK_H = keccak256(
  "FundingTick(FundingRateEntry[] entries,uint32 nonce,int64 expiration)FundingRateEntry(uint256 asset,int32 fundingRateCentiBeeps,uint8 intervalHours,int64 intervalStart,int64 intervalEnd)"
);
bytes32 constant _FUNDING_RATE_ENTRY_H = keccak256(
  "FundingRateEntry(uint256 asset,int32 fundingRateCentiBeeps,uint8 intervalHours,int64 intervalStart,int64 intervalEnd)"
);

function hashOraclePrice(int64 timestamp, PriceEntry[] calldata prices) pure returns (bytes32) {
  uint numValues = prices.length;
  bytes32[] memory hashedPricesElements = new bytes32[](prices.length);
  for (uint i; i < numValues; ++i) {
    hashedPricesElements[i] = keccak256(abi.encode(_ORACLE_VALUE_H, prices[i].assetID, prices[i].value));
  }
  bytes memory pricesEncoded = abi.encodePacked(hashedPricesElements);
  return keccak256(abi.encode(_ORACLE_H, keccak256(pricesEncoded), timestamp));
}

function hashUpdateFundingInfo(
  AssetFundingInfo[] calldata fundingInfos,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return keccak256(abi.encode(_UPDATE_FUNDING_INFO_H, hashFundingInfos(fundingInfos), nonce, expiration));
}

function hashFundingInfos(AssetFundingInfo[] calldata infos) pure returns (bytes32) {
  uint len = infos.length;
  bytes32[] memory hashed = new bytes32[](len);
  for (uint i; i < len; ++i) {
    hashed[i] = hashFundingInfo(infos[i]);
  }
  return keccak256(abi.encodePacked(hashed));
}

function hashFundingInfo(AssetFundingInfo calldata info) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(
        _FUNDING_INFO_H,
        info.asset,
        info.intervalHours,
        info.fundingRateHighCentiBeeps,
        info.fundingRateLowCentiBeeps,
        info.updateTime
      )
    );
}

function hashFundingTickV2(FundingRateEntry[] calldata entries, uint32 nonce, int64 expiration) pure returns (bytes32) {
  return keccak256(abi.encode(_FUNDING_TICK_H, hashFundingRateEntries(entries), nonce, expiration));
}

function hashFundingRateEntries(FundingRateEntry[] calldata entries) pure returns (bytes32) {
  uint len = entries.length;
  bytes32[] memory hashed = new bytes32[](len);
  for (uint i; i < len; ++i) {
    FundingRateEntry calldata entry = entries[i];
    hashed[i] = keccak256(
      abi.encode(
        _FUNDING_RATE_ENTRY_H,
        entry.asset,
        entry.fundingRateCentiBeeps,
        entry.intervalHours,
        entry.intervalStart,
        entry.intervalEnd
      )
    );
  }
  return keccak256(abi.encodePacked(hashed));
}
