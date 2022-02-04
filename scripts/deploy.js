const hre = require("hardhat");
const fs = require('fs');

async function main() {
   [owner] = await ethers.getSigners();
   console.log(`Owner: ${owner.address}`);
  const contractName = 'Tree';
  await hre.run("compile");
  const smartContract = await hre.ethers.getContractFactory(contractName);

  const contractArtifacts = artifacts.readArtifactSync('Tree');
	fs.writeFileSync('./artifacts/contractArtifacts.json',  JSON.stringify(contractArtifacts, null, 2));

  const contract = await smartContract.deploy();
  await contract.deployed();
  console.log(`${contractName} deployed to: ${contract.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
