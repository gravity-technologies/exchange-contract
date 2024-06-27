const codegen = require("./codegen.js")
const Types = require("../message/types.js")

let allBuf = ""
Object.values(Types).forEach((top) => {
  let primary = top.primaryType
  let typesBuf = ""
  let cur = ""
  const typs = Object.keys(top.types)

  const primaryLower = lower(primary.replace("Payload", "DataType"))
  typs.forEach((typ) => {
    if (typ === "EIP712Domain") {
      typesBuf += `\n    "EIP712Domain": EIP712Domain,`
      return
    }
    let typStr = ""
    const definitions = top.types[typ]
    for (let i = 0; i < definitions.length; ++i) {
      const def = definitions[i]
      typStr += `      {Name: "${def.name}", Type: "${def.type}"},\n`
    }

    typesBuf += `\n    "${typ}": []apitypes.Type{\n${typStr}    },`
  })
  cur = `
var ${primaryLower} = apitypes.TypedData{
  PrimaryType: "${primary}",
  Domain:      GRVTDomain,
  Types: apitypes.Types{${typesBuf}
  },
}
`
  allBuf += cur
})

console.log(allBuf)

function lower(s) {
  return s.charAt(0).toLowerCase() + s.slice(1)
}
