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
  RATE // 7
}

enum Currency {
  UNSPECIFIED, // 0
  USD, // 1
  USDC, // 2
  USDT, // 3
  ETH, // 4
  BTC, // 5
  SOL, // 6
  ARB, // 7
  BNB, // 8
  ZK, // 9
  POL, // 10
  OP, // 11
  ATOM, // 12
  KPEPE, // 13
  TON, // 14
  XRP, // 15
  XLM, // 16
  WLD, // 17
  WIF, // 18
  VIRTUAL, // 19
  TRUMP, // 20
  SUI, // 21
  KSHIB, // 22
  POPCAT, // 23
  PENGU, // 24
  LINK, // 25
  KBONK, // 26
  JUP, // 27
  FARTCOIN, // 28
  ENA, // 29
  DOGE, // 30
  AIXBT, // 31
  AI_16_Z, // 32
  ADA, // 33
  AAVE, // 34
  BERA, // 35
  VINE, // 36
  PENDLE, // 37
  UXLINK, // 38
  KAITO, // 39
  IP, // 40
  HYPE, // 41
  LAUNCHCOIN, // 42
  MOODENG, // 43
  UNI, // 44
  SAHARA, // 45
  H, // 46
  PUMP, // 47
  AVAX, // 48
  CRV, // 49
  SEI, // 50
  LTC, // 51
  HBAR, // 52
  ONDO, // 53
  CFX, // 54
  PROVE, // 55
  MNT, // 56
  WLFI, // 57
  LINEA, // 58
  ASTER, // 59
  AVNT, // 60
  BARD, // 61
  DOT, // 62
  EIGEN, // 63
  LA, // 64
  NEAR, // 65
  W, // 66
  BCH, // 67
  XPL, // 68
  APEX, // 69
  ZEC, // 70
  BLESS, // 71
  COAI, // 72
  STRK, // 73
  SPX, // 74
  LDO, // 75
  APT, // 76
  MON, // 77
  FIL, // 78
  ICP, // 79
  GIGGLE, // 80
  RESOLV, //81
  ZEN, // 82
  PAXG, // 83
  TAO, // 84
  LIT, // 85
  XAG, // 86
  TRX, // 87
  XMR, // 88
  AXS, // 89
  KAIA, // 90
  RIVER, // 91
  MEGA, // 92
  CC, // 93
  XAU, // 94
  XPT, // 95
  XPD, // 96
  TSLA, // 97
  INTC, // 98
  HOOD, // 99
  AMZN, // 100
  COIN, // 101
  CRCL, // 102
  MSTR, // 103
  PLTR, // 104
  COPPER, // 105
  EWJ, // 106
  EWY, // 107
  PAYP, // 108
  GOOGL, // 109
  NVDA, // 110
  META, // 111
  BASED, // 112
  EDGE, // 113
  BZ, // 114
  CL, // 115
  NATGAS // 116
}
