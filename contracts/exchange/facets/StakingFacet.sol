pragma solidity ^0.8.20;

import "../api/StakingContract.sol";
import "../interfaces/IStaking.sol";

contract StakingFacet is IStaking, StakingContract {}
