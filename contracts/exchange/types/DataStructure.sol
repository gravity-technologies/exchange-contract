// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Derivative.sol";

enum MarginType {
  UNSPECIFIED,
  ISOLATED,
  SIMPLE_CROSS_MARGIN,
  PORTFOLIO_CROSS_MARGIN
}

enum AccountRecoveryType {
  UNSPECIFIED,
  GUARDIAN,
  SUB_ACCOUNT_SIGNERS
}

enum TimeInForce {
  UNSPECIFIED,
  GOOD_TILL_TIME,
  ALL_OR_NONE,
  IMMEDIATE_OR_CANCEL,
  FILL_OR_KILL
}

enum Kind {
  UNSPECIFIED,
  PERPS,
  FUTURES,
  CALL,
  PUT
}

enum Currency {
  UNSPECIFIED,
  USDC,
  USDT,
  ETH,
  BTC
}

uint64 constant AccountPermAdmin = 1;
uint64 constant AccountPermInternalTransfer = 1 << 1;
uint64 constant AccountPermExternalTransfer = 1 << 2;
uint64 constant AccountPermWithdraw = 1 << 3;

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
uint64 constant SubAccountPermUpdateSignerPermission = 1 << 7;
uint64 constant SubAccountPermChangeMarginType = 1 << 8;

struct Signature {
  // The address of the signer
  address signer;
  bytes32 r;
  bytes32 s;
  uint8 v;
  // Timestamp after which this signature expires. Use 0 for no expiration.
  int64 expiration;
  uint32 nonce;
}

// sub_signer -> session_signer
// sub_signer -> subaccount
// given a signer, need to find subaccount
struct State {
  // Accounts
  mapping(address => Account) accounts;
  mapping(uint64 => SubAccount) subAccounts;
  // Map from session key to user and expiry. Session keys are used to auto sign trade on behalf of the user
  mapping(address => Session) sessions;
  // This mapping is used to prevent replay attack. Check if a certain signature has been executed before
  // This tracks the number of contract that has been matched
  // Also used to prevent replay attack
  ReplayState replay;
  // Oracle prices: Spot, Interest Rate, Volatility
  PriceState prices;
  // Latest Transaction time
  int64 timestamp;
  // Latest Transaction ID
  uint64 lastTxID;
  // Config
  mapping(ConfigID => bytes32) configs;
  mapping(ConfigID => ScheduledConfigEntry) scheduledConfig;
  mapping(ConfigID => ConfigTimelockRule[]) configTimelocks;
}

struct Account {
  address id;
  // Number of account admin signers required to make any privileged changes on the account level. Defaults to 1
  // This affects the multi-sigs required to onboard new account admins, guardians, withdrawal, and transfer addresses
  // uint256 instead of uint8 to reduce gas cost
  // See :
  //   - https://docs.soliditylang.org/en/v0.8.17/internals/layout_in_storage.html#layout-of-state-variables-in-storage
  //   - https://ethereum.stackexchange.com/questions/3067/why-does-uint8-cost-more-gas-than-uint256
  uint multiSigThreshold;
  mapping(Currency => int128) spotBalances;
  // Guardians who are authorized to participate in key recovery quorum
  // Both retail and institutional accounts can rely on guardians for key recovery
  // Institutions have an additional option to rely on their sub account signers
  address[] guardians;
  // All subaccounts belonging to the account can only withdraw assets to these L1 Wallet addresses
  mapping(address => bool) onboardedWithdrawalAddresses;
  // All subaccounts belonging to the account can only transfer assets to these L2 Accounts
  mapping(address => bool) onboardedTransferAccounts;
  // A record of all SubAccounts owned by the account
  // Helps in sub account signer quorum computation during key recovery
  uint64[] subAccounts;
  // All users who have Account Admin privileges. They automatically inherit all SubAccountPermissions on subaccount level
  mapping(address => uint64) signers;
  uint256 adminCount;
  uint256 signerCount;
}

struct SubAccount {
  // The unique id of this subaccount, id > 0
  uint64 id;
  // The Account that this Sub Account belongs to
  address accountID;
  MarginType marginType;
  // The Quote Currency that this Sub Account is denominated in
  Currency quoteCurrency;
  // The total amount of base currency that the sub account possesses
  mapping(Currency => uint64) spotBalances;
  // Mapping from the uint256 representation to derivate position
  PositionsMap options;
  PositionsMap futures;
  PositionsMap perps;
  mapping(bytes => uint256) positionIndex;
  // Signers who are authorized to trade on this sub account
  mapping(address => uint64) signers;
  uint256 adminCount;
  uint256 signerCount;
  // The timestamp that the sub account was last funded at
  int64 lastAppliedFundingTimestamp;
}

// A ScheduleConfig() call will add a new timelock entry to the state (for the config identifier).
// Previous timelock entries will be overwritten.
//
// A SetConfig() call will remove the timelock entry from the state (for the config identifier).
struct ScheduledConfigEntry {
  // The timestamp at which the config will be unlocked
  int lockEndTime;
  // The value the config will be set to when it is unlocked
  bytes32 value;
}

struct ConfigTimelockRule {
  // Number of nanoseconds the config is locked for if the rule applies
  int64 lockDuration;
  // This only applies for Int Configs.
  // It expresses the maximum delta (in the positive direction) that the config value
  // can be changed by in order for this rule to apply
  uint256 deltaPositive;
  // This only applies for Int Configs.
  // It expresses the maximum delta (in the negative direction) that the config value
  // can be changed by in order for this rule to apply
  uint256 deltaNegative;
}

struct ReplayState {
  mapping(bytes32 => mapping(uint256 => uint64)) sizeMatched;
  // This mapping is used to prevent replay attack. Check if a certain signature has been executed before
  mapping(bytes32 => bool) executed;
}

struct PriceState {
  // Asset price is int64 because we need
  // Map assetID to price. Price is int64 instead of uint64 because we need negative value to represent absence of price
  mapping(uint256 => uint64) mark;
  mapping(uint256 => int64) interest;
  // TODO: revise: No need to store oracle prices, they are lazily uploaded at point of liquidation

  // Prior to any trade, funding must be applied
  // We centrally upload funding rates. On smart contract side, we simply apply a tiny minmax clamp
  // So that users are only minimally impacted if GRVT exhibits bad integrity
  // USD is always expressed as a uint64 with 10 decimal points
  // TODO: this uint128 represents the derivative
  mapping(uint256 => uint64) fundingIndex;
  uint64 fundingTime;
  // For each underlying/expiration pair, there will be one settled price
  // Prior to any trade, settlement must be applied
  // FIXME: review data type
  mapping(uint256 => uint64) settlement;
}

struct Session {
  // The address of the user that create this session
  address user;
  // The last timestamp that the signer can sign at
  // We can apply a max one day expiry on session keys
  int64 expiry;
}

// --------------- Config --------------
enum ConfigType {
  UNSPECIFIED,
  BOOL,
  ADDRESS,
  INT,
  UINT
}

// See https://docs.google.com/spreadsheets/d/1MEp2BMtBjkdfTn7WXc_egh5ucc1UK8v6ibNWUuzW6AI/edit#gid=0 for the most up to date list of configs
enum ConfigID {
  UNSPECIFIED,
  // SIMPLE MARGIN CONFIGS
  SM_FUTURES_INITIAL_MARGIN,
  SM_FUTURES_MAINTENANCE_MARGIN,
  SM_FUTURES_VARIABLE_MARGIN,
  SM_OPTIONS_INITIAL_MARGIN_HIGH,
  SM_OPTIONS_INITIAL_MARGIN_LOW,
  SM_OPTIONS_MAINTENANCE_MARGIN_HIGH,
  SM_OPTIONS_MAINTENANCE_MARGIN_LOW,
  SM_OPTIONS_VARIABLE_MARGIN,
  // PORTFOLIO MARGIN CONFIGS
  PM_SPOT_MOVE,
  PM_VOL_MOVE_UP,
  PM_VOL_MOVE_DOWN,
  PM_SPOT_MOVE_EXTREME,
  PM_EXTREME_MOVE_DISCOUNT,
  PM_SHORT_TERM_VEGA_POWER,
  PM_LONG_TERM_VEGA_POWER,
  PM_INITIAL_MARGIN_FACTOR,
  PM_NET_SHORT_OPTION_MINIMUM,
  // ADMIN
  ADMIN_RECOVERY_ADDRESS,
  FEE_SUB_ACCOUNT_ID // the sub account that collects fees
}

// --------------- Trade --------------
struct Trade {
  Order takerOrder;
  OrderMatch[] makerOrders;
  AssetTradeContext[] tradeContext;
}

struct AssetTradeContext {
  uint256 assetID;
  uint64 markPrice;
  uint64 underlyingPrice;
  int32 riskFreeRate;
}

struct Order {
  // The subaccount initiating the order
  uint64 subAccountID;
  /// @dev No logic in contract related to this field
  //If the order is a market order
  // Market Orders do not have a limit price, and are always executed according to the maker order price.
  // Market Orders must always be taker orders
  bool isMarket;
  /// @dev No logic in contract related to this field
  // Four supported types of orders: GTT, IOC, AON, FOK
  // PARTIAL EXECUTION = GTT / IOC - allows partial size execution on each leg
  // FULL EXECUTION = AON / FOK - only allows full size execution on all legs
  // TAKER ONLY = IOC / FOK - only allows taker orders
  // MAKER OR TAKER = GTT / AON - allows maker or taker orders
  // Exchange only supports (GTT, IOC, FOK)
  // RFQ Maker only supports (GTT, AON), RFQ Taker only supports (FOK)
  TimeInForce timeInForce;
  // ONLY APPLICABLE WHEN TimeInForce = AON / FOK AND IsMarket = FALSE
  // The limit price of the full order, expressed in USD Price.
  // This is the total amount of base currency to pay/receive for all legs.
  uint64 limitPrice;
  uint64 ocoLimitPrice;
  // The taker fee percentage cap signed by the order.
  // This is the maximum taker fee percentage the order sender is willing to pay for the order.
  uint32 takerFeePercentageCap;
  // Same as TakerFeePercentageCap, but for the maker fee. Negative for maker rebates
  uint32 makerFeePercentageCap;
  /// @dev No logic in contract related to this field
  // If True, Order must be a maker order. It has to fill the orderbook instead of match it.
  // If False, Order can be either a maker or taker order.
  //
  // |               | Must Fill All | Can Fill Partial
  // | Must Be Taker | FOK + False   | IOC + False
  // | Can Be Either | AON + False   | GTC + False
  // | Must Be Maker | AON + True    | GTC + True
  bool postOnly;
  /// @dev No logic in contract related to this field
  // If True, Order must reduce the position size, or be cancelled
  bool reduceOnly;
  /// @dev No logic in contract related to this field
  bool isPayingBaseCurrency;
  // The legs present in this order
  // The legs must be sorted by Derivative: Instrument/Underlying/BaseCurrency/Expiration/StrikePrice
  OrderLeg[] legs;
  uint32 nonce;
  Signature signature;
}

struct OrderLeg {
  uint256 assetID;
  // The total number of derivative contracts to trade in this leg, expressed in derivative decimal units
  uint64 size;
  // ONLY APPLICABLE WHEN TimeInForce = GTT / IOC AND IsMarket = FALSE
  // The limit price of the order leg, expressed in USD Price.
  // This is the total amount of base currency to pay/receive for all legs.
  uint64 limitPrice;
  // ONLY APPLICABLE WHEN TimeInForce = GTT / IOC AND IsMarket = FALSE AND IsOCO = TRUE
  // If a OCO order is specified, this must contain the other limit price
  // User must sign both limit prices, and activator is free to swap them depending on which trigger is activated
  // The smart contract will always validate both limit prices, by arranging them in ascending order
  uint64 ocoLimitPrice;
  // Specifies if the order leg is a buy or sell
  bool isBuyingAsset;
}

struct OrderMatch {
  Order makerOrder;
  uint64[] matchedSize;
  uint32 takerFeePercentageCharged;
  uint32 makerFeePercentageCharged;
}

struct Asset {
  Kind kind;
  Currency underlying;
  uint256 underlyingAssetID;
  Currency quote;
  uint256 quoteAssetID;
  uint32 expiration;
  uint64 strikePrice;
}