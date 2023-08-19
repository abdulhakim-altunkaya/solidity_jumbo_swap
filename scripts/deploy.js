const hre = require("hardhat");

async function main() {
  const jumboSwap = await hre.ethers.deployContract("JumboSwap", [], {});
  await jumboSwap.waitForDeployment();
  console.log(`JumboSwap deployed to ${jumboSwap.target}`);
}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

