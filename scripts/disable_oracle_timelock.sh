#!/bin/bash

FILE="contracts/exchange/api/ConfigContract.sol"

# Use BSD-compatible sed command
sed -i '' '/if (key == ConfigID\.ORACLE_ADDRESS)/,/}/c\
    if (key == ConfigID.ORACLE_ADDRESS) {\
      return 0;\
    }' "$FILE"

echo "Replacement completed successfully."