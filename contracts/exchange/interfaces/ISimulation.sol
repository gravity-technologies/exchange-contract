pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface ISimulation {
  function simulate(
    uint64 submitterLastTxID,
    bytes[] calldata txs,
    bytes[] calldata txAssertions,
    uint256[][] calldata relevantTicks
  ) external returns (uint64[] memory sequencedTxIDs);
}
