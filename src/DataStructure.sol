// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

enum Currency {
  USDC,
  BTC,
  ETH
}

enum Instrument {
  FUTURES,
  PERPS,
  CALL,
  PUT
}

// Permissions
uint64 constant PermDeposit = 1;
uint64 constant PermWithdrawal = 1 << 1;
uint64 constant PermTransfer = 1 << 2;
uint64 constant PermTrade = 1 << 3;
uint64 constant PermAddSigner = 1 << 4;
uint64 constant PermRemoveSigner = 1 << 5;
uint64 constant PermChangeMarginType = 1 << 6;

uint64 constant AdminPermissions = PermDeposit |
  PermWithdrawal |
  PermTransfer |
  PermTrade |
  PermAddSigner |
  PermRemoveSigner |
  PermChangeMarginType;

struct Signature {
  address signer;
  uint64 expiration;
  uint256 R;
  uint256 S;
}

struct State {
  // Accounts and Sessions
  mapping(uint32 => Account) accounts;
  mapping(uint32 => SubAccount) subAccounts;
  mapping(address => uint128) sessionKeys;
  // This tracks the number of contract that has been matched
  // Also used to prevent replay attack
  OrderState orders;
  // Oracle prices: Spot, Interest Rate, Volatility
  PriceState prices;
  // Configuration
  ConfigState config;
  // A Safety Module is created per quote + underlying currency pair
  mapping(uint8 => mapping(uint8 => SafetyModulePool)) safetyModule;
  // Transaction ID and time
  uint64 lastTransactionTime;
  uint64 lastTxID;
}

struct Account {
  uint32 id;
  // Number of account admin signers required to make any privileged changes on the account level. Defaults to 1
  // This affects the multi-sigs required to onboard new account admins, guardians, withdrawal, and transfer addresses
  uint8 multiSigThreshold;
  // All users who have Account Admin privileges. They automatically inherit all permissions on subaccount level
  address[] admins;
  // Guardians who are authorized to participate in key recovery quorum
  // Both retail and institutional accounts can rely on guardians for key recovery
  // Institutions have an additional option to rely on their sub account signers
  address[] guardians;
  // All subaccounts belonging to the account can only withdraw assets to these L1 Wallet addresses
  address[] onboardedWithdrawlAddresses;
  // All subaccounts belonging to the account can only transfer assets to these L2 Sub Accounts
  address[] onboardedTranferSubAccount;
  // A record of all SubAccounts owned by the account
  // Helps in sub account signer quorum computation during key recovery
  uint32[] subAccounts;
}

struct SubAccount {
  // The Account that this Sub Account belongs to
  uint32 accountID;
  // SIMPLE / PORTFOLIO / OPTIMAL
  uint8 marginType;
  // The Quote Currency that this Sub Account is denominated in
  Currency quoteCurrency;
  // The total amount of base currency that the sub account possesses
  // Expressed in base currency decimal units
  // TODO: Defined as int65 IExchange
  int64 balance;
  // SMO: CONSIDER NOT REFLECTING THIS IN LIQUIDATIONS, EXCHANGES TYPICALLY WAIT FOR SETTLEMENT TOO
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
  // Whether the sub account is being liquidated
  bool isUnderLiquidation;
}

struct Derivative {
  Instrument instrument;
  Currency underlying;
  Currency quote;
  uint8 decimals;
  uint32 expiration;
  uint64 strikePrice;
}

struct DerivativePosition {
  // The derivative contract held in this position
  Derivative derivative;
  // Number of contracts held in this position
  // TODO: Defined as int65 IExchange
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
  // Bitmask of permissions (Deposit, Withdraw, Transfer, Trade, Add Signer, Remove Signer, Change Margin Type)
  uint64 Permission;
}

struct OrderState {
  mapping(uint128 => bool) fullDerivativeOrderMatched;
  mapping(uint128 => uint64[]) partialDerivativeOrderMatched;
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

struct ConfigState {
  // eg. 5% = 500bps = 50000 CentiBeeps
  uint64 safetyModuleTargetInsuranceToDailyVolumeRatio;
  uint64 safetyModuleLiquidationFee;
  // This is the address of the gravity wallet that supports the recovery of the admin wallet
  address gravityAdminRecoveryWallet;
}

struct RiskConfig {
  // fxp 3.2
  uint32[] SpotMoves;
  // fxp 3.2
  uint32[] volMoves;
  // discount
  uint32 discount;
}

struct SessionKey {
  // If this is a session key, this is the main signing key that owns the session key
  // The smart contract will validate that the session key only has a subset of the main signing key's permissions
  // MainSigningKey ContractAddress

  // The session key that is tagged to the main signing key
  address sessionKey;
  // The last timestamp that the signer can sign at
  // We can apply a max one day expiry on session keys
  uint64 authorizationExpiry;
}

// See https://docs.google.com/document/d/1nXArbQMm-wbdRCoYR8FSPKCHZQxT8sAm8cjhq_16jSw/edit#heading=h.fqlr6k6zp9p2
// Liquidation Fee is hard coded by config at eg. 75bps
// The contribution of the liquidation fee towards the safety module follows the insurance fee curve
// Use a sigmoid curve like https://en.wikipedia.org/wiki/Generalised_logistic_function
struct SafetyModulePool {
  // Maps SubAccounts to their LP Tokens
  mapping(uint32 => uint64) lpTokens;
  // Depositors receive LP Tokens equivalent to (DepositSize * TotalLpTokens / TotalBalance)
  // Withdrawers receive Quote Currency equivalent to (LpTokensReturned * TotalBalance / TotalLpTokens)
  uint64 totalLpTokens;
  uint64 totalBalance;
}
