// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {TokenizedVickreyAuction} from "../src/TokenizedVickreyAuction.sol";
import {ERC20Token} from "../src/ERC20Token.sol";
import {ERC721Token} from "../src/ERC721Token.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract TokenizedVickreyAuctionTest is Test {
  TokenizedVickreyAuction public auction;
  ERC20Token public token;
  ERC721Token public nft;

  address seller = makeAddr("seller");
  address alice = makeAddr("alice");
  address bob = makeAddr("bob");
  address auctionAddress;
  address tokenAddress;
  address nftAddress;

  uint256 tokenId = 0; // the auctioned nft
  uint32 bidPeriod = 180; // 3 minute
  uint32 revealPeriod = 60; // 60 seconds
  uint96 reservePrice = 1 ether; // 1 erc token

  bytes32 nonce = bytes32(0);

  event AssetTransferred(address tokenContract, uint256 tokenId, address from, address to);
  
  function setUp() public {
    auction = new TokenizedVickreyAuction();
    token = new ERC20Token("NEUToken", "NEU", 18, 1000000);
    nft = new ERC721Token("NEUNFT", "NNFT");
    auctionAddress = address(auction);
    tokenAddress = address(token);
    nftAddress = address(nft);

    token.mint(seller, 300 ether);
    token.mint(bob, 500 ether);
    token.mint(alice, 100 ether);
    nft.batchMint(seller, 30);

    vm.startPrank(seller);
    nft.approve(auctionAddress, tokenId);
    vm.stopPrank();
  }

  function test_createAuction() public {
    vm.prank(seller);
    uint32 startTime = uint32(block.timestamp) + 10; // auction starts in 10 seconds
    auction.createAuction(nftAddress, tokenId, tokenAddress, startTime, bidPeriod, revealPeriod, reservePrice); // create an auction for the tokenId nft
    TokenizedVickreyAuction.Auction memory createdAuction = auction.getAuction(nftAddress, tokenId);

    assertEq(createdAuction.seller, seller);
    assertEq(createdAuction.startTime, startTime);
    assertEq(createdAuction.endOfBiddingPeriod, startTime + bidPeriod);
    assertEq(createdAuction.endOfRevealPeriod, startTime + bidPeriod + revealPeriod);
    assertEq(createdAuction.numUnrevealedBids, 0);
    assertEq(createdAuction.highestBid, reservePrice);
    assertEq(createdAuction.secondHighestBid, reservePrice);
    assertEq(createdAuction.highestBidder, seller);
    assertEq(createdAuction.index, 1);
  }

  function test_commitBid() public {
    // Create an auction
    vm.prank(seller);
    uint32 startTime = uint32(block.timestamp) + 10; // auction starts in 10 seconds
    auction.createAuction(nftAddress, tokenId, tokenAddress, startTime, bidPeriod, revealPeriod, reservePrice); // create an auction for the tokenId nft
    TokenizedVickreyAuction.Auction memory createdAuction = auction.getAuction(nftAddress, tokenId);

    vm.warp(startTime + 30); // start bidding 30 seconds after auction begins
    
    // Commit the bid with a collateral of 30
    vm.startPrank(alice);
    uint96 aliceBid = 5;
    uint96 collateral = 30 ether;
    bytes20 commitment = bytes20(keccak256(abi.encode(nonce, aliceBid, nftAddress, tokenId, createdAuction.index)));
    token.approve(auctionAddress, collateral);
    auction.commitBid(nftAddress, tokenId, commitment, collateral);
    TokenizedVickreyAuction.Bid memory bid =  auction.getBid(nftAddress, tokenId, createdAuction.index,alice);
    assertEq(bid.commitment, commitment);
    assertEq(bid.collateral, collateral);
  }

  function test_revealBid() public {
    // Create an auction
    vm.prank(seller);
    uint32 startTime = uint32(block.timestamp) + 10; // auction starts in 10 seconds
    auction.createAuction(nftAddress, tokenId, tokenAddress, startTime, bidPeriod, revealPeriod, reservePrice); // create an auction for the tokenId nft
    TokenizedVickreyAuction.Auction memory createdAuction = auction.getAuction(nftAddress, tokenId);

    vm.warp(startTime + 30); // start bidding 30 seconds after auction begins

    // Commit the bid with a collateral of 30
    vm.startPrank(alice);
    uint96 aliceBid = 5 ether;
    bytes20 aliceCommitment = bytes20(keccak256(abi.encode(nonce, aliceBid, nftAddress, tokenId, createdAuction.index)));
    uint96 aliceCollateral = 30 ether;
    token.approve(auctionAddress, aliceCollateral);
    auction.commitBid(nftAddress, tokenId, aliceCommitment, aliceCollateral);

    // Commit the bid with a collateral of 50
    vm.startPrank(bob);
    uint96 bobBid = 10 ether;
    bytes20 bobCommitment = bytes20(keccak256(abi.encode(nonce, bobBid, nftAddress, tokenId, createdAuction.index)));
    uint96 bobCollateral = 50 ether;
    token.approve(auctionAddress, bobCollateral);
    auction.commitBid(nftAddress, tokenId, bobCommitment, bobCollateral);

    vm.warp(startTime + 200); // set the revealing time
    vm.startPrank(alice);
    auction.revealBid(nftAddress, tokenId, aliceBid, nonce);

    vm.warp(startTime + 230); // set the revealing time
    vm.startPrank(bob);
    auction.revealBid(nftAddress, tokenId, bobBid, nonce);

    TokenizedVickreyAuction.Auction memory updatedAuction = auction.getAuction(nftAddress, tokenId);
    assertEq(updatedAuction.highestBid, bobBid);
    assertEq(updatedAuction.secondHighestBid, aliceBid);
    assertEq(updatedAuction.highestBidder, bob);
  }

  function test_endAuction() public {
    // Create an auction
    vm.prank(seller);
    uint32 startTime = uint32(block.timestamp) + 10; // auction starts in 10 seconds
    auction.createAuction(nftAddress, tokenId, tokenAddress, startTime, bidPeriod, revealPeriod, reservePrice); // create an auction for the tokenId nft
    TokenizedVickreyAuction.Auction memory createdAuction = auction.getAuction(nftAddress, tokenId);

    vm.warp(startTime + 30); // start bidding 30 seconds after auction begins

    // Commit the bid with a collateral of 30
    vm.startPrank(alice);
    uint96 aliceBid = 5 ether;
    bytes20 aliceCommitment = bytes20(keccak256(abi.encode(nonce, aliceBid, nftAddress, tokenId, createdAuction.index)));
    uint96 aliceCollateral = 30 ether;
    token.approve(auctionAddress, aliceCollateral);
    auction.commitBid(nftAddress, tokenId, aliceCommitment, aliceCollateral);

    // Commit the bid with a collateral of 50
    vm.startPrank(bob);
    uint96 bobBid = 10 ether;
    bytes20 bobCommitment = bytes20(keccak256(abi.encode(nonce, bobBid, nftAddress, tokenId, createdAuction.index)));
    uint96 bobCollateral = 50 ether;
    token.approve(auctionAddress, bobCollateral);
    auction.commitBid(nftAddress, tokenId, bobCommitment, bobCollateral);

    vm.warp(startTime + 200); // set the revealing time
    vm.startPrank(alice);
    auction.revealBid(nftAddress, tokenId, aliceBid, nonce);

    vm.warp(startTime + 230); // set the revealing time
    vm.startPrank(bob);
    auction.revealBid(nftAddress, tokenId, bobBid, nonce);

    vm.warp(startTime + 241); // end the auction
    vm.expectEmit(true, true, true, true);
    emit AssetTransferred(nftAddress, tokenId, seller, bob);
    auction.endAuction(nftAddress, tokenId);

    uint256 sellerBalance = token.balanceOf(seller);
    uint256 winnerBalance = token.balanceOf(bob);
    uint256 loserBalance = token.balanceOf(alice);
    assertEq(winnerBalance, 500 ether - aliceBid); // winner's collateral has already been returned
    assertEq(loserBalance, 100 ether - aliceCollateral); // loser's collateral hasn't been returned
    assertEq(sellerBalance, 300 ether + aliceBid);
  }

  function test_withdrawCollateral() public {
    // Create an auction
    vm.prank(seller);
    uint32 startTime = uint32(block.timestamp) + 10; // auction starts in 10 seconds
    auction.createAuction(nftAddress, tokenId, tokenAddress, startTime, bidPeriod, revealPeriod, reservePrice); // create an auction for the tokenId nft
    TokenizedVickreyAuction.Auction memory createdAuction = auction.getAuction(nftAddress, tokenId);

    vm.warp(startTime + 30); // start bidding 30 seconds after auction begins

    // Commit the bid with a collateral of 30
    vm.startPrank(alice);
    uint96 aliceBid = 5 ether;
    bytes20 aliceCommitment = bytes20(keccak256(abi.encode(nonce, aliceBid, nftAddress, tokenId, createdAuction.index)));
    uint96 aliceCollateral = 30 ether;
    token.approve(auctionAddress, aliceCollateral);
    auction.commitBid(nftAddress, tokenId, aliceCommitment, aliceCollateral);

    // Commit the bid with a collateral of 50
    vm.startPrank(bob);
    uint96 bobBid = 10 ether;
    bytes20 bobCommitment = bytes20(keccak256(abi.encode(nonce, bobBid, nftAddress, tokenId, createdAuction.index)));
    uint96 bobCollateral = 50 ether;
    token.approve(auctionAddress, bobCollateral);
    auction.commitBid(nftAddress, tokenId, bobCommitment, bobCollateral);

    vm.warp(startTime + 200); // set the revealing time
    vm.startPrank(alice);
    auction.revealBid(nftAddress, tokenId, aliceBid, nonce);

    vm.warp(startTime + 230); // set the revealing time
    vm.startPrank(bob);
    auction.revealBid(nftAddress, tokenId, bobBid, nonce);

    vm.warp(startTime + 241); // end the auction
    vm.expectEmit(true, true, true, true);
    emit AssetTransferred(nftAddress, tokenId, seller, bob);
    auction.endAuction(nftAddress, tokenId);

    vm.startPrank(alice);
    vm.warp(startTime + 241);
    auction.withdrawCollateral(nftAddress, tokenId, createdAuction.index);

    uint256 loserBalance = token.balanceOf(alice);
    assertEq(loserBalance, 100 ether);
  }
}