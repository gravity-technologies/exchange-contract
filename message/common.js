const { keccak256 } = require('ethers/lib/utils')

const EIP712Domain = [
  { name: 'name', type: 'string' },
  { name: 'version', type: 'string' },
  { name: 'chainId', type: 'uint256' },
  { name: 'verifyingContract', type: 'address' },
  { name: 'salt', type: 'bytes32' },
]

const domain = {
  name: 'GRVTEx',
  version: '0', // testnet
  chainId: 0,
  verifyingContract: 0,
  salt: keccak256(Buffer.from('GRVTExchange', 'utf-8')),
}

module.exports = {
  EIP712Domain,
  domain,
}
