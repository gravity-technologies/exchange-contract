pragma solidity ^0.8.20;

import "../api/SubAccountContract.sol";
import "../interfaces/ISubAccount.sol";

contract SubAccountFacet is ISubAccount, SubAccountContract {}
