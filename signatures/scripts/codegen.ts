import { TypedDataUtils } from "signtypeddata-v5"
const { encodeType } = TypedDataUtils

function camelCase(str) {
  return str.toLowerCase().replace(/_(.)/g, function (match, group1) {
    return group1.toUpperCase()
  })
}

function screamingSnakeCase(camelCaseString) {
  return camelCaseString.replace(/([A-Z])/g, "_$1").toUpperCase()
}

const basicEncodableTypes = [
  "address",
  "bool",
  "int",
  "uint",
  "int8",
  "uint8",
  "int16",
  "uint16",
  "int32",
  "uint32",
  "int64",
  "uint64",
  "int128",
  "uint128",
  "int256",
  "uint256",
  "bytes32",
  "bytes16",
  "bytes8",
  "bytes4",
  "bytes2",
  "bytes1",
]

export interface MessageTypeProperty {
  name: string
  type: string
}

export interface MessageTypes {
  EIP712Domain: MessageTypeProperty[]
  [additionalProperties: string]: MessageTypeProperty[]
}

/**
 * This is the message format used for `signTypeData`, for all versions
 * except `V1`.
 *
 * @template T - The custom types used by this message.
 * @property types - The custom types used by this message.
 * @property primaryType - The type of the message.
 * @property domain - Signing domain metadata. The signing domain is the intended context for the
 * signature (e.g. the dapp, protocol, etc. that it's intended for). This data is used to
 * construct the domain seperator of the message.
 * @property domain.name - The name of the signing domain.
 * @property domain.version - The current major version of the signing domain.
 * @property domain.chainId - The chain ID of the signing domain.
 * @property domain.verifyingContract - The address of the contract that can verify the signature.
 * @property domain.salt - A disambiguating salt for the protocol.
 * @property message - The message to be signed.
 */
export interface TypedMessage<T extends MessageTypes> {
  types: T
  primaryType: keyof T
  domain: {
    name?: string
    version?: string
    chainId?: number
    verifyingContract?: string
    salt?: ArrayBuffer
  }
}

const generateFile = (primaryType: string, types, methods) => `
${types}
${methods}
`

type Result = {
  struct: string
  typeHash: string
}

type Field = {
  name: string
  type: string
}
export function generateCodeFrom(types, entryTypes: string[]) {
  let results: Result[] = []

  const packetHashGetters: Array<string> = []

  /**
   * We order the types so the signed types can be generated before any types that may need to depend on them.
   */
  const orderedTypes: {
    name: string
    fields: Field[]
  }[] = []

  Object.keys(types.types).forEach((typeName) => {
    orderedTypes.push({
      name: typeName,
      fields: types.types[typeName],
    })
  })

  orderedTypes.forEach((type) => {
    const typeName = type.name
    const fields = type.fields

    if (typeName === "EIP712Domain") {
      return
    }

    const typeHash = `bytes32 constant ${screamingSnakeCase(typeName + "H")} = keccak256("${encodeType(
      typeName,
      types.types
    )}");\n`
    const struct = `struct ${typeName} {\n${fields
      .map((field) => {
        return `  ${field.type} ${field.name};\n`
      })
      .join("")}}\n`

    generatePacketHashGetters(types, typeName, fields, packetHashGetters)
    results.push({ struct, typeHash })
  })

  return { setup: results, packetHashGetters: [...new Set(packetHashGetters)] }
}

function generatePacketHashGetters(types, typeName, fields, packetHashGetters: Array<string> = []) {
  fields.forEach((field) => {
    const arrayMatch = field.type.match(/(.+)\[\]/)
    if (arrayMatch) {
      const basicType = arrayMatch[1]
      if (types.types[basicType]) {
        packetHashGetters.push(`
function ${packetHashGetterName(field.type)} (${field.type} memory _input) pure returns (bytes32) {
  bytes memory encoded;
  for (uint i; i < _input.length; ++i) {
    encoded = abi.encodePacked(encoded, ${packetHashGetterName(basicType)}(_input[i]));
  }
  return keccak256(encoded);
}
`)
      } else {
        packetHashGetters.push(`
function ${packetHashGetterName(field.type)} (${field.type} memory _input) pure returns (bytes32) {
  return keccak256(abi.encodePacked(_input));
}
`)
      }
    } else {
      if (typeName === "EIP712Domain") {
        return
      }
      const funcName = packetHashGetterName(typeName)
      packetHashGetters.push(`
function ${funcName} (${typeName} memory _input) pure returns (bytes32) {
  bytes memory encoded = abi.encode(
    ${screamingSnakeCase(typeName + "TypeHash")},
    ${fields.map(getEncodedValueFor).join(",\n      ")}
  );
  return keccak256(encoded);
}
`)
    }
  })

  return packetHashGetters
}

function getEncodedValueFor(field: { name: string; type: string }) {
  const hashedTypes = ["bytes", "string"]
  if (basicEncodableTypes.includes(field.type)) {
    return `${field.name}`
  }

  if (hashedTypes.includes(field.type)) {
    if (field.type === "bytes") {
      return `keccak256(${field.name})`
    }
    if (field.type === "string") {
      return `keccak256(bytes(${field.name}))`
    }
  }

  return `${packetHashGetterName(field.type)}(_input.${field.name})`
}

function packetHashGetterName(typeName) {
  if (typeName === "EIP712Domain") {
    return camelCase("GET_EIP_712_DOMAIN_PACKET_HASH")
  }
  if (typeName.includes("[]")) {
    return `get${typeName.substr(0, typeName.length - 2)}ArrayPacketHash`
  }
  return `hash${typeName}`
}

/**
 * For encoding arrays of structs.
 * @param typeName
 * @param packetHashGetters
 */
function generateArrayPacketHashGetter(typeName, packetHashGetters) {
  packetHashGetters.push(`
  function ${packetHashGetterName(typeName)} (${typeName} memory _input) pure returns (bytes32) {
    bytes memory encoded;
    for (uint i; i < _input.length; ++i) {
      encoded = bytes.concat(
        encoded,
        ${packetHashGetterName(typeName.substr(0, typeName.length - 2))}(_input[i])
      );
    }
    bytes32 hash = keccak256(encoded);
    return hash;
  }`)
}

export function generateSolidity<T extends MessageTypes>(typeDef: TypedMessage<T>, entryTypes: string[]) {
  const { setup, packetHashGetters } = generateCodeFrom(typeDef, entryTypes)

  const types: string[] = []
  const methods: string[] = []

  setup.forEach((type) => {
    types.push(type.struct)
    types.push(type.typeHash)
  })

  packetHashGetters.forEach((getterLine) => {
    methods.push(getterLine)
  })

  // Generate entrypoint methods
  const newFileString = generateFile(String(typeDef.primaryType), types.join("\n"), methods.join("\n"))
  return newFileString
}
