const codegen = require('./codegen.js')
const Types = require('../message/types.js')

const typs = [Types.RemoveSubAccountSignerPayload]
typs.forEach((typ) => {
  console.log(codegen.generateSolidity(typ, false, [typ.primaryType]))
})
