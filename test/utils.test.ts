import { expect } from "chai"
import { generateDiamondCutDataFromDiff } from "../scripts/utils"

describe("generateDiamondCutDataFromDiff", function () {
    // Default test data based on the user's provided examples
    const defaultOnChainFacetInfo = [
        {
            address: '0x85ac3aDf8dfF8A4c964f70DF1a594767195eFeA9',
            selectors: ['0x1f931c1c'],
            bytecodeHash: '0x0100016f662ce9f7ee4e6051fb9095d84d86b0776c3235538edf8c6e7bf0d3d5'
        },
        {
            address: '0x0E4BF43Dd1F2bcc6c1153FF1e87d82C1e23E7c90',
            selectors: ['0x52ef6b2c', '0x7a0ed627', '0xadfca15e', '0xcdffacc6'],
            bytecodeHash: '0x010000cb31a043124d925f9d78b74baa7b23461fab5a7596fe0615ea33537c1a'
        },
        {
            address: '0x150D36bB644A0C1F922e8bf7e2d7A5d0971BFdd0',
            selectors: [
                '0x0ac28438', '0x0fc9f0cd', '0x116332ec',
                '0x188ec356', '0x21bb315a', '0x21bc043e',
                '0x23e7a641', '0x2c2b1c31', '0x41c639ae',
                '0x4419c99d', '0x53d1b5d2', '0x59acd516',
                '0x59c232e0', '0x65cd6aa9', '0x6d177b54',
                '0x710640b5', '0x7698aa33', '0x8179e95c',
                '0x83588780', '0x8ca75886', '0x8e4ba7cc',
                '0x8fbb2d13', '0x900470b6', '0x956adad7',
                '0xa7dc49fe', '0xb2f0d1b7', '0xc7706605',
                '0xcc68ef8a', '0xcc91498b', '0xd62e66f8',
                '0xd75dcea3', '0xdc8b18de', '0xdecf78ce',
                '0xe07cb08b', '0xefe0d798', '0xf1e291df',
                '0xf9750cb3'
            ],
            bytecodeHash: '0x01001863b223fdfeff7266c29b2c880c2060bf21e0f2f6ca3e545c5cd7ec49c5'
        },
        {
            address: '0xedCb3482fcB66b8d68c93A3174239D1d0C8a4902',
            selectors: [
                '0x276f2de0',
                '0x318ac2b6',
                '0x53b783e2',
                '0x5abe995f',
                '0xcdff6d2f',
                '0xe22e437c',
                '0xe79d0f57',
                '0xfcd9535d'
            ],
            bytecodeHash: '0x010032cba189efa3145aa4b6332062d8e546ed7a749a65599b6516fb2547d7e8'
        },
        {
            address: '0x8E3de3b7f3017D05Ebb72c054c7E96b1aD0A0018',
            selectors: ['0x6d9a8418', '0xe71d4797', '0xff6cae07'],
            bytecodeHash: '0x0100038b6ab19e69868b079823ae309537161cff6ed7e42d5aeada9150549716'
        }
    ]

    const defaultLocalFacetInfo = [
        {
            facet: 'DiamondCutFacet',
            selectors: ['0x1f931c1c'],
            bytecodeHash: '0x0100016f662ce9f7ee4e6051fb9095d84d86b0776c3235538edf8c6e7bf0d3d5'
        },
        {
            facet: 'DiamondLoupeFacet',
            selectors: ['0x52ef6b2c', '0x7a0ed627', '0xadfca15e', '0xcdffacc6'],
            bytecodeHash: '0x010000cb31a043124d925f9d78b74baa7b23461fab5a7596fe0615ea33537c1a'
        },
        {
            facet: 'GetterFacet',
            selectors: [
                '0x0ac28438', '0x0fc9f0cd', '0x116332ec',
                '0x188ec356', '0x21bb315a', '0x21bc043e',
                '0x23e7a641', '0x2c2b1c31', '0x41c639ae',
                '0x4419c99d', '0x53d1b5d2', '0x59acd516',
                '0x59c232e0', '0x65cd6aa9', '0x6d177b54',
                '0x710640b5', '0x7698aa33', '0x8179e95c',
                '0x83588780', '0x8ca75886', '0x8e4ba7cc',
                '0x8fbb2d13', '0x900470b6', '0x956adad7',
                '0xa7dc49fe', '0xb2f0d1b7', '0xc7706605',
                '0xcc68ef8a', '0xcc91498b', '0xd62e66f8',
                '0xd75dcea3', '0xdc8b18de', '0xdecf78ce',
                '0xe07cb08b', '0xefe0d798', '0xf1e291df',
                '0xf9750cb3'
            ],
            bytecodeHash: '0x01001863b223fdfeff7266c29b2c880c2060bf21e0f2f6ca3e545c5cd7ec49c5'
        },
        {
            facet: 'VaultFacet',
            selectors: [
                '0x276f2de0',
                '0x318ac2b6',
                '0x53b783e2',
                '0x5abe995f',
                '0xcdff6d2f',
                '0xe22e437c',
                '0xe79d0f57',
                '0xfcd9535d'
            ],
            bytecodeHash: '0x010032cba189efa3145aa4b6332062d8e546ed7a749a65599b6516fb2547d7e8'
        },
        {
            facet: 'WalletRecoveryFacet',
            selectors: ['0x6d9a8418', '0xe71d4797', '0xff6cae07'],
            bytecodeHash: '0x0100038b6ab19e69868b079823ae309537161cff6ed7e42d5aeada9150549716'
        }
    ]

    interface TestCase {
        name: string
        modifyOnChain: (data: typeof defaultOnChainFacetInfo) => typeof defaultOnChainFacetInfo
        modifyLocal: (data: typeof defaultLocalFacetInfo) => typeof defaultLocalFacetInfo
        expected: {
            add: Record<string, string[]>
            replace: Record<string, string[]>
            remove: string[]
            facetsToDeploy: string[]
        }
    }

    const testCases: TestCase[] = [
        {
            name: "no changes - identical on-chain and local facets",
            modifyOnChain: (data) => data,
            modifyLocal: (data) => data,
            expected: {
                add: {},
                replace: {},
                remove: [],
                facetsToDeploy: []
            }
        },
        {
            name: "add new facet - local has additional facet",
            modifyOnChain: (data) => data,
            modifyLocal: (data) => [
                ...data,
                {
                    facet: 'NewFacet',
                    selectors: ['0x12345678', '0x87654321'],
                    bytecodeHash: '0x0100000000000000000000000000000000000000000000000000000000000001'
                }
            ],
            expected: {
                add: {
                    'NewFacet': ['0x12345678', '0x87654321']
                },
                replace: {},
                remove: [],
                facetsToDeploy: ['NewFacet']
            }
        },
        {
            name: "remove facet - on-chain has facet that local doesn't",
            modifyOnChain: (data) => data,
            modifyLocal: (data) => data.filter(facet => facet.facet !== 'VaultFacet'),
            expected: {
                add: {},
                replace: {},
                remove: [
                    '0x276f2de0',
                    '0x318ac2b6',
                    '0x53b783e2',
                    '0x5abe995f',
                    '0xcdff6d2f',
                    '0xe22e437c',
                    '0xe79d0f57',
                    '0xfcd9535d'
                ],
                facetsToDeploy: []
            }
        },
        {
            name: "replace facet - same selectors but different bytecode hash",
            modifyOnChain: (data) => data,
            modifyLocal: (data) => data.map(facet =>
                facet.facet === 'VaultFacet'
                    ? { ...facet, bytecodeHash: '0x0100000000000000000000000000000000000000000000000000000000000002' }
                    : facet
            ),
            expected: {
                add: {},
                replace: {
                    'VaultFacet': [
                        '0x276f2de0',
                        '0x318ac2b6',
                        '0x53b783e2',
                        '0x5abe995f',
                        '0xcdff6d2f',
                        '0xe22e437c',
                        '0xe79d0f57',
                        '0xfcd9535d'
                    ]
                },
                remove: [],
                facetsToDeploy: ['VaultFacet']
            }
        },
        {
            name: "add selectors to existing facet - local facet has additional selectors",
            modifyOnChain: (data) => data,
            modifyLocal: (data) => data.map(facet =>
                facet.facet === 'VaultFacet'
                    ? {
                        ...facet,
                        selectors: [...facet.selectors, '0x11111111', '0x22222222'],
                        bytecodeHash: '0x0100000000000000000000000000000000000000000000000000000000000003'
                    }
                    : facet
            ),
            expected: {
                add: {
                    'VaultFacet': ['0x11111111', '0x22222222']
                },
                replace: {
                    'VaultFacet': [
                        '0x276f2de0',
                        '0x318ac2b6',
                        '0x53b783e2',
                        '0x5abe995f',
                        '0xcdff6d2f',
                        '0xe22e437c',
                        '0xe79d0f57',
                        '0xfcd9535d'
                    ]
                },
                remove: [],
                facetsToDeploy: ['VaultFacet']
            }
        },
        {
            name: "remove selectors from existing facet - local facet has fewer selectors",
            modifyOnChain: (data) => data,
            modifyLocal: (data) => data.map(facet =>
                facet.facet === 'VaultFacet'
                    ? {
                        ...facet,
                        selectors: facet.selectors.slice(0, 4), // Keep only first 4 selectors
                        bytecodeHash: '0x0100000000000000000000000000000000000000000000000000000000000004'
                    }
                    : facet
            ),
            expected: {
                add: {},
                replace: {
                    'VaultFacet': [
                        '0x276f2de0',
                        '0x318ac2b6',
                        '0x53b783e2',
                        '0x5abe995f'
                    ]
                },
                remove: [
                    '0xcdff6d2f',
                    '0xe22e437c',
                    '0xe79d0f57',
                    '0xfcd9535d'
                ],
                facetsToDeploy: ['VaultFacet']
            }
        },
        {
            name: "complex scenario - add new facet, remove old facet, and modify existing facet",
            modifyOnChain: (data) => data,
            modifyLocal: (data) => [
                ...data.filter(facet => facet.facet !== 'WalletRecoveryFacet' && facet.facet !== 'VaultFacet'), // Remove WalletRecoveryFacet
                {
                    facet: 'NewComplexFacet',
                    selectors: ['0xaaaaaaaa', '0xbbbbbbbb'],
                    bytecodeHash: '0x0100000000000000000000000000000000000000000000000000000000000005'
                },
                ...data.filter(facet => facet.facet === 'VaultFacet').map(facet => ({
                    ...facet,
                    selectors: [...facet.selectors, '0xcccccccc'],
                    bytecodeHash: '0x0100000000000000000000000000000000000000000000000000000000000006'
                }))
            ],
            expected: {
                add: {
                    'NewComplexFacet': ['0xaaaaaaaa', '0xbbbbbbbb'],
                    'VaultFacet': ['0xcccccccc']
                },
                replace: {
                    'VaultFacet': [
                        '0x276f2de0',
                        '0x318ac2b6',
                        '0x53b783e2',
                        '0x5abe995f',
                        '0xcdff6d2f',
                        '0xe22e437c',
                        '0xe79d0f57',
                        '0xfcd9535d'
                    ]
                },
                remove: ['0x6d9a8418', '0xe71d4797', '0xff6cae07'],
                facetsToDeploy: ['NewComplexFacet', 'VaultFacet']
            }
        },
        {
            name: "empty on-chain facets - all local facets are new",
            modifyOnChain: (_) => [],
            modifyLocal: (data) => data.slice(0, 2), // Only first 2 facets
            expected: {
                add: {
                    'DiamondCutFacet': ['0x1f931c1c'],
                    'DiamondLoupeFacet': ['0x52ef6b2c', '0x7a0ed627', '0xadfca15e', '0xcdffacc6']
                },
                replace: {},
                remove: [],
                facetsToDeploy: ['DiamondCutFacet', 'DiamondLoupeFacet']
            }
        },
        {
            name: "empty local facets - all on-chain facets should be removed",
            modifyOnChain: (data) => data.slice(0, 2), // Only first 2 facets
            modifyLocal: (data) => [],
            expected: {
                add: {},
                replace: {},
                remove: ['0x1f931c1c', '0x52ef6b2c', '0x7a0ed627', '0xadfca15e', '0xcdffacc6'],
                facetsToDeploy: []
            }
        }
    ]

    testCases.forEach((testCase) => {
        it(testCase.name, function () {
            const onChainFacetInfo = testCase.modifyOnChain([...defaultOnChainFacetInfo])
            const localFacetInfo = testCase.modifyLocal([...defaultLocalFacetInfo])

            const result = generateDiamondCutDataFromDiff(onChainFacetInfo, localFacetInfo)

            expect(result.add).to.deep.equal(testCase.expected.add)
            expect(result.replace).to.deep.equal(testCase.expected.replace)
            expect(result.remove).to.deep.equal(testCase.expected.remove)
            expect(result.facetsToDeploy).to.deep.equal(testCase.expected.facetsToDeploy)

            // Assert that all facets in add and replace are included in facetsToDeploy
            const facetsInAddAndReplace = new Set([
                ...Object.keys(result.add),
                ...Object.keys(result.replace)
            ])
            const facetsToDeploySet = new Set(result.facetsToDeploy)

            for (const facet of facetsInAddAndReplace) {
                expect(facetsToDeploySet.has(facet),
                    `Facet '${facet}' is in add/replace but not in facetsToDeploy`).to.be.true
            }
        })
    })
}) 