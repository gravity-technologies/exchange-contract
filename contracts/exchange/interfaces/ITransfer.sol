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

  event L1DefiVaultAddressSet(address indexed recipient);

  event NativeVaultGatewayAddressSet(address indexed recipient);

  event L1DefiVaultBridge(address indexed l2Token, uint256 amount, address indexed recipient);

  event OverCollateralizedFundDestinationSet(address indexed destination);

  event OverCollateralizedFundSwept(
    Currency indexed currency,
    address indexed erc20Address,
    address indexed destination,
    uint256 amount
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

  /// @notice Drains queued withdrawals in FIFO order while L2 liquidity is sufficient for the queue head.
  /// @dev Callable only by the liquidity orchestrator to resume progress after L2 top-up.
  /// @param maxCount Maximum number of queued withdrawals to process in this call (0 = unlimited).
  function processWithdrawalQueue(uint256 maxCount) external;

  /// @notice Sets the L1 DeFi vault address for direct bridge operations. Can only be called once.
  function setL1DefiVaultAddress(address recipient) external;

  /// @notice Returns the L1 DeFi vault address used by direct bridge operations.
  function getL1DefiVaultAddress() external view returns (address);

  /// @notice Sets the L1 native vault gateway address for ETH bridge operations. Can only be called once.
  function setNativeVaultGatewayAddress(address recipient) external;

  /// @notice Returns the L1 native vault gateway address used by ETH bridge operations.
  function getNativeVaultGatewayAddress() external view returns (address);

  /// @notice Bridges L2 vault assets held by the exchange to L1.
  /// @dev ERC20 assets go directly to the configured L1 DeFi vault. ETH uses the shared bridge
  ///      withdrawal flow and routes to the native vault gateway.
  /// @dev Callable only by the liquidity orchestrator.
  function bridgeToL1DefiVault(address l2Token, uint256 amount) external;

  /// @notice Sets the L1 destination used by sweepOverCollateralizedFund. Updatable by admin.
  function setOverCollateralizedFundDestination(address destination) external;

  /// @notice Returns the L1 destination used by sweepOverCollateralizedFund.
  function getOverCollateralizedFundDestination() external view returns (address);

  /// @notice Returns the current over-collateralized surplus for a currency in raw ERC20
  ///         native-decimal units.
  function getOverCollateralizedAmount(Currency currency) external view returns (uint256);

  /// @notice Bridges a caller-specified portion of the ERC20 surplus (exchange balance in
  ///         excess of totalSpotBalances) to the admin-configured L1 recovery destination.
  /// @param currency The spot currency whose surplus to sweep.
  /// @param amount   Raw ERC20 amount in the token's native decimals (NOT the exchange's
  ///                 internal int64 balance-decimal representation). Passed directly to
  ///                 IL2SharedBridge.withdraw. Must be <=
  ///                 erc20Balance(this) - scaledInternalTotalSpotBalances(currency).
  /// @dev Callable only by DEFAULT_ADMIN_ROLE. Requires the pending withdrawal queue to be
  ///      empty so that queued (but not yet bridged) user withdrawals are not counted as
  ///      surplus.
  function sweepOverCollateralizedFund(Currency currency, uint256 amount) external;

  /// @notice Bridges the entire current ERC20 surplus for a currency to the admin-configured
  ///         L1 recovery destination.
  /// @return swept Raw ERC20 amount bridged out.
  /// @dev Same role and precondition rules as sweepOverCollateralizedFund. Reverts if the
  ///      surplus is zero.
  function sweepAllOverCollateralizedFund(Currency currency) external returns (uint256 swept);

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

  /**
   * @notice Transfer tokens from one sub account to another sub account with explicit wallet type routing
   *
   * @param timestamp Timestamp of the transaction
   * @param txID Transaction ID
   * @param fromAccID Sub account to transfer from
   * @param fromSubID Sub account to transfer from
   * @param toAccID Sub account to transfer to
   * @param toSubID Sub account to transfer to
   * @param currency Currency to transfer
   * @param numTokens Number of tokens to transfer
   * @param fromWalletType Source wallet type (UNSPECIFIED resolves to default)
   * @param toWalletType Destination wallet type (UNSPECIFIED resolves to default)
   * @param sig Signature of the transaction
   */
  function transferV2(
    int64 timestamp,
    uint64 txID,
    address fromAccID,
    uint64 fromSubID,
    address toAccID,
    uint64 toSubID,
    Currency currency,
    uint64 numTokens,
    WalletType fromWalletType,
    WalletType toWalletType,
    Signature calldata sig
  ) external;
}
