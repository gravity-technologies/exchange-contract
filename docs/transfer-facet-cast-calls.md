# Transfer Facet Cast Commands

These functions are exposed via the deployed `GRVTExchange` diamond address, not by calling the facet contract directly.

The requested state-changing functions use `cast send`. Each step below includes an inline verification command using `cast call`.

## Environment

Staging, USDT balance = 4998935089287340000, the after moving AMOUNT to L1, the contract is left with 1USDT
```bash
export RPC_URL="https://zkrpc.zkstg.gravitymarkets.io/"
export EXCHANGE_ADMIN_PRIVATE_KEY=""
export EXCHANGE_ADDRESS=""
export L1_DEFI_VAULT=""
export NATIVE_VAULT_GATEWAY=""
export L2_TOKEN=""
export AMOUNT=""
export LIQUIDITY_ORCHESTRATOR_ADDRESS=""
export LIQUIDITY_ORCHESTRATOR_PRIVATE_KEY=""
```



Testnet
```bash
export RPC_URL="https://rpc.zkdev.gravitymarkets.io"
export EXCHANGE_ADMIN_PRIVATE_KEY=""
export EXCHANGE_ADDRESS=""

export L1_DEFI_VAULT=""
export NATIVE_VAULT_GATEWAY=""
export L2_TOKEN=""
export AMOUNT="<token_amount_in_wei>"
export LIQUIDITY_ORCHESTRATOR_ADDRESS=""
export LIQUIDITY_ORCHESTRATOR_PRIVATE_KEY=""


Compute USDT L2 address
RAW=$(cast storage "$EXCHANGE_ADDRESS" 0xcd1e2c79ea0705d842a7b4b00e25dceb29703319274876a284ab1f3d449ef675 --rpc-url "$RPC_URL")
cast parse-bytes32-address "$RAW"
```
## 1. `setL1DefiVaultAddress(address)`

Admin only. Can only be called once.

```bash
cast send "$EXCHANGE_ADDRESS" \
  "setL1DefiVaultAddress(address)" \
  "$L1_DEFI_VAULT" \
  --rpc-url "$RPC_URL" \
  --private-key "$EXCHANGE_ADMIN_PRIVATE_KEY"
```

Verify:

```bash
cast call "$EXCHANGE_ADDRESS" \
  "getL1DefiVaultAddress()(address)" \
  --rpc-url "$RPC_URL"
```

## 2. `setNativeVaultGatewayAddress(address)`

Admin only. Can only be called once.

```bash
cast send "$EXCHANGE_ADDRESS" \
  "setNativeVaultGatewayAddress(address)" \
  "$NATIVE_VAULT_GATEWAY" \
  --rpc-url "$RPC_URL" \
  --private-key "$EXCHANGE_ADMIN_PRIVATE_KEY"
```

Verify:

```bash
cast call "$EXCHANGE_ADDRESS" \
  "getNativeVaultGatewayAddress()(address)" \
  --rpc-url "$RPC_URL"
```

## 3. Grant Liquidity Orchestrator role

```bash
cast send "$EXCHANGE_ADDRESS" \
  "grantRole(bytes32,address)" \
  "0x$(cast keccak 'LIQUIDITY_ORCHESTRATOR_ROLE' | sed 's/^0x//')" \
  "$LIQUIDITY_ORCHESTRATOR_ADDRESS" \
  --rpc-url "$RPC_URL" \
  --private-key "$EXCHANGE_ADMIN_PRIVATE_KEY"
```

Verify:

```bash
ROLE="0x$(cast keccak 'LIQUIDITY_ORCHESTRATOR_ROLE' | sed 's/^0x//')"
cast call "$EXCHANGE_ADDRESS" \
  "hasRole(bytes32,address)(bool)" \
  "$ROLE" \
  "$LIQUIDITY_ORCHESTRATOR_ADDRESS" \
  --rpc-url "$RPC_URL"
```

## 4. `bridgeToL1DefiVault(address,uint256)`

Liquidity orchestrator only.

```bash
cast send "$EXCHANGE_ADDRESS" \
  "bridgeToL1DefiVault(address,uint256)" \
  "$L2_TOKEN" \
  "$AMOUNT" \
  --rpc-url "$RPC_URL" \
  --private-key "$LIQUIDITY_ORCHESTRATOR_PRIVATE_KEY"
```

Verify:

```bash
cast call "$L2_TOKEN" \
  "balanceOf(address)(uint256)" \
  "$EXCHANGE_ADDRESS" \
  --rpc-url "$RPC_URL"
```

## 5. `processWithdrawalQueue()`

Liquidity orchestrator only.

```bash
cast send "$EXCHANGE_ADDRESS" \
  "processWithdrawalQueue()" \
  --rpc-url "$RPC_URL" \
  --private-key "$EXCHANGE_ADMIN_PRIVATE_KEY"
```

Verify:

```bash
cast call "$EXCHANGE_ADDRESS" \
  "getPendingWithdrawalQueueBounds()(uint64,uint64)" \
  --rpc-url "$RPC_URL"
```
