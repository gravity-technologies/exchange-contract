// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library DataStructure {
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

    struct Account {
        uint id;
        // Number of account admin signers required to make any privileged changes on the account level. Defaults to 1
        // This affects the multi-sigs required to onboard new account admins, guardians, withdrawal, and transfer addresses
        uint8 multiSigThreshold;
        // All users who have Account Admin privileges. They automatically inherit all permissions on subaccount level
        mapping(address => bool) admins;
        // Guardians who are authorized to participate in key recovery quorum
        // Both retail and institutional accounts can rely on guardians for key recovery
        // Institutions have an additional option to rely on their sub account signers
        mapping(address => bool) guardians;
        // All subaccounts belonging to the account can only withdraw assets to these L1 Wallet addresses
        mapping(address => bool) onboardedWithdrawlAddresses;
        // All subaccounts belonging to the account can only transfer assets to these L2 Sub Accounts
        mapping(address => bool) onboardedTranferSubAccount;
        // A record of all SubAccounts owned by the account
        // Helps in sub account signer quorum computation during key recovery
        mapping(uint32 => bool) subAccounts;
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
        uint64 PendingDeposits;
        // Mapping from the uint128 representation to derivate position
        mapping(uint128 => DerivativePosition) derivativePositions;
        // Signers who are authorized to trade on this sub account
        mapping(address => Signer) authorizedSigners;
        // The timestamp that the sub account was last funded at
        uint64 lastAppliedFundingTimestamp;
        // Whether the sub account is being liquidated
        bool IsUnderLiquidation;
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
        int64 contractBalance; // TODO: Defined as int65 IExchange
        uint64 averageEntryPrice;
        uint64 lastAppliedFundingIndex;
    }

    struct Signer {
        uint16 permissions;
        uint64 dailyTradeLimit;
        uint64 dailyTradeConsumption;
        uint32 lastTradedTimestamp;
        uint32 authorizationExpiry;
    }

    struct OrderState {
        mapping(uint128 => bool) fullDerivativeOrderMatched;
        mapping(uint128 => mapping(uint8 => uint64)) partialDerivativeOrderMatched;
    }

    struct PriceState {
        mapping(Currency => uint64) spotIndexPrices;
        // Mapping from the uint128 deriv representation to index prices
        mapping(uint128 => uint64) optionsIndexPrices;
        mapping(Currency => uint64) spotInterestRates;
        // Mapping from the uint128 deriv representation to ewma
        mapping(uint128 => DerivativeEwma) derivativeEwma;
        // Mapping from the uint128 deriv representation to funding vwap
        mapping(uint128 => FundingVwap) fundingVwap;
        // Mapping from the uint128 deriv representation to funding indices
        mapping(uint128 => uint64) fundingIndices;
        uint64 previousFundingTimestamp;
        // Mapping from the uint64 settledInstrument representation to settled prices
        mapping(uint64 => uint64) settledPrices;
    }

    struct DerivativeEwma {
        uint64 ewma1;
        uint64 ewma2;
        uint64 ewma3;
    }

    struct FundingVwap {
        uint128 cumulativeVolume;
        uint256 cumulativeNotional;
    }

    struct SettledInstrument {
        Currency underlying;
        uint32 expiration;
    }

    struct ConfigState {
        uint64 safetyModuleTargetInsuranceToDailyVolumeRatio;
        uint64 safetyModuleLiquidationFee;
        address gravityAdminRecoveryWallet;
    }

    struct SessionKey {
        address sessionKey;
        uint32 authorizationExpiry;
    }

    struct SafetyModulePool {
        mapping(address => uint64) lpTokens;
        uint64 totalLpTokens;
        uint64 totalBalance;
        uint128 thirtyDayAverageVolume;
        mapping(uint8 => uint128) thirtyDayVolumeArray;
        uint8 currentDayIndex;
    }
}
