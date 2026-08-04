pragma solidity ^0.8.20;

import "./ConfigContract.sol";
import "./signature/generated/StakingSig.sol";
import "../interfaces/IStaking.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

abstract contract StakingContract is IStaking, ConfigContract {
  uint8 internal constant GRVT_CURRENCY_ID = 147;

  function stake(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint8 currency,
    uint64 numTokens,
    int64 newLockEndTime,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(_currencyIsRegistered(currency), "invalid currency");
    require(currency == GRVT_CURRENCY_ID, "stake currency must be GRVT");
    _setSequence(timestamp, txID);

    Account storage acc = _requireAccount(accountID);

    // ── Signature Verification ──
    bytes32 hash = hashStake(accountID, currency, numTokens, newLockEndTime, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    _requireAccountPermission(acc, sig.signer, AccountPermAdmin);

    // State-machine gating: stake is illegal during CoolingDown / Withdrawable.
    require(acc.stakeCooldownEndTime == 0, "stake disallowed during cooldown");

    int64 amount = SafeCast.toInt64(int(uint(numTokens)));
    require(amount > 0, "stake requires numTokens > 0");

    // Effective lock end follows the "max(current, new)" rule, with 0 = keep current.
    int64 effectiveLockEnd;
    if (acc.stakeLockedAmount == 0) {
      // Idle → Locked. Requires future lockEndTime.
      require(newLockEndTime > timestamp, "lock end must be in the future");
      effectiveLockEnd = newLockEndTime;
    } else {
      // Locked or Matured. Top-up and/or extend.
      if (newLockEndTime == 0) {
        // Keep current. Pure top-up
        effectiveLockEnd = acc.stakeLockEndTime;
      } else {
        require(newLockEndTime > timestamp, "lock end must be in the future");
        require(newLockEndTime >= acc.stakeLockEndTime, "lock end cannot shorten");
        effectiveLockEnd = newLockEndTime;
      }
    }
    acc.stakeLockEndTime = effectiveLockEnd;

    require(amount <= acc.fundingWalletBalances[currency], "insufficient GRVT");
    acc.fundingWalletBalances[currency] -= amount;
    acc.stakeLockedAmount += amount;

    emit Staked(accountID, numTokens, effectiveLockEnd, txID);
  }

  function initiateUnstake(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint8 currency,
    int64 cooldownEndTime,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(_currencyIsRegistered(currency), "invalid currency");
    require(currency == GRVT_CURRENCY_ID, "stake currency must be GRVT");
    _setSequence(timestamp, txID);

    Account storage acc = _requireAccount(accountID);

    bytes32 hash = hashInitiateUnstake(accountID, currency, cooldownEndTime, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    _requireAccountPermission(acc, sig.signer, AccountPermAdmin);

    // Source state must be Matured.
    require(acc.stakeLockedAmount > 0, "no stake to unstake");
    require(acc.stakeCooldownEndTime == 0, "cooldown already in progress");
    require(timestamp >= acc.stakeLockEndTime, "lock not yet matured");

    require(cooldownEndTime > timestamp, "cooldown end must be in the future");

    acc.stakeCooldownEndTime = cooldownEndTime;

    emit UnstakeInitiated(accountID, cooldownEndTime, txID);
  }

  function cancelUnstake(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint8 currency,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(_currencyIsRegistered(currency), "invalid currency");
    require(currency == GRVT_CURRENCY_ID, "stake currency must be GRVT");
    _setSequence(timestamp, txID);

    Account storage acc = _requireAccount(accountID);

    bytes32 hash = hashCancelUnstake(accountID, currency, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    _requireAccountPermission(acc, sig.signer, AccountPermAdmin);

    // Allowed from BOTH CoolingDown and Withdrawable.
    require(acc.stakeLockedAmount > 0, "no stake");
    require(acc.stakeCooldownEndTime != 0, "no active cooldown");

    acc.stakeCooldownEndTime = 0;

    emit UnstakeCancelled(accountID, txID);
  }

  function withdrawStake(
    int64 timestamp,
    uint64 txID,
    address accountID,
    uint8 currency,
    Signature calldata sig
  ) external onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) {
    require(_currencyIsRegistered(currency), "invalid currency");
    require(currency == GRVT_CURRENCY_ID, "stake currency must be GRVT");
    _setSequence(timestamp, txID);

    Account storage acc = _requireAccount(accountID);

    bytes32 hash = hashWithdrawStake(accountID, currency, sig.nonce, sig.expiration);
    _preventReplay(hash, sig);
    _requireAccountPermission(acc, sig.signer, AccountPermAdmin);

    // Source state must be Withdrawable.
    require(acc.stakeCooldownEndTime != 0, "no withdrawable stake");
    require(timestamp >= acc.stakeCooldownEndTime, "cooldown not elapsed");
    require(acc.stakeLockedAmount > 0, "no withdrawable stake");

    int64 amount = acc.stakeLockedAmount;
    acc.fundingWalletBalances[currency] += amount;
    acc.stakeLockedAmount = 0;
    acc.stakeLockEndTime = 0;
    acc.stakeCooldownEndTime = 0;

    emit StakeWithdrawn(accountID, SafeCast.toUint64(uint(int(amount))), txID);
  }

}
