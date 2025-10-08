pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface IFundingConfig {
  function updateFundingInfo(
    int64 timestamp,
    uint64 txID,
    AssetFundingInfo[] calldata fundingInfos,
    Signature calldata sig
  ) external;
}
