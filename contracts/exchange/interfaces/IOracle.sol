pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface IOracle {
  /**
   * @notice Update the oracle mark prices for spot, futures, and options
   * @param timestamp The timestamp of the price tick
   * @param txID The transaction ID of the price tick
   * @param prices The prices of the assets
   * @param sig The signature of the price tick
   */
  function markPriceTick(int64 timestamp, uint64 txID, PriceEntry[] calldata prices, Signature calldata sig) external;

  /**
   * @notice Update the funding prices for perpetuals
   * @param timestamp The timestamp of the price tick
   * @param txID The transaction ID of the price tick
   * @param prices The funding tick values
   * @param sig The signature of the price tick
   */
  function fundingPriceTick(
    int64 timestamp,
    uint64 txID,
    PriceEntry[] calldata prices,
    Signature calldata sig
  ) external;
}
