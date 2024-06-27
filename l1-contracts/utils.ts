import { ethers } from "ethers";
import { TransactionResponse, TransactionReceipt } from "@ethersproject/abstract-provider";

export async function generateSignature({ l1Sender, l2Receiver, l1Token, amount, deadline, wallet }: {
    l1Sender: string;
    l2Receiver: string;
    l1Token: string;
    amount: number;
    deadline: number;
    wallet: ethers.Signer;
}) {
    const domain = {
        name: "GRVT Exchange",
        version: "0",
        chainId: 1, // Change this based on your network
    };

    const types = {
        DepositApproval: [
            { name: "l1Sender", type: "address" },
            { name: "l2Receiver", type: "address" },
            { name: "l1Token", type: "address" },
            { name: "amount", type: "uint256" },
            { name: "deadline", type: "uint256" }
        ],
    };

    const value = {
        l1Sender,
        l2Receiver,
        l1Token,
        amount,
        deadline,
    };

    const signature = await wallet.signTypedData(domain, types, value);

    return ethers.Signature.from(signature);
}

export const txConfirmation = async (txPromise: Promise<TransactionResponse>): Promise<TransactionReceipt> => {
    const tx = await txPromise;
    return await tx.wait();
}