const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Initial tests for Tree.sol",  () => {
  let owner,tree,nft,tokenId;

  before(async () => {
    [owner,user1,user2,user3] = await ethers.getSigners();
    console.log(`Owner: ${owner.address}`);
    const contractName = 'Tree';
    await hre.run("compile");
    // Deploy Tree.sol
    const Tree = await hre.ethers.getContractFactory('Tree');
    tree = await Tree.deploy();
    await tree.deployed();
    // Deploy TestNFT.sol
    const TestNFT = await hre.ethers.getContractFactory('TestNFT');
    nft = await TestNFT.deploy();
    await nft.deployed();
    tokenId = 1;
  });

  it("Mint a test NFT", async () => {
    await nft.mint(user1.address, tokenId);
    const balance = await nft.balanceOf(user1.address);
    expect(balance).to.be.eq('1');
  });

  it("Listen and log events", async () => {
    await expect(tree.connect(user3).placeBid(nft.address, tokenId, '1', { value: '1'}))
      .to.emit(tree, 'bidPlaced')
      .withArgs(nft.address, tokenId, user3.address, '1');
  });

  it("Place a bid for an NFT and check getBid returns it", async () => {
    await tree.placeBid(nft.address, tokenId, '1000000000000000000', { value: '1000000000000000000'});
    const tx = await tree.getBid(nft.address, tokenId);
    //console.log(tx.price);
    expect(tx.price.toString()).to.be.eq('1000000000000000000');
    const contractBalance = await ethers.provider.getBalance(tree.address);
    expect(contractBalance).to.be.eq('1000000000000000000');
  });

  it("Cancel a bid and have funds returned", async () => {
    const balance1 = await ethers.provider.getBalance(owner.address);
    await tree.cancelBid(nft.address, tokenId);
    const tx = await tree.getBid(nft.address, tokenId);
    //console.log(tx.price);
    expect(tx.price.toString()).to.be.eq('0');
    const balance2 = await ethers.provider.getBalance(owner.address);
    expect(balance2).to.be.gt(balance1);
  });

  it("Place a new bid for the same NFT", async () => {
    await tree.connect(user2).placeBid(nft.address, tokenId, '1000000000000000001', { value: '1000000000000000001'});
    const tx = await tree.getBid(nft.address, tokenId);
    expect(tx.price.toString()).to.be.eq('1000000000000000001');
    const contractBalance = await ethers.provider.getBalance(tree.address);
    expect(contractBalance).to.be.eq('1000000000000000001');
  });

  it("Place a higher bid for the NFT", async () => {
    const balance1 = await ethers.provider.getBalance(user2.address);
    await tree.connect(user3).placeBid(nft.address, tokenId, '1000000000000000002', { value: '1000000000000000002'});
    const balance2 = await ethers.provider.getBalance(user2.address);
    expect(balance2).to.be.gt(balance1); // check funds are returned
    const tx = await tree.getBid(nft.address, tokenId);
    expect(tx.bidder).to.be.eq(user3.address);
  });

  it("Accept a bid", async () => {
    const balance1 = await ethers.provider.getBalance(user1.address);
    await nft.connect(user1).approve(tree.address, tokenId);
    await tree.connect(user1).acceptBid(nft.address, tokenId, '1000000000000000002');
    const balance2 = await ethers.provider.getBalance(user1.address);
    expect(balance2).to.be.gt(balance1);
    const newOwner = await nft.ownerOf(tokenId);
    expect(newOwner).to.be.eq(user3.address);    
    const contractBalance = await ethers.provider.getBalance(tree.address);
    expect(contractBalance).to.be.eq('0');  
  });

  it("Reject a bid", async () => {
    await tree.connect(user1).placeBid(nft.address, tokenId, '1000000000000000003', { value: '1000000000000000003'});
    await tree.connect(user3).rejectBid(nft.address, tokenId);
    const tx = await tree.getBid(nft.address, tokenId);
    expect(tx.price).to.be.eq('0');
  });

  it("Update treasury fund", async () => {
    await tree.connect(owner).updateTreasuryAddress(user1.address);
    const treasury = await tree.treasury();
    expect(treasury).to.be.eq(user1.address);
    await tree.connect(user1).updateTreasuryAddress(user2.address);
    const treasury2 = await tree.treasury();
    expect(treasury2).to.be.eq(user2.address);
  });


});

