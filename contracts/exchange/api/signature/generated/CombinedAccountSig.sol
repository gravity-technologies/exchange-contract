// Code generated, DO NOT EDIT.
pragma solidity ^0.8.20;

import "../../../types/DataStructure.sol";

bytes32 constant _CREATE_ACCOUNT_WITH_SUBACCOUNT_H = keccak256(
  "CreateAccountWithSubAccount(address accountID,uint64 subAccountID,uint8 quoteCurrency,uint8 marginType,uint32 nonce,int64 expiration)"
);

function hashCreateAccountWithSubAccount(
  address accountID,
  uint64 subAccountID,
  Currency quoteCurrency,
  MarginType marginType,
  uint32 nonce,
  int64 expiration
) pure returns (bytes32) {
  return
    keccak256(
      abi.encode(
        _CREATE_ACCOUNT_WITH_SUBACCOUNT_H,
        accountID,
        subAccountID,
        uint8(quoteCurrency),
        uint8(marginType),
        nonce,
        expiration
      )
    );
}
