// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/Vm.sol";
import "../../../contracts/exchange/api/signature/generated/AccountSig.sol";
import "../../../contracts/exchange/api/AccountContract.sol";
import "../../../contracts/exchange/types/DataStructure.sol";
import "../Base.t.sol";

contract AccountContractTest is Base_Test {
  function testCreateAccount() public {
    uint256 expiryTimestamp = currentTimestamp + (3 days);
    int64 currentTimestapInt64 = int64(int256(currentTimestamp));
    int64 expiry = int64(int256(expiryTimestamp));
    uint32 sigNonce = random();
    address accountID = users.walletOne;
    bytes32 structHash = hashCreateAccount(accountID, sigNonce);
    Signature memory sig = getUserSig(
      users.walletOne,
      users.walletOnePrivateKey,
      DOMAIN_HASH,
      structHash,
      expiry,
      sigNonce
    );
    grvtExchange.createAccount(currentTimestapInt64, txNonce, accountID, sig);
    txNonce++;
  }
}
