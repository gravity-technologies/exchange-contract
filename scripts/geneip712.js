const codegen = require("./codegen.js")
const Types = require("../message/types.js")

const typs = [Types.ScheduleConfigPayload, Types.SetConfigPayload]
typs.forEach((typ) => {
  console.log(codegen.generateSolidity(typ, false, [typ.primaryType]))
})
