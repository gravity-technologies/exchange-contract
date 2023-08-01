// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

enum MarginType {
  UNSPECIFIED,
  ISOLATED,
  SIMPLE_CROSS_MARGIN,
  PORTFOLIO_CROSS_MARGIN
}

enum Currency {
  UNSPECIFIED,
  USDC,
  USDT,
  ETH,
  BTC
}

enum Instrument {
  UNSPECIFIED,
  PERPS,
  FUTURES,
  CALL,
  PUT
}

enum AccountRecoveryType {
  UNSPECIFIED,
  GUARDIAN,
  SUB_ACCOUNT_SIGNERS
}

// SubAccountPermissions:
// Permission is represented as a uint64 value, where each bit represents a permission. The value defined below is a bit mask for each permission
// To check if user has a certain permission, just do a bitwise AND
// ie: permission & mask > 0
uint64 constant SubAccountPermAdmin = 1;
uint64 constant SubAccountPermDeposit = 1 << 1;
uint64 constant SubAccountPermWithdrawal = 1 << 2;
uint64 constant SubAccountPermTransfer = 1 << 3;
uint64 constant SubAccountPermTrade = 1 << 4;
uint64 constant SubAccountPermAddSigner = 1 << 5;
uint64 constant SubAccountPermRemoveSigner = 1 << 6;
uint64 constant SubAccountPermUpdteSignerPermission = 1 << 7;
uint64 constant SubAccountPermChangeMarginType = 1 << 8;

struct Signature {
  // The address of the signer
  address signer;
  bytes32 r;
  bytes32 s;
  uint8 v;
  // Timestamp after which this signature expires. Use 0 for no expiration.
  uint64 expiration;
}

struct State {
  // Accounts and Sessions
  mapping(uint32 => Account) accounts;
  mapping(address => SubAccount) subAccounts;
  mapping(address => SessionKey) sessionKeys;
  // This tracks the number of contract that has been matched
  // Also used to prevent replay attack
  SignatureState signatures;
  // Oracle prices: Spot, Interest Rate, Volatility
  PriceState prices;
  // Configuration
  ConfigState config;
  // A Safety Module is created per quote + underlying currency pair
  mapping(Currency => mapping(Currency => SafetyModulePool)) safetyModule;
  // Latest Transaction time
  uint64 timestamp;
  // Latest Transaction ID
  uint64 lastTxID;
}

struct Account {
  uint32 id;
  // Number of account admin signers required to make any privileged changes on the account level. Defaults to 1
  // This affects the multi-sigs required to onboard new account admins, guardians, withdrawal, and transfer addresses
  // uint256 instead of uint8 to reduce gas cost
  // See :
  //   - https://docs.soliditylang.org/en/v0.8.17/internals/layout_in_storage.html#layout-of-state-variables-in-storage
  //   - https://ethereum.stackexchange.com/questions/3067/why-does-uint8-cost-more-gas-than-uint256
  uint multiSigThreshold;
  // All users who have Account Admin privileges. They automatically inherit all SubAccountPermissions on subaccount level
  address[] admins;
  // Guardians who are authorized to participate in key recovery quorum
  // Both retail and institutional accounts can rely on guardians for key recovery
  // Institutions have an additional option to rely on their sub account signers
  address[] guardians;
  // All subaccounts belonging to the account can only withdraw assets to these L1 Wallet addresses
  address[] onboardedWithdrawalAddresses;
  // All subaccounts belonging to the account can only transfer assets to these L2 Sub Accounts
  address[] onboardedTransferSubAccounts;
  // A record of all SubAccounts owned by the account
  // Helps in sub account signer quorum computation during key recovery
  address[] subAccounts;
}

struct SubAccount {
  // The wallet address of this subaccount, which also acts as the subaccount ID
  address id;
  // The Account that this Sub Account belongs to
  uint32 accountID;
  MarginType marginType;
  // The Quote Currency that this Sub Account is denominated in
  Currency quoteCurrency;
  // The total amount of base currency that the sub account possesses
  // Expressed in base currency decimal units
  int64 balance;
  // The total amount of base currency that the sub account has deposited, but not yet confirmed by L1 finality
  // Take this into account when liquidating a sub account
  // But do not take this into account when calculating the sub account's balance
  // Expressed in base currency decimal units
  uint64 pendingDeposits;
  // Mapping from the uint128 representation to derivate position
  DerivativePosition[] derivativePositions;
  // Signers who are authorized to trade on this sub account
  Signer[] authorizedSigners;
  // The timestamp that the sub account was last funded at
  uint64 lastAppliedFundingTimestamp;
}

struct Derivative {
  Instrument instrument;
  Currency underlying;
  Currency quote;
  uint32 expiration;
  uint64 strikePrice;
}

struct DerivativePosition {
  // The derivative contract held in this position
  Derivative derivative;
  // Number of contracts held in this position
  int64 contractBalance;
  // The average entry price of the contracts held in this position
  // Used for computing unrealized P&L
  // This value experiences rounding errors, so it is not guaranteed to be accurate, use as an indicator only
  // Important to track on StateMachine to serve unrealized P&L queries, but not important to track on the
  // smart contract. Smart contract doesn't rely on this field for any logic
  uint64 averageEntryPrice;
  // (expressed in USD with 10 decimal points)
  uint64 lastAppliedFundingIndex;
}

struct Signer {
  // The public key of the signer
  address signingKey;
  // Bitmask of SubAccountPermissions (Deposit, Withdraw, Transfer, Trade, Add Signer, Remove Signer, Change Margin Type)
  uint64 permission;
}

struct SignatureState {
  mapping(bytes32 => bool) fullDerivativeOrderMatched;
  mapping(bytes32 => uint64[]) partialDerivativeOrderMatched;
  // This mapping is used to prevent replay attack. Check if a certain signature has been executed before
  mapping(bytes32 => bool) isExecuted;
}

struct PriceState {
  // No need to store oracle prices, they are lazily uploaded at point of liquidation

  // Prior to any trade, funding must be applied
  // We centrally upload funding rates. On smart contract side, we simply apply a tiny minmax clamp
  // So that users are only minimally impacted if GRVT exhibits bad integrity
  // USD is always expressed as a uint64 with 10 decimal points
  // TODO: this uint128 represents the derivative
  mapping(uint128 => uint64) fundingIndices;
  uint64 previousFundingTimestamp;
  // For each underlying/expiration pair, there will be one settled price
  // Prior to any trade, settlement must be applied
  // FIXME: review data type
  mapping(Instrument => uint64) settledPrices;
}

// There is only one settled price per underlying/expiration pair
struct SettledInstrument {
  Currency underlying;
  uint32 expiration;
}

// TODO: align on the set of configs
struct ConfigState {
  // eg. 5% = 500bps = 50000 CentiBeeps
  uint64 safetyModuleTargetInsuranceToDailyVolumeRatio;
  uint64 safetyModuleLiquidationFee;
  // This is the address of the gravity wallet that supports the recovery of the admin wallet
  address gravityAdminRecoveryWallet;
}

// TODO: align on the set of configs
struct RiskConfig {
  // fxp 3.2
  uint32[] spotMoves;
  // fxp 3.2
  uint32[] volMoves;
  // discount
  uint32 discount;
}

struct SessionKey {
  // If this is a session key, this is the main signing key that owns the session key
  // The smart contract will validate that the session key only has a subset of the main signing key's SubAccountPermissions
  // MainSigningKey ContractAddress

  // The session key that is tagged to the main signing key
  address sessionKey;
  // The last timestamp that the signer can sign at
  // We can apply a _max one day expiry on session keys
  uint64 authorizationExpiry;
}

// See https://docs.google.com/document/d/1nXArbQMm-wbdRCoYR8FSPKCHZQxT8sAm8cjhq_16jSw/edit#heading=h.fqlr6k6zp9p2
// Liquidation Fee is hard coded by config at eg. 75bps
// The contribution of the liquidation fee towards the safety module follows the insurance fee curve
// Use a sigmoid curve like https://en.wikipedia.org/wiki/Generalised_logistic_function
struct SafetyModulePool {
  // Maps SubAccounts to their LP Tokens
  mapping(address => uint64) lpTokens;
  // Depositors receive LP Tokens equivalent to (DepositSize * TotalLpTokens / TotalBalance)
  // Withdrawers receive Quote Currency equivalent to (LpTokensReturned * TotalBalance / TotalLpTokens)
  uint64 totalLpTokens;
  uint64 totalBalance;
}
