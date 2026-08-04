pragma solidity ^0.8.20;

import "./ITransfer.sol";
import "./ITrade.sol";

interface ITransferAndTrade is ITransfer, ITrade {}
