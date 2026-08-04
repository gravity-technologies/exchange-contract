pragma solidity ^0.8.20;

import "../types/Enum.sol";

// The single production account permitted to distribute the GRVT token airdrop through external
// main-account -> main-account transfers on the production chain (325).
address constant GRVT_AIRDROP_ACCOUNT = 0x36Fc723E6F3a8A9a916F8E9D08863365cD7c7e82;

/**
 * @notice Whether a main-to-main transfer is permitted purely because it is a GRVT token airdrop.
 *
 * Only the GRVT currency is ever whitelisted here. For non-production chains the airdrop may
 * originate from any account; for the production chain (325) it must come from the designated prod
 * airdrop account.
 *
 * @param currency  The currency being transferred.
 * @param fromAccID The source (main) account of the transfer.
 */
function isAirdropWhitelisted(uint8 currency, address fromAccID) view returns (bool) {
  return currency == CCY_GRVT && (block.chainid != 325 || fromAccID == GRVT_AIRDROP_ACCOUNT);
}
