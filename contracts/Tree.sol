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

}
