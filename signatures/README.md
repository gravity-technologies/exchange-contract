## GRVT Signatures Utility

This utility is used to sign GRVT messages. There are 2 kinds of messages that can be signed:
1. Off-chain messages: Right now there's only 1 type which is the register wallet. The scheme used is ethereum personal sign.
2. Onchain messages: All message that need to be relayed on chain are signed using EIP712.

## How to use
1. Off-chain messages
- Use `signRegisterWalletMessage` 

2. Onchain messages
- Set the chainID in `schema.ts`
```
  export const domain = {
    name: "GRVT Exchange",
    version: "0",
    chainId: localEraNodeChainID, // replace this with the chainID of the network you want to use. For GRVT, testnet is 326, mainnet is 325. Local era node is 271
  }
```
- Use `GetXHash` function to get the hash of the message
- Use `Sign` function to sign the hash, given a private key