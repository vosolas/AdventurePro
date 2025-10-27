// ✅ Real FHE Spin Log - Kiểm tra kết quả spin thật
import { ethers } from "ethers";

// ✅ Real Contract ABI
const REAL_ABI = [
  "function spin() external",
  "function getUserSpins(address user) external view returns (bytes)",
  "function getUserRewards(address user) external view returns (bytes)",
  "function buyGmTokens(bytes calldata encryptedAmount, bytes calldata proof) external payable",
  "function buySpins(bytes calldata encryptedAmount, bytes calldata proof) external",
  "event SpinCompleted(address indexed user, string result)",
  "event GmTokensBought(address indexed user, uint256 amount)",
  "event SpinsBought(address indexed user, uint256 amount)",
];

// ✅ Real FHE Spin Log function
export const testSpinLog = async () => {
  console.log("🎯 === REAL FHE SPIN LOG ===");

  try {
    // ✅ Check if MetaMask is available
    if (!window.ethereum) {
      throw new Error("MetaMask not found");
    }

    // ✅ Connect to Sepolia
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const account = await signer.getAddress();

    console.log("🔗 Connected to:", account);

    // ✅ Contract address
    const contractAddress = process.env.REACT_APP_FHEVM_CONTRACT_ADDRESS;
    if (!contractAddress) {
      throw new Error("REACT_APP_FHEVM_CONTRACT_ADDRESS environment variable is required");
    }
    const contract = new ethers.Contract(contractAddress, REAL_ABI, signer);

    console.log("📋 Contract:", contractAddress);

    // ✅ Get initial state
    console.log("📊 === INITIAL STATE ===");
    const initialSpins = await contract.getUserSpins(account);
    const initialRewards = await contract.getUserRewards(account);

    console.log("🎰 Initial spins ciphertext:", initialSpins);
    console.log("💰 Initial rewards ciphertext:", initialRewards);

    // ✅ Spin
    console.log("🎯 === SPINNING ===");
    const tx = await contract.spin({
      gasLimit: 500000,
    });

    console.log("⏳ Spin transaction:", tx.hash);
    const receipt = await tx.wait();
    console.log("✅ Spin completed:", receipt.transactionHash);

    // ✅ Parse events
    console.log("📋 === EVENT PARSING ===");
    const spinEvent = receipt.logs.find((log: any) => {
      const topic0 = log.topics[0];
      return topic0 === ethers.id("SpinCompleted(address,string)");
    });

    if (spinEvent) {
      const decoded = contract.interface.parseLog(spinEvent);
      if (decoded) {
        console.log("🎯 Spin result:", decoded.args[1]);
      } else {
        console.log("❌ Failed to parse spin event");
      }
    } else {
      console.log("❌ No SpinCompleted event found");
    }

    // ✅ Get final state
    console.log("📊 === FINAL STATE ===");
    const finalSpins = await contract.getUserSpins(account);
    const finalRewards = await contract.getUserRewards(account);

    console.log("🎰 Final spins ciphertext:", finalSpins);
    console.log("💰 Final rewards ciphertext:", finalRewards);

    // ✅ Compare states
    console.log("🔄 === STATE COMPARISON ===");
    console.log("Spins changed:", initialSpins !== finalSpins);
    console.log("Rewards changed:", initialRewards !== finalRewards);

    console.log("✅ === REAL FHE SPIN LOG COMPLETED ===");
  } catch (error) {
    console.error("❌ Real FHE spin log failed:", error);
  }
};

// ✅ Export for use in App.tsx
export default testSpinLog;
