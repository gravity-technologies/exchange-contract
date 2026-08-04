pragma solidity ^0.8.20;

enum MarginType {
  UNSPECIFIED,
  ISOLATED,
  SIMPLE_CROSS_MARGIN,
  PORTFOLIO_CROSS_MARGIN
}

enum PositionMarginType {
  UNSPECIFIED, // For UNSPECIFIED value, consider it the same as CROSS for backward compatibility (this enum is introduced after isolated margin)
  ISOLATED, // Isolated Margin Mode: each position is allocated a fixed amount of collateral
  CROSS // Cross Margin Mode: uses all available funds in your account as collateral across all cross margin positions
}

enum SubAccountMode {
  UNSPECIFIED,
  SINGLE_ASSET_MODE,
  MULTI_ASSET_MODE,
  UNIFIED_MODE
}

enum WalletType {
  UNSPECIFIED, // 0 - resolve to default based on subID
  FUNDING, // 1 - main account only (subID == 0)
  SPOT, // 2 - sub-account only (subID > 0)
  FUTURES // 3 - sub-account only (subID > 0)
}

enum TimeInForce {
  UNSPECIFIED,
  GOOD_TILL_TIME,
  ALL_OR_NONE,
  IMMEDIATE_OR_CANCEL,
  FILL_OR_KILL,
  RETAIL_PRICE_IMPROVEMENT
}

enum Kind {
  UNSPECIFIED, // 0
  PERPS, // 1
  FUTURES, // 2
  CALL, // 3
  PUT, // 4
  SPOT, // 5
  SETTLEMENT, // 6
  RATE, // 7
  SPOT_SWAP // 8
}

// On-chain currency identifier.
//
// Currency IDs are plain `uint8`. The runtime registry (`state.currencyConfigs`) is the
// single source of truth for which IDs are valid. To onboard a new currency, call
// `addCurrency(...)` — there is no enum to extend. The named constants below exist only
// because the contract logic special-cases these specific currencies by name; every other
// currency is referenced by raw numeric ID via the runtime registry.
//
// The asset packing scheme in `util/Asset.sol` also encodes underlying/quote as 8 bits, so
// the uint8 width here is intentional. The 256-ID ceiling is documented as future work.

uint8 constant CCY_UNSPECIFIED = 0;
uint8 constant CCY_USD = 1;
uint8 constant CCY_USDC = 2;
uint8 constant CCY_USDT = 3;
uint8 constant CCY_ETH = 4;
uint8 constant CCY_GRVT = 147;
