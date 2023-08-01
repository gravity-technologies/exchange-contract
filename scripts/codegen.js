"use strict";
var __read = (this && this.__read) || function (o, n) {
    var m = typeof Symbol === "function" && o[Symbol.iterator];
    if (!m) return o;
    var i = m.call(o), r, ar = [], e;
    try {
        while ((n === void 0 || n-- > 0) && !(r = i.next()).done) ar.push(r.value);
    }
    catch (error) { e = { error: error }; }
    finally {
        try {
            if (r && !r.done && (m = i["return"])) m.call(i);
        }
        finally { if (e) throw e.error; }
    }
    return ar;
};
var __spreadArray = (this && this.__spreadArray) || function (to, from, pack) {
    if (pack || arguments.length === 2) for (var i = 0, l = from.length, ar; i < l; i++) {
        if (ar || !(i in from)) {
            if (!ar) ar = Array.prototype.slice.call(from, 0, i);
            ar[i] = from[i];
        }
    }
    return to.concat(ar || Array.prototype.slice.call(from));
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateSolidity = exports.generateCodeFrom = void 0;
var signtypeddata_v5_1 = require("signtypeddata-v5");
var encodeType = signtypeddata_v5_1.TypedDataUtils.encodeType;
function camelCase(str) {
    return str.toLowerCase().replace(/_(.)/g, function (match, group1) {
        return group1.toUpperCase();
    });
}
function screamingSnakeCase(camelCaseString) {
    return camelCaseString.replace(/([A-Z])/g, '_$1').toUpperCase();
}
var basicEncodableTypes = [
    'address',
    'bool',
    'int',
    'uint',
    'int8',
    'uint8',
    'int16',
    'uint16',
    'int32',
    'uint32',
    'int64',
    'uint64',
    'int128',
    'uint128',
    'int256',
    'uint256',
    'bytes32',
    'bytes16',
    'bytes8',
    'bytes4',
    'bytes2',
    'bytes1',
];
var generateFile = function (primaryType, types, methods) { return "\n".concat(types, "\n").concat(methods, "\n"); };
var LOGGING_ENABLED = false;
function generateCodeFrom(types, entryTypes) {
    var results = [];
    var packetHashGetters = [];
    /**
     * We order the types so the signed types can be generated before any types that may need to depend on them.
     */
    var orderedTypes = [];
    Object.keys(types.types).forEach(function (typeName) {
        orderedTypes.push({
            name: typeName,
            fields: types.types[typeName],
        });
    });
    orderedTypes.forEach(function (type) {
        var typeName = type.name;
        var fields = type.fields;
        if (typeName === 'EIP712Domain') {
            return;
        }
        var typeHash = "bytes32 constant ".concat(screamingSnakeCase(typeName + 'TypeHash'), " = keccak256(\"").concat(encodeType(typeName, types.types), "\");\n");
        var struct = "struct ".concat(typeName, " {\n").concat(fields
            .map(function (field) {
            return "  ".concat(field.type, " ").concat(field.name, ";\n");
        })
            .join(''), "}\n");
        generatePacketHashGetters(types, typeName, fields, packetHashGetters);
        results.push({ struct: struct, typeHash: typeHash });
    });
    return { setup: results, packetHashGetters: __spreadArray([], __read(new Set(packetHashGetters)), false) };
}
exports.generateCodeFrom = generateCodeFrom;
function generatePacketHashGetters(types, typeName, fields, packetHashGetters) {
    if (packetHashGetters === void 0) { packetHashGetters = []; }
    fields.forEach(function (field) {
        var arrayMatch = field.type.match(/(.+)\[\]/);
        if (arrayMatch) {
            var basicType = arrayMatch[1];
            if (types.types[basicType]) {
                packetHashGetters.push("\nfunction ".concat(packetHashGetterName(field.type), " (").concat(field.type, " memory _input) pure returns (bytes32) {\n  bytes memory encoded;\n  for (uint i = 0; i < _input.length; i++) {\n    encoded = abi.encodePacked(encoded, ").concat(packetHashGetterName(basicType), "(_input[i]));\n  }\n  return keccak256(encoded);\n}\n"));
            }
            else {
                packetHashGetters.push("\nfunction ".concat(packetHashGetterName(field.type), " (").concat(field.type, " memory _input) pure returns (bytes32) {\n  return keccak256(abi.encodePacked(_input));\n}\n"));
            }
        }
        else {
            if (typeName === 'EIP712Domain') {
                return;
            }
            var funcName = packetHashGetterName(typeName);
            packetHashGetters.push("\nfunction ".concat(funcName, " (").concat(typeName, " memory _input) pure returns (bytes32) {\n  bytes memory encoded = abi.encode(\n    ").concat(screamingSnakeCase(typeName + 'TypeHash'), ",\n    ").concat(fields.map(getEncodedValueFor).join(',\n      '), "\n  );\n  return keccak256(encoded);\n}\n"));
        }
    });
    return packetHashGetters;
}
function getEncodedValueFor(field) {
    var hashedTypes = ['bytes', 'string'];
    if (basicEncodableTypes.includes(field.type)) {
        return "".concat(field.name);
    }
    if (hashedTypes.includes(field.type)) {
        if (field.type === 'bytes') {
            return "keccak256(".concat(field.name, ")");
        }
        if (field.type === 'string') {
            return "keccak256(bytes(".concat(field.name, "))");
        }
    }
    return "".concat(packetHashGetterName(field.type), "(_input.").concat(field.name, ")");
}
function packetHashGetterName(typeName) {
    if (typeName === 'EIP712Domain') {
        return camelCase('GET_EIP_712_DOMAIN_PACKET_HASH');
    }
    if (typeName.includes('[]')) {
        return "get".concat(typeName.substr(0, typeName.length - 2), "ArrayPacketHash");
    }
    return "get".concat(typeName, "PacketHash");
}
/**
 * For encoding arrays of structs.
 * @param typeName
 * @param packetHashGetters
 */
function generateArrayPacketHashGetter(typeName, packetHashGetters) {
    packetHashGetters.push("\n  function ".concat(packetHashGetterName(typeName), " (").concat(typeName, " memory _input) pure returns (bytes32) {\n    bytes memory encoded;\n    for (uint i = 0; i < _input.length; i++) {\n      encoded = bytes.concat(\n        encoded,\n        ").concat(packetHashGetterName(typeName.substr(0, typeName.length - 2)), "(_input[i])\n      );\n    }\n    bytes32 hash = keccak256(encoded);\n    return hash;\n  }"));
}
function generateSolidity(typeDef, entryTypes) {
    var _a = generateCodeFrom(typeDef, entryTypes), setup = _a.setup, packetHashGetters = _a.packetHashGetters;
    var types = [];
    var methods = [];
    setup.forEach(function (type) {
        types.push(type.struct);
        types.push(type.typeHash);
    });
    packetHashGetters.forEach(function (getterLine) {
        methods.push(getterLine);
    });
    // Generate entrypoint methods
    var newFileString = generateFile(String(typeDef.primaryType), types.join('\n'), methods.join('\n'));
    return newFileString;
}
exports.generateSolidity = generateSolidity;
