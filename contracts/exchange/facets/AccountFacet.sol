pragma solidity ^0.8.20;

import "../api/AccountContract.sol";
import "../interfaces/IAccount.sol";

contract AccountFacet is IAccount, AccountContract {}
