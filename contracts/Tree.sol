//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter02.sol';

interface ITreeToken {
  function mint(address _to, uint256 _amount) external;
  function burn(uint256 _amount) external;
  function totalSupply() external returns (uint256);
}

interface IWMatic {
  function deposit() external payable;
  function approve(address spender, uint amount) external returns (bool);
	function transfer(address recipient, uint amount) external returns (bool);
  function balanceOf(address account) external view returns (uint);
}

contract Tree {

  struct Bid {
    address nftContract;
    uint256 tokenId;
    address bidder;
    uint256 price;
    uint256 timestamp;
  }

  Bid[] public bids;
  address public treeToken;
  uint256 public treeTokenMaxSupply = 100000000 ether; // 100m Tokens
  address public uniRouter;
  address public wMatic;
  ISwapRouter public immutable swapRouter;

  event bidPlaced(address nftContract, uint256 tokenId, address bidder, uint256 price);
  event bidCancelled(address nftContract, uint256 tokenId, address bidder, uint256 price);
  event bidAccepted(address nftContract, uint256 tokenId, address bidder, uint256 price, address owner);
  event bidRejected(address nftContract, uint256 tokenId, address bidder, uint256 price);

  constructor(address _treeToken, address _uniRouter, address _wMatic) {
    treeToken = _treeToken;
    uniRouter = _uniRouter;
    swapRouter = ISwapRouter(uniRouter);
    wMatic = _wMatic;
    // make sure bids[0] is filled for the for loops
    bids.push(Bid(address(0),0,address(0),0,block.timestamp));
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
    address payable ownerWallet = payable(owner);
    address bidder = bids[iBid].bidder;
    delete bids[iBid];
    ownerWallet.transfer(payment);
    emit bidAccepted(_nftContract, _tokenId, bidder, _price, owner);
    distributeRewards(owner,bidder,commission);
    buyBackAndBurn(commission);
  }

  function distributeRewards(address _owner, address _bidder, uint256 _commission) internal {
    uint256 treeTokenSupply = ITreeToken(treeToken).totalSupply();
    if (treeTokenSupply < treeTokenMaxSupply - 1 ether) {
      uint256 remainingTreeTokens = treeTokenMaxSupply - treeTokenSupply;
      uint256 diminishingSupplyFactor =  remainingTreeTokens * 100 / treeTokenMaxSupply;
      uint256 govTokenDistro = _commission * diminishingSupplyFactor ;
      require(govTokenDistro > 0, "Why is govTokenDistro below zero?");
      ITreeToken(treeToken).mint( _owner, govTokenDistro);
      ITreeToken(treeToken).mint( _bidder, govTokenDistro);
    }
  }

  function buyBackAndBurn(uint256 _commission) internal {
    require(address(this).balance >= _commission,"Not enough balance to pay commission");
    IWMatic(wMatic).deposit{ value: _commission }();
    require(IWMatic(wMatic).balanceOf(address(this)) >= _commission,"Not enough wMatic to pay commission");
    IWMatic(wMatic).approve(uniRouter, _commission);
    /*
    uint256 deadline = block.timestamp + 300;
    address tokenIn = wMatic;
    address tokenOut = treeToken;
    uint24 fee = 3000;
    address recipient = address(this);
    uint256 amountIn = _commission;
    uint256 amountOutMinimum = 0;
    uint160 sqrtPriceLimitX96 = 0;
    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
      tokenIn,
      tokenOut,
      fee,
      recipient,
      deadline,
      amountIn,
      amountOutMinimum,
      sqrtPriceLimitX96
    );
    //uint256 amountOut = ISwapRouter(uniRouter).exactInputSingle{ value: _commission }(params);
    uint256 amountOut = swapRouter.exactInputSingle(params);
    */
    uint24 fee = 3000;
    bytes memory path = abi.encodePacked(wMatic, fee, treeToken);
    address recipient = address(this);
    uint256 deadline = block.timestamp + 300;
    uint256 amountIn = _commission;
    uint256 amountOutMinimum = 0;
    ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams(
      path,
      recipient,
      deadline,
      amountIn,
      amountOutMinimum
    );
    uint256 amountOut = swapRouter.exactInput(params);
    ITreeToken(treeToken).burn(amountOut);
  }

}
