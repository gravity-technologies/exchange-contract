// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

bytes32 constant _DEPOSIT_SAFETY_MOD_H = keccak256(
  "DepositIntoSafetyModulePayload(address subAccountID,uint8 quote,uint8 underlying,uint64 numTokens,uint32 nonce)"
);

function hashDepositSafetyMod(
  address subID,
  uint8 quote,
  uint8 underlying,
  uint64 qty,
  uint32 nonce
) pure returns (bytes32) {
  return keccak256(abi.encode(_DEPOSIT_SAFETY_MOD_H, subID, quote, underlying, qty, nonce));
}

bytes32 constant _WITHDRAW_SAFETY_MOD_H = keccak256(
  "WithdrawFromSafetyModulePayload(address subAccountID,uint8 quote,uint8 underlying,uint64 numTokens, uint32 nonce)"
);

function hashWithdrawSafetyMod(
  address subID,
  uint8 quote,
  uint8 base,
  uint64 qty,
  uint32 nonce
) pure returns (bytes32) {
  return keccak256(abi.encode(_WITHDRAW_SAFETY_MOD_H, subID, quote, base, qty, nonce));
}
