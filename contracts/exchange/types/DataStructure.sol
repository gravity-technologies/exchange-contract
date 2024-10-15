pragma solidity ^0.8.20;

import "./PositionMap.sol";
import "../util/BIMath.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

enum MarginType {
  UNSPECIFIED,
  ISOLATED,
  SIMPLE_CROSS_MARGIN,
  PORTFOLIO_CROSS_MARGIN
}

enum TimeInForce {
  UNSPECIFIED,
  GOOD_TILL_TIME,
  ALL_OR_NONE,
  IMMEDIATE_OR_CANCEL,
  FILL_OR_KILL
}

enum Kind {
  UNSPECIFIED, // 0
  PERPS, // 1
  FUTURES, // 2
  CALL, // 3
  PUT, // 4
  SPOT, // 5
  SETTLEMENT, // 6
  RATE // 7
}

enum Currency {
  UNSPECIFIED, // 0
  USD, // 1
  USDC, // 2
  USDT, // 3
  ETH, // 4
  BTC // 5
}

function currencyStart() pure returns (Currency) {
  return Currency.USD;
}

function currencyNext(Currency iter) pure returns (Currency) {
  if (iter == type(Currency).max) {
    return Currency.UNSPECIFIED;
  }
  return Currency(uint(iter) + 1);
}

function currencyIsValid(Currency iter) pure returns (bool) {
  return iter > type(Currency).min && iter <= type(Currency).max;
}

uint constant PRICE_DECIMALS = 9;
uint constant PRICE_MULTIPLIER = 10 ** PRICE_DECIMALS;
uint constant CENTIBEEP_DECIMALS = 6;
uint constant BASIS_POINTS_DECIMALS = 4;
int constant TIME_FACTOR = 480;

uint64 constant AccountPermAdmin = 1 << 1;
uint64 constant AccountPermInternalTransfer = 1 << 2;
uint64 constant AccountPermExternalTransfer = 1 << 3;
uint64 constant AccountPermWithdraw = 1 << 4;

// SubAccountPermissions:
// Permission is represented as a uint64 value, where each bit represents a permission. The value defined below is a bit mask for each permission
// To check if user has a certain permission, just do a bitwise AND
// ie: permission & mask > 0
uint64 constant SubAccountPermAdmin = 1 << 1;
uint64 constant SubAccountPermTransfer = 1 << 2;
uint64 constant SubAccountPermTrade = 1 << 3;

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
  // Store the type, timelock rules and update schedules for each config
  mapping(ConfigID => ConfigSetting) configSettings;
  // Store the current value of all 1 dimensional config. 1D config is a simple key -> value mapping that doesn't
  // Eg: (AdminFeeSubAccountID) = 1357902468
  //     (AdminRecoveryAddress) = 0xc0ffee254729296a45a3885639AC7E10F9d54979
  mapping(ConfigID => ConfigValue) config1DValues;
  // Store the current value of all 2 dimensional config.
  // A 2D config needs to be referred by both (key, subKey)
  // This is mainly to support risk configs for different underlying currency
  // Eg: (PortfolioInitialMarginFactor, BTC) = 1.2
  //     (PortfolioInitialMarginFactor, DOGE) = 1.5
  mapping(ConfigID => mapping(bytes32 => ConfigValue)) config2DValues;
  // Latest Transaction time
  int64 timestamp;
  // Latest Transaction ID
  uint64 lastTxID;
  // Stores the maintenance margin tiers for simple cross margin on a per KUQ(kind, underlying, quote) basis
  mapping(bytes32 => ListMarginTiersBI) simpleCrossMaintenanceMarginTiers;
  // Stores the timelock end time for the simple cross margin tiers on a per KUQ(kind, underlying, quote) basis
  mapping(bytes32 => int64) simpleCrossMaintenanceMarginTimelockEndTime;
  // Temporary storage for trade validation. This should always be cleared after each trade
  mapping(bytes32 => TmpLegData) _tmpTakerLegs;
  // This is the address that is used to initialize the config. Provided in initialize()
  address initializeConfigSigner;
  // uint configVersion
  uint configVersion;
  // The beacon address for the deposit proxy
  UpgradeableBeacon depositProxyBeacon;
  // The bytecode hash of the deposit proxy
  bytes32 depositProxyProxyBytecodeHash;
  // Total spot balances for all accounts
  mapping(Currency => int64) totalSpotBalances;
  // Bridging partners
  address[] bridgingPartners;
  // This empty reserved space is put in place to allow future versions to add new
  // variables without shifting down storage in the inheritance chain.
  // See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
  uint256[49] __gap;
}

struct TmpLegData {
  bool isBuyingAsset;
  bool isSet;
  uint64 limitPrice;
}

struct Account {
  address id;
  // Number of account admin signers required to make any privileged changes on the account level. Defaults to 1
  // This affects the multi-sigs required to onboard new account admins, guardians, withdrawal, and transfer addresses
  // uint256 instead of uint8 to reduce gas cost
  // See :
  //   - https://docs.soliditylang.org/en/v0.8.17/internals/layout_in_storage.html#layout-of-state-variables-in-storage
  //   - https://ethereum.stackexchange.com/questions/3067/why-does-uint8-cost-more-gas-than-uint256
  uint64 multiSigThreshold;
  uint64 adminCount;
  mapping(Currency => int64) spotBalances;
  // All signers tagged to this account can nominate recovery addresses that can be used to replace the wallet that can be used to sign transactions
  mapping(address => address[]) recoveryAddresses;
  // All subaccounts belonging to the account can only withdraw assets to these L1 Wallet addresses
  mapping(address => bool) onboardedWithdrawalAddresses;
  // All subaccounts belonging to the account can only transfer assets to these L2 Accounts
  mapping(address => bool) onboardedTransferAccounts;
  // A record of all SubAccounts owned by the account
  // Helps in sub account signer quorum computation during key recovery
  uint64[] subAccounts;
  // All users who have Account Admin privileges. They automatically inherit all SubAccountPermissions on subaccount level
  mapping(address => uint64) signers;
  uint256[49] __gap;
}

struct SubAccount {
  // The unique id of this subaccount, id > 0
  uint64 id;
  uint64 adminCount;
  uint64 signerCount;
  // The Account that this Sub Account belongs to
  address accountID;
  MarginType marginType;
  // The Quote Currency that this Sub Account is denominated in
  Currency quoteCurrency;
  // The total amount of base currency that the sub account possesses
  mapping(Currency => int64) spotBalances;
  // Mapping from the uint256 representation to derivate position
  PositionsMap options;
  PositionsMap futures;
  PositionsMap perps;
  mapping(bytes => uint256) positionIndex;
  // Signers who are authorized to trade on this sub account
  mapping(address => uint64) signers;
  // The timestamp that the sub account was last funded at
  int64 lastAppliedFundingTimestamp;
  uint256[49] __gap;
}

// A ScheduleConfig() call will add a new timelock entry to the state (for the config identifier).
// Previous timelock entries will be overwritten.
//
// A SetConfig() call will remove the timelock entry from the state (for the config identifier).
struct ConfigSchedule {
  // The timestamp at which the config will be unlocked
  int64 lockEndTime;
  uint256[49] __gap;
}

struct ConfigTimelockRule {
  // Number of nanoseconds the config is locked for if the rule applies
  int64 lockDuration;
  // This only applies for Int Configs.
  // It expresses the maximum delta (in the positive direction) that the config value
  // can be changed by in order for this rule to apply
  uint64 deltaPositive;
  // This only applies for Int Configs.
  // It expresses the maximum delta (in the negative direction) that the config value
  // can be changed by in order for this rule to apply
  uint64 deltaNegative;
}

struct ReplayState {
  mapping(bytes32 => mapping(bytes32 => uint64)) sizeMatched;
  // This mapping is used to prevent replay attack. Check if a certain signature has been executed before
  mapping(bytes32 => bool) executed;
  uint256[49] __gap;
}

struct PriceState {
  // Asset price is int64 because we need
  // Map assetID to price. Price is int64 instead of uint64 because we need negative value to represent absence of price
  mapping(bytes32 => uint64) mark;
  mapping(bytes32 => int32) interest;
  // TODO: revise: No need to store oracle prices, they are lazily uploaded at point of liquidation

  // Prior to any trade, funding must be applied
  // We centrally upload funding rates. On smart contract side, we simply apply a tiny minmax clamp
  // So that users are only minimally impacted if GRVT exhibits bad integrity
  // USD is always expressed as a uint64 with 9 decimal points
  mapping(bytes32 => int64) fundingIndex;
  int64 fundingTime;
  // For each underlying/expiration pair, there will be one settled price
  // Prior to any trade, settlement must be applied
  // FIXME: review data type
  mapping(bytes32 => SettlementPriceEntry) settlement;
  uint256[49] __gap;
}

struct Session {
  // The address of the user that create this session
  address subAccountSigner;
  // The last timestamp in nanoseconds that the signer can sign at
  // We can apply a max one day expiry on session keys
  int64 expiry;
}

// --------------- Config --------------
struct InitializeConfigItem {
  ConfigID key;
  bytes32 subKey;
  bytes32 value;
}

enum ConfigType {
  UNSPECIFIED,
  BOOL,
  BOOL2D,
  ADDRESS,
  ADDRESS2D,
  INT,
  INT2D,
  UINT,
  UINT2D,
  CENTIBEEP,
  CENTIBEEP2D
}

enum ConfigID {
  UNSPECIFIED, // 0
  DEPRECATED_1, // 1
  ORACLE_ADDRESS, // 2, has timelock
  CONFIG_ADDRESS, // 3, no timelock to add or remove
  MARKET_DATA_ADDRESS, // 4, no timelock to add or remove
  // Admin Sub Accounts
  ADMIN_FEE_SUB_ACCOUNT_ID, // 5, no timelock
  INSURANCE_FUND_SUB_ACCOUNT_ID, // 6, no timelock
  // Funding Configs
  FUNDING_RATE_HIGH, // 7, has timelock
  FUNDING_RATE_LOW, // 8, has timelock
  // Trading Fee Configs
  FUTURES_MAKER_FEE_MINIMUM, // 9, has timelock
  FUTURES_TAKER_FEE_MINIMUM, // 10, has timelock
  OPTIONS_MAKER_FEE_MINIMUM, // 11, has timelock
  OPTIONS_TAKER_FEE_MINIMUM, // 12, has timelock
  // ERC20 addresses
  ERC20_ADDRESSES, // 13, no timelock to add, is immutable once set
  L2_SHARED_BRIDGE_ADDRESS, // 14, no timelock to add, is immutable once set
  // Simple cross futures initial margin. This config is not used in the contract (since initial margin is only computed offchain),
  // but it is important to keep it here to maintain the correct configID ordinals
  SIMPLE_CROSS_FUTURES_INITIAL_MARGIN, // 15, has timelock
  // Withdrawal Fee Configs
  WITHDRAWAL_FEE, // 16, has timelock
  // Bridging partner accounts can transfer from and withdraw to any address
  BRIDGING_PARTNER_ADDRESSES // 17, no timelock on add, has timelock on remove
}

struct ConfigValue {
  // true if the config is set, false otherwise
  bool isSet;
  // The value is stored as bytes32 to allow for different types of config
  bytes32 val;
}

struct ConfigSetting {
  // the type of the config. UNSPECIFIED if this config setting is not set
  ConfigType typ;
  // the timelock rules for this config
  ConfigTimelockRule[] rules;
  // the schedules where we can change this config.
  mapping(bytes32 => ConfigSchedule) schedules;
}

struct MarginTier {
  uint64 bracketStart;
  uint32 rate;
}

struct MarginTierBI {
  BI bracketStart;
  BI rate;
}

struct ListMarginTiersBI {
  bytes32 kud;
  MarginTierBI[] tiers;
}

// --------------- Trade --------------
struct Trade {
  Order takerOrder;
  MakerTradeMatch[] makerOrders;
  int64[] feeCharged;
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
  OrderLeg[] legs;
  Signature signature;
  // If the trade was a liquidation
  bool isLiquidation;
}

struct OrderLeg {
  bytes32 assetID;
  // The total number of derivative contracts to trade in this leg, expressed in derivative decimal units
  uint64 size;
  // ONLY APPLICABLE WHEN TimeInForce = GTT / IOC AND IsMarket = FALSE
  // The limit price of the order leg, expressed in USD Price.
  // This is the total amount of base currency to pay/receive for all legs.
  uint64 limitPrice;
  // Specifies if the order leg is a buy or sell
  bool isBuyingAsset;
}

struct MakerTradeMatch {
  Order makerOrder;
  uint64[] matchedSize;
  int64[] feeCharged;
}

struct PriceEntry {
  bytes32 assetID;
  int256 value;
}

struct SettlementPriceEntry {
  bool isSet;
  uint64 value;
}

struct SettlementTick {
  bytes32 assetID;
  int256 value;
  bool isFinal;
  Signature signature;
}
