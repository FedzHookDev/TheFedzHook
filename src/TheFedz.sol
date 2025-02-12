// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TheFedz is ERC721A, Ownable {
    using Strings for uint256;
    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant RANGE_SIZE = 10;
    bool public contractPaused;
    string baseTokenURI;

    mapping(uint256 => uint256) public priceRanges;

    constructor(address _owner) ERC721A("The Fedz", "NFDZ") Ownable(_owner) {
        contractPaused = false;
        baseTokenURI = "ipfs://QmegxRhPaCU2DCm82SMrHKMArW25qg736GSJGWqVCYgwbZ/";
    }

    function setPriceForRange(uint256 rangeIndex, uint256 price)
        external
        onlyOwner
    {
        require(
            rangeIndex > 0 && rangeIndex <= (MAX_SUPPLY / RANGE_SIZE),
            "Invalid range index"
        );
        priceRanges[rangeIndex] = price;
    }

    function setPricesForRangeArray(uint256[] memory prices)
        external
        onlyOwner
    {
        uint256 numRanges = MAX_SUPPLY / RANGE_SIZE;
        require(prices.length == numRanges, "Invalid prices array length");

        for (uint256 i = 1; i <= numRanges; i++) {
            priceRanges[i] = prices[i - 1];
        }
    }

    function getPrice(uint256 tokenId) public view returns (uint256) {
        require(
            tokenId >= 1 && tokenId <= MAX_SUPPLY,
            "Token ID out of bounds"
        );
        uint256 rangeIndex = (tokenId - 1) / RANGE_SIZE + 1;
        uint256 price = priceRanges[rangeIndex];
        require(price > 0, "No price set for this range");
        return price;
    }

    function getCurrentMintPrice() public view returns (uint256) {
        require(totalSupply() < MAX_SUPPLY, "All NFTs are minted");
        uint256 nextTokenId = totalSupply() + 1;
        return getPrice(nextTokenId);
    }

    function getTotalCost(uint256 quantity) public view returns (uint256) {
        require(quantity > 0, "Quantity must be greater than 0");
        uint256 currentSupply = totalSupply();
        require(currentSupply + quantity <= MAX_SUPPLY, "Exceeds max supply");

        uint256 totalCost = 0;
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = currentSupply + i + 1;
            totalCost += getPrice(tokenId);
        }

        return totalCost;
    }

    function mint(uint256 quantity) external payable {
        require(!contractPaused, "Sale Paused!");
        uint256 currentSupply = totalSupply();
        require(currentSupply + quantity <= MAX_SUPPLY, "Exceeds max supply");
        uint256 totalCost = 0;
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = currentSupply + i + 1;
            totalCost += getPrice(tokenId);
        }
        require(msg.value >= totalCost, "Insufficient ETH sent");
        payable(owner()).transfer(totalCost);
        _mint(msg.sender, quantity);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function adminMint(address _to, uint256 _quantity) public {
        require(!contractPaused, "Sale Paused!");
        require(totalSupply() + _quantity <= MAX_SUPPLY, "Max supply reached!");
        _mint(_to, _quantity);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function pauseContract() public onlyOwner {
        contractPaused = true;
    }

    function unpauseContract() public onlyOwner {
        contractPaused = false;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        ".json"
                    )
                )
                : "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function listMyNFTs(address owner) public view returns (uint256[] memory) {
        unchecked {
            uint256 tokenIdsIdx;
            address currOwnershipAddr;
            uint256 tokenIdsLength = balanceOf(owner);
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);
            TokenOwnership memory ownership;
            for (
                uint256 i = _startTokenId();
                tokenIdsIdx != tokenIdsLength;
                ++i
            ) {
                ownership = _ownershipAt(i);
                if (ownership.burned) {
                    continue;
                }
                if (ownership.addr != address(0)) {
                    currOwnershipAddr = ownership.addr;
                }
                if (currOwnershipAddr == owner) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            return tokenIds;
        }
    }

    function tokenByIndex(uint256 index) public view returns (uint256) {
        require(index < totalSupply(), "ERC721A: global index out of bounds");
        unchecked {
            return index + _startTokenId();
        }
    }

    function listAllNFTAndOwner()
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256 totalSupply = totalSupply();
        address[] memory addresses = new address[](totalSupply);
        uint256[] memory ids = new uint256[](totalSupply);
        for (uint256 i = 0; i < totalSupply; i++) {
            addresses[i] = ownerOf(i + 1);
            ids[i] = tokenByIndex(i);
        }
        return (addresses, ids);
    }
}