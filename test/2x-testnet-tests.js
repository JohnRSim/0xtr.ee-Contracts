const { expect } = require("chai");
const { ethers } = require("hardhat");

const treeAddress = '0xdb4911f8eC72f4E8B213e52bB932adE330Eb7EBb';
const treeTokenAddress = '0x2a22886bFF44358Cbdd719eD40A3641E600138A6';

describe("Testnet tests for Tree.sol",  () => {
  let owner,user1,tree,nft,nft1155,tokenId,treeToken;

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

    // Deploy TestERC1155.sol
    const TestERC1155 = await hre.ethers.getContractFactory('TestERC1155');
    nft1155 = await TestERC1155.deploy();
    await nft1155.deployed();
  });

  it("Mint a test NFT ERC721", async () => {
    const tx = await nft.mint(owner.address, tokenId);
    await tx.wait();
    const balance = await nft.balanceOf(owner.address);
    expect(balance).to.be.eq('1');
  });

  it("Mint a test NFT ERC1155", async () => {
    const tx = await nft1155.mint(owner.address, tokenId);
    await tx.wait();
    const balance = await nft1155.balanceOf(owner.address,tokenId);
    expect(balance).to.be.eq('1');
  });

  it("Place a bid for an ERC721 NFT and check getBid returns it", async () => {
    const bidPrice  = ethers.utils.parseEther('0.000004');
    const tx = await tree.connect(user1).placeBid(nft.address, tokenId, bidPrice, { value: bidPrice});
    await tx.wait();
    const txObj = await tree.getBid(nft.address, tokenId);
    expect(txObj.price.toString()).to.be.eq(bidPrice);
  });

  it("Accept a ERC721 bid", async () => {
    const bidPrice  = ethers.utils.parseEther('0.000004');
    const balance1 = await ethers.provider.getBalance(owner.address);
    const tx = await nft.connect(owner).approve(tree.address, tokenId);
    await tx.wait();
    const tx2 = await tree.connect(owner).acceptBid(nft.address, tokenId, bidPrice,{ gasLimit: 5000000 });
    await tx2.wait();
    const balance2 = await ethers.provider.getBalance(owner.address);
    expect(balance2).to.be.lt(balance1);
    const newOwner = await nft.ownerOf(tokenId);
    expect(newOwner).to.be.eq(user1.address);    
  });

  it("Place a bid for an ERC1155 NFT and check getBid returns it", async () => {
    const bidPrice  = ethers.utils.parseEther('0.000005');
    const tx = await tree.connect(user1).placeBid(nft1155.address, tokenId, bidPrice, { value: bidPrice});
    await tx.wait();
    const txObj = await tree.getBid(nft1155.address, tokenId);
    expect(txObj.price.toString()).to.be.eq(bidPrice);
  });

  it("Accept a ERC1155 bid", async () => {
    const bidPrice  = ethers.utils.parseEther('0.000005');
    const balance1 = await ethers.provider.getBalance(owner.address);
    const tx = await nft1155.connect(owner).setApprovalForAll(user1.address, true);
    await tx.wait();
    const tx4 = await nft1155.connect(owner).setApprovalForAll(tree.address, true);
    await tx4.wait();
    console.log('TestB');
  /*
    const approved = await nft1155.connect(owner).isApprovedForAll(owner.address, user1.address);
    expect(approved).to.be.eq(true);

    const tx3 = await tree.getBid(nft1155.address, tokenId);
    console.log('user1',user1.address);
    console.log(tx3);

    const tx2 = await tree.connect(owner).acceptBid(nft1155.address, tokenId, bidPrice,{ gasLimit: 5000000 });
    await tx2.wait();
    console.log('TestC');
    //const balance = await nft1155.balanceOf(user1.address,tokenId);
    //expect(balance).to.be.eq('1');
*/
  });

});

