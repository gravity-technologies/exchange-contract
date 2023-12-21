// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// All percentage are represented with as integer with 9 decimal points
int128 constant SETTLEMENT_UNDERLYING_CHARGE_PCT = 15e6; // 0.015%
int128 constant SETTLEMENT_TRADE_PRICE_PCT = 125e8; // 12.5%

// Charge a flat rate for withdrawal
// FIXME: change it to a config
int128 constant WITHDRAWAL_FEE = 1e9; // 1 USDC
