// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./HelperContract.sol";
import "./signature/generated/TransferSig.sol";
import "../DataStructure.sol";
import "../util/Address.sol";

abstract contract OracleContract is HelperContract {
  // TODO
  // 1. PRICING
  // get spot price
  // get interest rate
  // get deriv price
  // get settlement
  //
  // 2. Get Total Value to prevent overwithdrawal
  // getTotalValue
  // How to organize positions?
  // Requirements
  // - Trade: find positions and update the balance of multiple parties
  // - Liquidation: iterate through all positions to compute SPAN margin
  // - Deleverage: iterate through all positions to compute SPAN margin
  // - Withdraw/Transfer: iterate
  // - Funding perpetual: iterate through perps to compute new balance
  // - Settlement tick: either eager or lazily update

  // TODO
  function _getDerivPrice(uint128 id) internal pure returns (uint256) {
    return uint256(id);
  }

  // TODO
  function _getInterestRate(uint128 id) internal pure returns (uint256) {
    return uint256(id);
  }
}
