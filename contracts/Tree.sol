//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Tree {

  struct Bid {
    address nftContract;
    uint256 tokenId;
    address bidder;
    uint256 price;
    uint256 timestamp;
  }

  Bid[] public bids;

  address public treasury;

  event bidPlaced(address nftContract, uint256 tokenId, address bidder, uint256 price);
  event bidCancelled(address nftContract, uint256 tokenId, address bidder, uint256 price);
  event bidAccepted(address nftContract, uint256 tokenId, address bidder, uint256 price, address owner);
  event bidRejected(address nftContract, uint256 tokenId, address bidder, uint256 price);

  constructor() {
    treasury = msg.sender;
    // make sure bids[0] is filled for the for loops
    bids.push(Bid(address(0),0,address(0),0,block.timestamp));
  }

  function updateTreasuryAddress (address _newTreasury) public {
    require(msg.sender == treasury, "Update must come from treasury address");
    treasury = _newTreasury;
  }

  function _findBid(address _nftContract, uint256 _tokenId) internal view returns(uint256) {
    uint256 iBid = 0;
    for (uint i=0; i<bids.length; i++) {
      if (bids[i].nftContract == _nftContract) {
        if (bids[i].tokenId == _tokenId) {
          iBid = i;
        }
      }
    }
    return iBid;
  }
  
  function getBid(address _nftContract, uint256 _tokenId) public view returns (Bid memory) {
    for (uint i=0; i<bids.length; i++) {
      if (bids[i].nftContract == _nftContract) {
        if (bids[i].tokenId == _tokenId) {
          return bids[i];
        }
      }
    }
    return bids[0];
  }

  function placeBid(address _nftContract, uint256 _tokenId, uint256 _price) public payable {
    uint256 iBid = _findBid(_nftContract, _tokenId);
    require(_price > 0,"Price not set");
    require(msg.value >= _price, "Funds not received");
    if (iBid == 0) {
      bids.push(Bid(_nftContract,_tokenId,msg.sender,_price,block.timestamp));
      emit bidPlaced(_nftContract, _tokenId, msg.sender, _price);
    } else {
      if (bids[iBid].price < _price) {
        address payable bidderWallet = payable(bids[iBid].bidder);
        bidderWallet.transfer(bids[iBid].price); // secure?
        bids[iBid] = Bid(_nftContract,_tokenId,msg.sender,_price,block.timestamp);
      } else {
        revert("Higher bid already placed");
      }
    }
  }

  function cancelBid(address _nftContract, uint256 _tokenId) public {
    uint256 iBid = _findBid(_nftContract, _tokenId);
    require(iBid > 0, "Bid not found");
    require(bids[iBid].bidder == msg.sender, "Can not cancel this bid from this address");
    uint256 toPayBack = bids[iBid].price;
    address payable bidderWallet = payable(bids[iBid].bidder);
    delete bids[iBid];
    bidderWallet.transfer(toPayBack);
    emit bidCancelled(_nftContract, _tokenId, msg.sender, toPayBack);
  }

  function rejectBid(address _nftContract, uint256 _tokenId) public {
    uint256 iBid = _findBid(_nftContract, _tokenId);
    require(iBid > 0, "Bid not found");
    address owner = IERC721(_nftContract).ownerOf(_tokenId);
    require(msg.sender == owner, "You do not own this NFT");
    address bidder = bids[iBid].bidder;
    uint256 price = bids[iBid].price;
    delete bids[iBid];
    emit bidRejected(_nftContract, _tokenId, bidder, price);
  }

  function acceptBid(address _nftContract, uint256 _tokenId, uint256 _price) public {
    uint256 iBid = _findBid(_nftContract, _tokenId);
    require(iBid > 0, "Bid not found");
    require(_price == bids[iBid].price, "Price accepted does not match bid price");
    address owner = IERC721(_nftContract).ownerOf(_tokenId);
    require(msg.sender == owner, "You do not own this NFT");
    IERC721(_nftContract).transferFrom(owner, bids[iBid].bidder, _tokenId);
    uint commission = bids[iBid].price / 400;
    uint256 payment = bids[iBid].price - commission;
    address payable treasuryWallet = payable(treasury);
    address payable ownerWallet = payable(owner);
    address bidder = bids[iBid].bidder;
    delete bids[iBid];
    treasuryWallet.transfer(commission);
    ownerWallet.transfer(payment);
    emit bidAccepted(_nftContract, _tokenId, bidder, _price, owner);
  }

}
