// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

interface IL2StandardToken is IERC20MetadataUpgradeable {
  event BridgeInitialize(address indexed l1Token, string name, string symbol, uint8 decimals);

  event BridgeMint(address indexed _account, uint256 _amount);

  event BridgeBurn(address indexed _account, uint256 _amount);

  function bridgeMint(address _account, uint256 _amount) external;

  function bridgeBurn(address _account, uint256 _amount) external;

  function l1Address() external view returns (address);

  function l2Bridge() external view returns (address);

  function fundExchangeAccount(address _from, uint256 _amount) external;
}
