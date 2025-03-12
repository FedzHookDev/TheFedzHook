// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../erc721a/contracts/IERC721A.sol";

interface ITheFedz is IERC721A {

    function setPriceForRange(uint256 rangeIndex, uint256 price) external;

    function setPricesForRangeArray(uint256[] memory prices) external;

    function getPrice(uint256 tokenId) external view returns (uint256);

    function getCurrentMintPrice() external view returns (uint256);

    function getTotalCost(uint256 quantity) external view returns (uint256);

    function mint(uint256 quantity) external payable;

    function withdraw() external;

    function adminMint(address _to, uint256 _quantity) external;

    function setBaseURI(string memory baseURI) external;

    function pauseContract() external;

    function unpauseContract() external;

    function listMyNFTs(address owner) external view returns (uint256[] memory);

    function tokenByIndex(uint256 index) external view returns (uint256);

    function listAllNFTAndOwner()
        external
        view
        returns (address[] memory, uint256[] memory);
}