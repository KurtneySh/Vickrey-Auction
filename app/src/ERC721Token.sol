// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract ERC721Token is ERC721 {
  uint256 private tokenId;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

  function mint(address to) public {
    // Ensure the recipient address is not zero
    require(to != address(0), "ERC721: mint to the zero address");

    _mint(to, tokenId);
    tokenId += 1;
  }

  function batchMint(address to, uint256 numberOfTokens) public {
    // Ensure the recipient address is not zero
    require(to != address(0), "ERC721: mint to the zero address");

    for (uint256 i = 0; i < numberOfTokens; i++) {
      _mint(to, tokenId);
      tokenId++;
    }
  }
}
