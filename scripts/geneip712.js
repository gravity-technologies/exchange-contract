const codegen = require("./codegen.js")
const Types = require("../message/types.js")

const typs = [Types.ScheduleConfig, Types.SetConfig]
typs.forEach((typ) => {
  console.log(codegen.generateSolidity(typ, false, [typ.primaryType]))
})
