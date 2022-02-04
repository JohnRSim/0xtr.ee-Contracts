const hre = require("hardhat");
const fs = require('fs');

async function main() {
  [owner] = await ethers.getSigners();
  console.log(`Owner: ${owner.address}`);
  await hre.run("compile");

  // Deploy TreeToken ERC20
  const treeTokenContract = await hre.ethers.getContractFactory('TreeToken');
  const treeToken = await treeTokenContract.deploy();
  await treeToken.deployed();
  console.log(`TreeToken deployed to: ${treeToken.address}`);

  // Deploy Tree Contract
  const treeContract = await hre.ethers.getContractFactory('Tree');
  const contractArtifacts = artifacts.readArtifactSync('Tree');
	fs.writeFileSync('./artifacts/contractArtifacts.json',  JSON.stringify(contractArtifacts, null, 2));

  const tree = await treeContract.deploy(treeToken.address);
  await tree.deployed();
  console.log(`Tree contract deployed to: ${tree.address}`);

  // Transfer ownership of TreeToken to Tree Contract
  await treeToken.transferOwnership(tree.address);
  console.log(`TreeToken Ownership transferred to: ${tree.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
