const codegen = require("./codegen.js")
const Types = require("../message/types.js")

const typs = [Types.DepositPayload, Types.WithdrawalPayload, Types.TransferPayload]
typs.forEach((typ) => {
  console.log(codegen.generateSolidity(typ, false, [typ.primaryType]))
})
