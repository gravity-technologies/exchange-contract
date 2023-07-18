// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Derivative, Instrument, Currency} from './DataStructure.sol';

function idToDerivative(uint128 data) pure returns (Derivative memory) {
  return
    Derivative(
      Instrument.CALL,
      Currency.BTC,
      Currency.USDC,
      uint8(data & 7),
      20,
      1234000
    );
}

function derivativeToId(Derivative memory deriv) pure returns (uint128) {
  return uint128(deriv.strikePrice);
}
