const codegen = require('./codegen.js')
const Types = require('../message/types.js')

const typ = Types.RemoveTransferSubAccountPayload
const solidityFile = codegen.generateSolidity(typ, false, [typ.primaryType])
console.log(solidityFile)
