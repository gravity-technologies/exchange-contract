pragma solidity ^0.8.20;

import "../api/TransferContract.sol";
import "../interfaces/ITransferAndTrade.sol";

contract TransferFacet is ITransferAndTrade, TransferContract {}
