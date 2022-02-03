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



}
