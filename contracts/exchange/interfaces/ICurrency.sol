pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface ICurrency {
  function addCurrency(int64 timestamp, uint64 txID, uint16 id, uint16 balanceDecimals) external;
}
