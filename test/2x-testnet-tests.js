const { expect } = require("chai");
const { ethers } = require("hardhat");

const treeAddress = '0x8ae971D2D8a33BF1BC86E5A01651a85A8EAc3112';
const treeTokenAddress = '';

describe("Testnet tests for Tree.sol",  () => {
  let owner,user1,tree,nft,tokenId,treeToken;

  before(async () => {
    [owner,user1] = await ethers.getSigners();
    console.log(`Owner: ${owner.address}`);
    await hre.run("compile");
    const treeContract = await hre.ethers.getContractFactory('Tree');
    tree = await treeContract.attach(treeAddress);

    // Deploy TestNFT.sol
    const TestNFT = await hre.ethers.getContractFactory('TestNFT');
    nft = await TestNFT.deploy();
    await nft.deployed();
    tokenId = 1;
  });

  it("Mint a test NFT", async () => {
    const tx = await nft.mint(owner.address, tokenId);
    await tx.wait();
    const balance = await nft.balanceOf(owner.address);
    expect(balance).to.be.eq('1');
  });

  it("Place a bid for an NFT and check getBid returns it", async () => {
    const bidPrice  = ethers.utils.parseEther('0.000004');
    const tx = await tree.connect(user1).placeBid(nft.address, tokenId, bidPrice, { value: bidPrice});
    await tx.wait();
    const txObj = await tree.getBid(nft.address, tokenId);
    expect(txObj.price.toString()).to.be.eq(bidPrice);
  });

  it("Accept a bid", async () => {
    const bidPrice  = ethers.utils.parseEther('0.000004');
    const balance1 = await ethers.provider.getBalance(owner.address);
    const tx = await nft.connect(owner).approve(tree.address, tokenId);
    await tx.wait();
    const tx2 = await tree.connect(owner).acceptBid(nft.address, tokenId, bidPrice,{ gasLimit: 5000000 });
    await tx2.wait();
    const balance2 = await ethers.provider.getBalance(owner.address);
    expect(balance2).to.be.lt(balance1);
    const newOwner = await nft.ownerOf(tokenId);
    expect(newOwner).to.be.eq(owner.address);    
  });

});

