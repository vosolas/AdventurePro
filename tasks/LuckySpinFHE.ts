import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("lucky-spin:deploy", "Deploy LuckySpinFHE contract")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    
    console.log("Deploying LuckySpinFHE contract...");
    const LuckySpinFHE = await ethers.getContractFactory("LuckySpinFHE");
    const luckySpinFHE = await LuckySpinFHE.deploy();
    await luckySpinFHE.waitForDeployment();
    
    const address = await luckySpinFHE.getAddress();
    console.log("LuckySpinFHE deployed to:", address);
    
    return address;
  });

task("lucky-spin:add-pool", "Add a new pool reward")
  .addParam("contract", "Contract address")
  .addParam("name", "Pool name")
  .addParam("image", "Image URL")
  .addParam("value", "Reward value")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    
    const LuckySpinFHE = await ethers.getContractFactory("LuckySpinFHE");
    const luckySpinFHE = LuckySpinFHE.attach(taskArgs.contract);
    
    console.log(`Adding pool: ${taskArgs.name}`);
    await luckySpinFHE.addPool(taskArgs.name, taskArgs.image, taskArgs.value);
    
    const poolCount = await luckySpinFHE.poolCount();
    console.log(`Pool added! Total pools: ${poolCount}`);
  });

task("lucky-spin:get-pools", "Get all pool rewards")
  .addParam("contract", "Contract address")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    
    const LuckySpinFHE = await ethers.getContractFactory("LuckySpinFHE");
    const luckySpinFHE = LuckySpinFHE.attach(taskArgs.contract);
    
    const poolCount = await luckySpinFHE.poolCount();
    console.log(`Total pools: ${poolCount}`);
    
    for (let i = 0; i < poolCount; i++) {
      const [name, imageUrl, value] = await luckySpinFHE.getPoolReward(i);
      console.log(`Pool ${i}: ${name} - ${imageUrl} - Value: ${value}`);
    }
  });

task("lucky-spin:submit-score", "Submit a public score to leaderboard")
  .addParam("contract", "Contract address")
  .addParam("user", "User address")
  .addParam("score", "Score value")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    
    const LuckySpinFHE = await ethers.getContractFactory("LuckySpinFHE");
    const luckySpinFHE = LuckySpinFHE.attach(taskArgs.contract);
    
    console.log(`Submitting score for ${taskArgs.user}: ${taskArgs.score}`);
    await luckySpinFHE.submitPublicScore(taskArgs.user, taskArgs.score);
    
    console.log("Score submitted successfully!");
  });

task("lucky-spin:get-leaderboard", "Get leaderboard")
  .addParam("contract", "Contract address")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    
    const LuckySpinFHE = await ethers.getContractFactory("LuckySpinFHE");
    const luckySpinFHE = LuckySpinFHE.attach(taskArgs.contract);
    
    const leaderboard = await luckySpinFHE.getLeaderboard();
    console.log(`Leaderboard (${leaderboard.length} entries):`);
    
    leaderboard.forEach((entry: any, index: number) => {
      console.log(`${index + 1}. ${entry.user} - Score: ${entry.score}`);
    });
  });

task("lucky-spin:check-in", "Simulate user check-in (with mock encrypted data)")
  .addParam("contract", "Contract address")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    
    const LuckySpinFHE = await ethers.getContractFactory("LuckySpinFHE");
    const luckySpinFHE = LuckySpinFHE.attach(taskArgs.contract);
    
    // Mock encrypted data for testing (32 bytes format)
    const encryptedSpins = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
    const attestation = "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890";
    
    console.log("Simulating user check-in...");
    await luckySpinFHE.checkIn(encryptedSpins, attestation);
    
    console.log("Check-in completed!");
  });

task("lucky-spin:spin", "Simulate user spin (with mock encrypted data)")
  .addParam("contract", "Contract address")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    
    const LuckySpinFHE = await ethers.getContractFactory("LuckySpinFHE");
    const luckySpinFHE = LuckySpinFHE.attach(taskArgs.contract);
    
    // Mock encrypted data for testing (32 bytes format)
    const encryptedPoolIndex = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
    const encryptedPoint = "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890";
    const attestationPool = "0x1111111111111111111111111111111111111111111111111111111111111111";
    const attestationPoint = "0x2222222222222222222222222222222222222222222222222222222222222222";
    
    console.log("Simulating user spin...");
    await luckySpinFHE.spinAndClaimReward(
      encryptedPoolIndex,
      encryptedPoint,
      attestationPool,
      attestationPoint
    );
    
    console.log("Spin completed!");
  });

task("lucky-spin:make-public", "Make user score public")
  .addParam("contract", "Contract address")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    
    const LuckySpinFHE = await ethers.getContractFactory("LuckySpinFHE");
    const luckySpinFHE = LuckySpinFHE.attach(taskArgs.contract);
    
    console.log("Making score public...");
    await luckySpinFHE.makeScorePublic();
    
    console.log("Score made public!");
  }); 