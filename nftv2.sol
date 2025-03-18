// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MyNFT is ERC721URIStorage, Ownable {
    using Strings for uint256;

    uint256 public nextTokenId;
    uint256 public mintPrice;
    uint256 public maxSupply;
    string public baseTokenURI;

    struct Listing {
        address seller;
        uint256 price;
        bool isListed;
    }

    mapping(uint256 => Listing) public listings;

    event Minted(address to, uint256 tokenId);
    event MintPriceChanged(uint256 newPrice);
    event Withdrawn(address to, uint256 amount);

    event NFTListed(address seller, uint256 tokenId, uint256 price);
    event NFTSold(address buyer, uint256 tokenId, uint256 price);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseTokenURI,
        uint256 _mintPrice,
        uint256 _maxSupply
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        baseTokenURI = _baseTokenURI;
        mintPrice = _mintPrice;
        maxSupply = _maxSupply;
    }

    function mint() external payable {
        require(nextTokenId < maxSupply, "Max supply reached");
        require(msg.value >= mintPrice, "Insufficient payment");

        uint256 tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, string(abi.encodePacked(tokenId.toString(), ".json")));

        emit Minted(msg.sender, tokenId);
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
        emit MintPriceChanged(_mintPrice);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
        
        emit Withdrawn(owner(), balance);
    }

    function totalSupply() external view returns (uint256) {
        return nextTokenId;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    // Marketplace functions

    function listNFTForSale(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Not the NFT owner");
        require(price > 0, "Price must be greater than zero");

        listings[tokenId] = Listing(msg.sender, price, true);

        emit NFTListed(msg.sender, tokenId, price);
    }

    function buyNFT(uint256 tokenId) external payable {
        Listing memory listing = listings[tokenId];

        require(listing.isListed, "NFT not for sale");
        require(msg.value >= listing.price, "Insufficient funds");

        address seller = listing.seller;

        // Use safeTransferFrom to ensure the recipient can accept the token
        _safeTransfer(seller, msg.sender, tokenId, "");

        // Transfer funds to the seller
        payable(seller).transfer(msg.value);

        // Mark the listing as no longer available
        listings[tokenId].isListed = false;

        emit NFTSold(msg.sender, tokenId, listing.price);
    }

    function cancelListing(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];

        require(listing.isListed, "NFT is not listed for sale");
        require(ownerOf(tokenId) == msg.sender, "Not the NFT owner");

        // Mark the NFT as no longer listed for sale
        listing.isListed = false;

        emit NFTListed(msg.sender, tokenId, 0); // Emit an event for cancellation
    }
}
