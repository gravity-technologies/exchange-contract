pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface ITrade {
  /**
   * @notice Execute a trade between a taker and multiple makers
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param trade The trade details including taker order and maker matches
   */
  function tradeDeriv(int64 timestamp, uint64 txID, Trade calldata trade) external;

  function addIsolatedPositionMargin(
    int64 timestamp,
    uint64 txID,
    uint64 subAccountID,
    bytes32 assetID,
    int64 amount,
    Signature calldata sig
  ) external;
}
