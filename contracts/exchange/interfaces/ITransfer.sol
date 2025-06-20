pragma solidity ^0.8.20;

import "../types/DataStructure.sol";

interface ITransfer {
  struct WithdrawalInfo {
    Currency currency;
    int64 amount;
    int64 socializedLossHaircutAmount;
    int64 withdrawalFeeCharged;
    int64 amountToSend;
    address erc20Address;
    uint256 erc20AmountToSend;
  }

  event Withdrawal(
    address indexed fromAccount,
    address indexed recipient, // the recipient of the withdrawal on L1
    uint64 txID,
    WithdrawalInfo withdrawalInfo
  );

  event Deposit(
    address indexed toAccount,
    bytes32 indexed bridgeMintHash, // the hash of the BridgeMint event on L2
    Currency currency,
    uint64 numTokens,
    uint64 txID
  );

  /**
   * @notice Deposit collateral into a sub account
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param txHash hash of the BridgeMint event
   * @param accountID  account to deposit into
   * @param currency Currency to deposit
   * @param numTokens Number of tokens to deposit
   **/
  function deposit(
    int64 timestamp,
    uint64 txID,
    bytes32 txHash,
    address accountID,
    Currency currency,
    uint64 numTokens
  ) external;

  /**
   * @notice Withdraw collateral from a sub account. This will call external contract.
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromAccID Sub account to withdraw from
   * @param recipient address of the recipient
   * @param currency Currency to withdraw
   * @param numTokens Number of tokens to withdraw
   * @param sig Signature of the transaction
   **/
  function withdraw(
    int64 timestamp,
    uint64 txID,
    address fromAccID,
    address recipient,
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) external;

  /**
   * @notice Transfer tokens from one sub account to another sub account
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromAccID Sub account to transfer from
   * @param fromSubID Sub account to transfer from
   * @param toAccID Sub account to transfer to
   * @param toSubID Sub account to transfer to
   * @param currency Currency to transfer
   * @param numTokens Number of tokens to transfer
   * @param sig Signature of the transaction
   */
  function transfer(
    int64 timestamp,
    uint64 txID,
    address fromAccID,
    uint64 fromSubID,
    address toAccID,
    uint64 toSubID,
    Currency currency,
    uint64 numTokens,
    Signature calldata sig
  ) external;
}
