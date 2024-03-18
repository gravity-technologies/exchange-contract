// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./PositionMap.sol";
import "../util/BIMath.sol";

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
  PUT,
  SPOT,
  SETTLEMENT,
  RATE
}

enum Currency {
  UNSPECIFIED,
  USD,
  USDC,
  USDT,
  ETH,
  BTC
}

uint constant PRICE_DECIMALS = 9;
uint constant CENTIBEEP_DECIMALS = 6;
int constant TIME_FACTOR = 480;

uint64 constant AccountPermAdmin = 1 << 1;
uint64 constant AccountPermInternalTransfer = 1 << 2;
uint64 constant AccountPermExternalTransfer = 1 << 3;
uint64 constant AccountPermWithdraw = 1 << 4;

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

struct State {
  mapping(address => Account) accounts;
  mapping(uint64 => SubAccount) subAccounts;
  mapping(address => Session) sessions;
  ReplayState replay;
  PriceState prices;
  mapping(ConfigID => ConfigSetting) configSettings;
  mapping(ConfigID => ConfigValue) config1DValues;
  mapping(ConfigID => mapping(bytes32 => ConfigValue)) config2DValues;
  int64 timestamp;
  uint64 lastTxID;
  uint256[49] __gap;
}

struct Account {
  address id;
  uint64 multiSigThreshold;
  uint64 adminCount;
  mapping(Currency => int64) spotBalances;
  mapping(address => mapping(address => uint256)) recoveryAddresses;
  mapping(address => bool) onboardedWithdrawalAddresses;
  mapping(address => bool) onboardedTransferAccounts;
  uint64[] subAccounts;
  mapping(address => uint64) signers;
  uint256[49] __gap;
}

struct SubAccount {
  uint64 id;
  uint64 adminCount;
  uint64 signerCount;
  address accountID;
  MarginType marginType;
  Currency quoteCurrency;
  mapping(Currency => int64) spotBalances;
  PositionsMap options;
  PositionsMap futures;
  PositionsMap perps;
  mapping(bytes => uint256) positionIndex;
  mapping(address => uint64) signers;
  int64 lastAppliedFundingTimestamp;
  uint256[49] __gap;
}

struct ConfigSchedule {
  int64 lockEndTime;
  uint256[49] __gap;
}

struct ConfigTimelockRule {
  int64 lockDuration;
  uint64 deltaPositive;
  uint64 deltaNegative;
}

struct ReplayState {
  mapping(bytes32 => mapping(bytes32 => uint64)) sizeMatched;
  mapping(bytes32 => bool) executed;
  uint256[49] __gap;
}

struct PriceState {
  mapping(bytes32 => uint64) mark;
  mapping(bytes32 => int32) interest;
  mapping(bytes32 => int64) fundingIndex;
  int64 fundingTime;
  mapping(bytes32 => SettlementPriceEntry) settlement;
  uint256[49] __gap;
}

struct Session {
  address subAccountSigner;
  int64 expiry;
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
  UNSPECIFIED,
  // SIMPLE MARGIN CONFIGS
  SM_FUTURES_INITIAL_MARGIN,
  SM_FUTURES_MAINTENANCE_MARGIN,
  SM_FUTURES_VARIABLE_MARGIN,
  SM_OPTIONS_INITIAL_MARGIN_HIGH,
  SM_OPTIONS_INITIAL_MARGIN_LOW,
  SM_OPTIONS_MAINTENANCE_MARGIN,
  // PORTFOLIO MARGIN CONFIGS
  PM_SPOT_MOVE,
  PM_VOL_MOVE_UP,
  PM_VOL_MOVE_DOWN,
  PM_SPOT_MOVE_EXTREME,
  PM_EXTREME_MOVE_DISCOUNT,
  PM_SHORT_TERM_VEGA_POWER,
  PM_LONG_TERM_VEGA_POWER,
  PM_INITIAL_MARGIN_FACTOR,
  PM_FUTURES_CONTINGENCY_MARGIN,
  PM_OPTIONS_CONTINGENCY_MARGIN,
  // ADMIN
  ADMIN_RECOVERY_ADDRESS,
  ORACLE_ADDRESS,
  CONFIG_ADDRESS,
  ADMIN_FEE_SUB_ACCOUNT_ID, // the sub account that collects fees
  ADMIN_LIQUIDATION_SUB_ACCOUNT_ID,
  // Funding
  FUNDING_RATE_HIGH,
  FUNDING_RATE_LOW,
  MARKET_DATA_ADDRESS,
  FUTURE_MAKER_FEE_MINIMUM,
  FUTURE_TAKER_FEE_MINIMUM,
  OPTION_MAKER_FEE_MINIMUM,
  OPTION_TAKER_FEE_MINIMUM,
  DEPOSIT_ADDRESS,
  ERC20_USDT_ADDRESS
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

// --------------- Trade --------------
struct Trade {
  Order takerOrder;
  MakerTradeMatch[] makerOrders;
  int64[] feeCharged;
}

struct Order {
  uint64 subAccountID;
  bool isMarket;
  TimeInForce timeInForce;
  uint32 takerFeePercentageCap;
  uint32 makerFeePercentageCap;
  bool postOnly;
  bool reduceOnly;
  OrderLeg[] legs;
  Signature signature;
}

struct OrderLeg {
  bytes32 assetID;
  uint64 size;
  uint64 limitPrice;
  uint64 ocoLimitPrice;
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
