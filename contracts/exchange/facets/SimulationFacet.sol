// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../api/ConfigContract.sol";
import "../types/DataStructure.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/ISimulation.sol";

contract SimulationFacet is ISimulation, ConfigContract {
  error ErrSubmitterAheadOfChain();
  error ErrMalformedInputs();
  error ErrDivergentStateOrInsufficientTicks();

  // Mark-price tick detection (4-byte selector match)
  bytes4 private constant _MARK_PRICE_TICK_SELECTOR = IOracle.markPriceTick.selector;

  // Calldata layout constants
  uint256 private constant _SELECTOR_LENGTH = 4;
  uint256 private constant _WORD_SIZE = 32;
  uint256 private constant _TX_ID_OFFSET = 36; //_SELECTOR_LENGTH + _WORD_SIZE
  uint256 private constant _MIN_CALLDATA_LENGTH = _SELECTOR_LENGTH + 2 * _WORD_SIZE;

  // Array operation constants
  uint256 private constant _BASIC_STEPS_COUNT = 2; // [operation, assertion]

  /**
   * @notice Simulation facet for sequencing mixed transactions (mark-price ticks + other ops)
   *         with zero on-chain side effects when invoked via `eth_call`.
   *
   *         Goal: return the minimal ordered subset of items to submit so that each non-mark tx
   *         passes its assertion. Ticks are injected only when needed.
   *
   *         IMPORTANT: This is intended for `eth_call`. If executed as a state-changing transaction,
   *         the inner subcalls WILL modify storage.
   *
   * @param txs                 Mixed tx calldata (ticks + non-mark).
   *                            Convention: arg0=int64 timestamp, arg1=uint64 txID (strictly increasing), then type-specific args.
   * @param txAssertions        One-to-one assertion calldata; view and must REVERT on failure (no return required).
   * @param submitterLastTxID   The last observed contract lastTxID by the ChainSubmitter. It could lag behind the contract lastTxID.
   *                            Must be <= state.lastTxID or we revert.
   * @param relevantTicks       For each i, strictly-ascending indices into `txs` that point ONLY to tick-items.
   *                            For tick-items themselves, the row must be empty.
   *
   * @return sequencedTxIDs     Ordered txIDs to submit: list of transactions IDs to submit on-chain that is guaranteed to pass all assertions.
   *
   * @dev SIMULATION FLOW EXAMPLES:
   *
   * Example 1: Simple case where operation succeeds without ticks
   * Input:
   *   - state.lastTxID = 100, state.lastMarkPriceTickID = 50
   *   - txs = [trade(txID=101)]
   *   - relevantTicks = [[]]  // empty - no ticks needed
   * Flow:
   *   1. Attempt A: execute trade(101) + assertion → SUCCESS
   *   2. Output: [101]
   *
   * Example 2: Operation needs mark price ticks
   * Input:
   *   - state.lastTxID = 100, state.lastMarkPriceTickID = 50
   *   - txs = [tick(txID=60), tick(txID=70), trade(txID=101)]
   *   - relevantTicks = [[], [], [0, 1]]  // trade needs both ticks
   * Flow:
   *   1. Skip tick(60) and tick(70) - they're never emitted alone
   *   2. Process trade(101):
   *      a. Attempt A: execute trade(101) + assertion → FAIL
   *      b. Attempt B: execute [tick(60), assert(60), tick(70), assert(70), trade(101), assert(101)] → SUCCESS
   *   3. Output: [60, 70, 101] - ticks are emitted just-in-time before the trade
   *
   * Example 3: Multiple operations with tick reuse via frontier
   * Input:
   *   - state.lastTxID = 100, state.lastMarkPriceTickID = 50
   *   - txs = [tick(txID=60), trade1(txID=101), trade2(txID=102)]
   *   - relevantTicks = [[], [0], [0]]  // both trades need the same tick
   * Flow:
   *   1. Process trade1(101):
   *      a. Attempt A: FAIL
   *      b. Attempt B: execute [tick(60), assert(60), trade1(101), assert(101)] → SUCCESS
   *      c. Advance frontier: minUnappliedTickIdx = 1
   *   2. Process trade2(102):
   *      a. Attempt A: execute trade2(102) + assertion → SUCCESS (tick(60) already applied)
   *   3. Output: [60, 101, 102] - tick applied once, both trades succeed
   * This demonstrates tick reuse: once applied, subsequent operations benefit without reapplication.
   *
   * Example 4: Filtering already processed ticks by state.lastMarkPriceTickID
   * Input:
   *   - state.lastTxID = 100, state.lastMarkPriceTickID = 65
   *   - txs = [tick(txID=60), tick(txID=70), trade(txID=101)]
   *   - relevantTicks = [[], [], [0, 1]]
   * Flow:
   *   1. Process trade(101):
   *      a. Attempt A: FAIL
   *      b. Count new ticks: tick(60) txID=60 <= lastMarkPriceTickID=65 (skip), tick(70) txID=70 > 65 (keep)
   *      c. Execute [tick(70), assert(70), trade(101), assert(101)] → SUCCESS
   *   2. Output: [70, 101] - tick(60) is filtered out as already processed
   *
   * MARK PRICE TICK SELECTION LOGIC:
   * - Only ticks with txID > state.lastMarkPriceTickID are considered
   * - Ticks are applied just-in-time before operations that need them
   * - Each tick appears at most once per simulation call via frontier tracking
   * - Ticks are never emitted alone - only when required by subsequent operations
   */
  function simulate(
    uint64 submitterLastTxID,
    bytes[] calldata txs,
    bytes[] calldata txAssertions,
    uint256[][] calldata relevantTicks
  ) external override onlyTxOriginRole(CHAIN_SUBMITTER_ROLE) returns (uint64[] memory sequencedTxIDs) {
    // Shape checks
    uint256 n = txs.length;
    if (n == 0 || n != txAssertions.length || n != relevantTicks.length) revert ErrMalformedInputs();

    // Chain precondition
    uint64 chainLast = state.lastTxID;
    if (submitterLastTxID > chainLast) revert ErrSubmitterAheadOfChain();

    // Decode txIDs
    uint64[] memory ids = new uint64[](n);

    for (uint256 i = 0; i < n; i++) {
      bytes calldata txCD = txs[i];
      if (txCD.length < _SELECTOR_LENGTH || txAssertions[i].length < _SELECTOR_LENGTH) revert ErrMalformedInputs();
      ids[i] = _readTxID(txCD);
    }

    // Pre-count future items to bound output size (each future item appears at most once)
    uint256 futureCount = 0;
    for (uint256 i = 0; i < n; i++) {
      if (ids[i] > chainLast) futureCount++;
    }

    uint64 lastMarkPriceTickID = state.lastMarkPriceTickID;
    sequencedTxIDs = new uint64[](futureCount);
    uint256 seqCount = 0;

    // Track the minimum index of ticks that haven't been applied yet.
    // Starts at 0 (all ticks available). After applying tick at index j, advances to j+1.
    uint256 minUnappliedTickIdx = 0;

    // Iterate future items (ids > chainLast) in ascending id; emit only for non-mark ops
    for (uint256 i = 0; i < n; i++) {
      if (ids[i] <= chainLast) continue; // Skip past transactions (already processed on-chain)
      if (_isMarkPriceTick(txs[i])) continue; // ticks are never emitted alone

      // Attempt A: op + assert atomically
      if (_attemptDirectExecution(txs[i], txAssertions[i])) {
        sequencedTxIDs[seqCount++] = ids[i];
        continue;
      }

      // Attempt B: apply required ticks filtered by frontier, then operation and assertion
      uint256[] calldata tickIndices = relevantTicks[i];

      (
        bool success,
        uint256 newMinUnappliedTickIdx,
        uint256[] memory appliedTickIndices,
        uint256 appliedCount
      ) = _attemptWithTicks(i, txs, txAssertions, ids, tickIndices, minUnappliedTickIdx, lastMarkPriceTickID);

      if (!success) {
        // If direct execution failed and no new ticks are available, the inputs are stale or insufficient
        revert ErrDivergentStateOrInsufficientTicks();
      }

      // Success: emit the tick IDs we actually applied then the op ID
      for (uint256 k = 0; k < appliedCount; k++) {
        sequencedTxIDs[seqCount++] = ids[appliedTickIndices[k]];
      }
      sequencedTxIDs[seqCount++] = ids[i];

      // Advance frontier
      minUnappliedTickIdx = newMinUnappliedTickIdx;
    }

    // Shrink output to actual length
    // We allocated sequencedTxIDs with futureCount size, but may have used fewer slots
    assembly {
      // Update the length field of the dynamic array:
      // - sequencedTxIDs points to the start of the array in memory
      // - The first 32 bytes store the array length
      // - mstore(sequencedTxIDs, seqCount) overwrites the length with actual items added
      mstore(sequencedTxIDs, seqCount)
    }
    return sequencedTxIDs;
  }

  modifier onlyThis() {
    require(msg.sender == address(this), "onlyThis");
    _;
  }

  /**
   * @notice Execute a sequence of steps atomically within a single inner attempt.
   *         Steps MUST be even-length: [op, assert, op, assert, ...].
   *         Even indices:  state-changing ops via .call(...)
   *         Odd indices:   assertions via .staticcall(...) that REVERT on failure
   */
  function atomicRun(bytes[] calldata steps) external onlyThis {
    uint256 nsteps = steps.length;
    if (nsteps == 0 || (nsteps & 1) != 0) revert ErrMalformedInputs();

    for (uint256 i = 0; i < nsteps; i++) {
      bool ok;
      bytes memory ret;
      if ((i & 1) == 0) {
        (ok, ret) = address(this).call(steps[i]);
      } else {
        (ok, ret) = address(this).staticcall(steps[i]);
      }
      if (!ok) {
        assembly {
          revert(add(ret, _WORD_SIZE), mload(ret))
        }
      }
    }
  }

  /// @dev Check if the given calldata represents a mark price tick transaction.
  function _isMarkPriceTick(bytes calldata c) private pure returns (bool) {
    if (c.length < _SELECTOR_LENGTH) return false;
    bytes4 selector;
    assembly {
      selector := shr(224, calldataload(c.offset))
    }
    return selector == _MARK_PRICE_TICK_SELECTOR;
  }

  /// @dev Decode the 2nd ABI-encoded arg (uint64 txID) from a calldata blob.
  ///      Layout: [4B selector][32B arg0 (int64 timestamp)][32B arg1 (uint64 txID)]...
  function _readTxID(bytes calldata c) private pure returns (uint64 id) {
    if (c.length < _MIN_CALLDATA_LENGTH) revert ErrMalformedInputs();
    uint256 word;
    assembly {
      word := calldataload(add(c.offset, _TX_ID_OFFSET))
    }
    id = uint64(word); // ABI encodes uint64 as right-aligned in 32 bytes, extract the lowest 8 bytes
  }

  /// @dev Check if a tick should be applied based on frontier and chain state
  function _shouldApplyTick(
    uint256 tickIndex,
    uint256 minUnappliedTickIdx,
    uint64 tickTxID,
    uint64 lastMarkPriceTickID
  ) private pure returns (bool) {
    return tickIndex >= minUnappliedTickIdx && tickTxID > lastMarkPriceTickID;
  }

  /// @dev Attempt to execute operation directly without any ticks (Attempt A)
  function _attemptDirectExecution(bytes calldata txData, bytes calldata txAssertion) private returns (bool success) {
    bytes[] memory steps = new bytes[](_BASIC_STEPS_COUNT);
    steps[0] = txData;
    steps[1] = txAssertion;

    (success, ) = address(this).call(abi.encodeWithSelector(this.atomicRun.selector, steps));
  }

  /// @dev Attempt to execute operation with required ticks (Attempt B)
  function _attemptWithTicks(
    uint256 opIndex,
    bytes[] calldata txs,
    bytes[] calldata txAssertions,
    uint64[] memory ids,
    uint256[] calldata tickIndices,
    uint256 minUnappliedTickIdx,
    uint64 lastMarkPriceTickID
  )
    private
    returns (bool success, uint256 newMinUnappliedTickIdx, uint256[] memory appliedTickIndices, uint256 appliedCount)
  {
    // Count how many new ticks need to be applied
    uint256 keepCount = 0;
    for (uint256 k = 0; k < tickIndices.length; k++) {
      uint256 j = tickIndices[k];
      if (_shouldApplyTick(j, minUnappliedTickIdx, ids[j], lastMarkPriceTickID)) {
        keepCount++;
      }
    }

    // If no new future ticks to apply, return failure
    if (keepCount == 0) {
      return (false, minUnappliedTickIdx, appliedTickIndices, 0);
    }

    // Build atomic sequence: [tick1, assert1, ..., op, assertOp]
    bytes[] memory steps = new bytes[](_BASIC_STEPS_COUNT * keepCount + _BASIC_STEPS_COUNT);
    appliedTickIndices = new uint256[](keepCount);
    uint256 stepIndex = 0;
    uint256 appliedIndex = 0;
    uint256 lastAppliedTickIndex = minUnappliedTickIdx == 0 ? 0 : (minUnappliedTickIdx - 1);

    for (uint256 k = 0; k < tickIndices.length; k++) {
      uint256 j = tickIndices[k];
      if (_shouldApplyTick(j, minUnappliedTickIdx, ids[j], lastMarkPriceTickID)) {
        steps[stepIndex++] = txs[j];
        steps[stepIndex++] = txAssertions[j];
        appliedTickIndices[appliedIndex++] = j;
        lastAppliedTickIndex = j;
      }
    }

    steps[stepIndex++] = txs[opIndex];
    steps[stepIndex++] = txAssertions[opIndex];

    // Execute atomic sequence
    bytes memory retData;
    (success, retData) = address(this).call(abi.encodeWithSelector(this.atomicRun.selector, steps));

    if (!success) {
      // Bubble up the revert reason from the inner call if available
      assembly {
        // Check if retData has content (length > 0)
        // mload(retData) reads the first 32 bytes which contains the length
        if gt(mload(retData), 0) {
          // Revert with the error data:
          // - add(retData, 0x20): skip the 32-byte length prefix to get actual data
          // - mload(retData): the length of the data to return
          revert(add(retData, 0x20), mload(retData))
        }
      }
    }

    return (success, lastAppliedTickIndex + 1, appliedTickIndices, keepCount);
  }
}
