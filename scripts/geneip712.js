const codegen = require("./codegen.js")
const Types = require("../message/types.js")

const typs = [Types.AddAccountGuardianPayload, Types.RemoveAccountGuardianPayload, Types.RecoverAccountAdminPayload]
typs.forEach((typ) => {
  console.log(codegen.generateSolidity(typ, false, [typ.primaryType]))
})
