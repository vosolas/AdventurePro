// ✅ Test FHE ABI và Contract Interaction
import { ethers } from "ethers";

// ✅ Standard ABI from compiled contract
const LUCKY_SPIN_ABI = [
  {
    inputs: [],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "timestamp",
        type: "uint256",
      },
    ],
    name: "DailyGmCompleted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "GmTokensBought",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "string",
        name: "result",
        type: "string",
      },
    ],
    name: "SpinCompleted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "SpinPurchased",
    type: "event",
  },
  {
    inputs: [],
    name: "DAILY_GM_RESET_HOUR",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "GM_TOKEN_RATE",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "SECONDS_PER_DAY",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "SPIN_PRICE",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "externalEuint64",
        name: "encryptedAmount",
        type: "bytes32",
      },
      {
        internalType: "bytes",
        name: "proof",
        type: "bytes",
      },
    ],
    name: "buyGmTokens",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "externalEuint64",
        name: "encryptedAmount",
        type: "bytes32",
      },
      {
        internalType: "bytes",
        name: "proof",
        type: "bytes",
      },
    ],
    name: "buySpins",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "canGmToday",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "externalEuint64",
        name: "encryptedGmValue",
        type: "bytes32",
      },
      {
        internalType: "bytes",
        name: "proof",
        type: "bytes",
      },
    ],
    name: "dailyGm",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "emergencyWithdraw",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "getContractBalance",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "getLastGmTime",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "getTimeUntilNextGm",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "getUserRewards",
    outputs: [
      {
        internalType: "euint64",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "getUserSpins",
    outputs: [
      {
        internalType: "euint64",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "spin",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "userRewards",
    outputs: [
      {
        internalType: "euint64",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "userSpins",
    outputs: [
      {
        internalType: "euint64",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

// ✅ Test function
export const testFheAbi = async () => {
  try {
    console.log("🔍 Testing FHE ABI...");

    // ✅ Test ABI parsing
    const contractInterface = new ethers.Interface(LUCKY_SPIN_ABI);
    console.log("✅ ABI parsed successfully");

    // ✅ Test function signatures
    const functions = contractInterface.fragments.filter((f) => f.type === "function");
    console.log("📋 Functions found:", functions.length);

    // ✅ Test specific functions
    const buyGmTokensFragment = contractInterface.getFunction("buyGmTokens");
    if (buyGmTokensFragment) {
      console.log("✅ buyGmTokens function:", {
        name: buyGmTokensFragment.name,
        inputs: buyGmTokensFragment.inputs.map((i) => ({ name: i.name, type: i.type })),
        outputs: buyGmTokensFragment.outputs.map((o) => ({ name: o.name, type: o.type })),
      });
    }

    const dailyGmFragment = contractInterface.getFunction("dailyGm");
    if (dailyGmFragment) {
      console.log("✅ dailyGm function:", {
        name: dailyGmFragment.name,
        inputs: dailyGmFragment.inputs.map((i) => ({ name: i.name, type: i.type })),
        outputs: dailyGmFragment.outputs.map((o) => ({ name: o.name, type: o.type })),
      });
    }

    const getUserSpinsFragment = contractInterface.getFunction("getUserSpins");
    if (getUserSpinsFragment) {
      console.log("✅ getUserSpins function:", {
        name: getUserSpinsFragment.name,
        inputs: getUserSpinsFragment.inputs.map((i) => ({ name: i.name, type: i.type })),
        outputs: getUserSpinsFragment.outputs.map((o) => ({ name: o.name, type: o.type })),
      });
    }

    // ✅ Test events
    const events = contractInterface.fragments.filter((f) => f.type === "event");
    console.log("📋 Events found:", events.length);

    const spinCompletedEvent = contractInterface.getEvent("SpinCompleted");
    if (spinCompletedEvent) {
      console.log("✅ SpinCompleted event:", {
        name: spinCompletedEvent.name,
        inputs: spinCompletedEvent.inputs.map((i) => ({ name: i.name, type: i.type, indexed: i.indexed })),
      });
    }

    console.log("🎯 FHE ABI test completed successfully!");
    return true;
  } catch (error) {
    console.error("❌ FHE ABI test failed:", error);
    return false;
  }
};

// ✅ Export ABI for use in other files
export { LUCKY_SPIN_ABI };
