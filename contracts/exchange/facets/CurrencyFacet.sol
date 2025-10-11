pragma solidity ^0.8.20;

import "../api/CurrencyContract.sol";
import "../interfaces/ICurrency.sol";

contract CurrencyFacet is ICurrency, CurrencyContract {}
