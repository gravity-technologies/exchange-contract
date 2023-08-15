export interface MessageTypeProperty {
    name: string;
    type: string;
}
export interface MessageTypes {
    EIP712Domain: MessageTypeProperty[];
    [additionalProperties: string]: MessageTypeProperty[];
}
export interface TypedMessage<T extends MessageTypes> {
    types: T;
    primaryType: keyof T;
    domain: {
        name?: string;
        version?: string;
        chainId?: number;
        verifyingContract?: string;
        salt?: ArrayBuffer;
    };
}
type Result = {
    struct: string;
    typeHash: string;
};
export declare function generateCodeFrom(types: any, entryTypes: string[]): {
    setup: Result[];
    packetHashGetters: string[];
};
export declare function generateSolidity<T extends MessageTypes>(typeDef: TypedMessage<T>, entryTypes: string[]): string;
export {};
