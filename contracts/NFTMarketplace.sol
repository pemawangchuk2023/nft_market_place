// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @title NFT Marketplace
 * @dev A decentralized platform for minting, purchasing, and selling unique digital assets (NFTs). 
 * This marketplace allows users to create NFTs with associated metadata, list them for sale, 
 * engage in auctions, and manage their digital collectibles. It leverages the ERC721 standard 
 * for non-fungible tokens to ensure the uniqueness and ownership of each asset.
 * The contract handles all marketplace transactions, including listing, buying, auctioning, and 
 * transferring ownership of NFTs, while also maintaining a royalty system for creators.
 * @author Pema Wangchuk
 */

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "hardhat/console.sol";

contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    uint256 private listingPrice = 0.025 ether;
    address payable private owner;

    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) private _bids;


    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }
    struct Auction {
    uint256 startPrice;
    uint256 endTimestamp;
    address highestBidder;
    uint256 highestBid;
    bool active;
    }

    struct Royalty {
    address payable creator;
    uint256 rate; 

    }
    event MarketItemCreated (
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    /**
     * @dev Sets up the marketplace with a default name and symbol for the tokens.
     */
    constructor() ERC721("Pemaverse Tokens", "PW") {
        owner = payable(msg.sender);
    }
    
        /**
    * @dev Allows a user to mint a new token with a specified metadata URI and list it for sale in the marketplace. 
    * The function increments the token counter, mints the new token, sets its URI, creates a market item for it, 
    * and returns the new token ID. Requires the attached value to match the listing price.
    *
    * @param tokenURI The metadata URI that points to the token's attributes and details.
    * @param price The price at which the token will be listed for sale in the marketplace.
    * @return uint The unique identifier (token ID) of the newly minted token.
 */
    function createToken(string memory tokenURI, uint256 price) public payable returns (uint) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        createMarketItem(newTokenId, price);
        return newTokenId;
    }
        /**
    * @dev Enables the owner of a token to list it for resale in the marketplace. The function sets the token's status to unsold, 
    * updates its price, and transfers ownership back to the contract pending a future sale. It decrements the count of items sold.
    * The function requires the caller to be the owner of the token and the attached value to match the current listing price.
    *
    * @param tokenId The unique identifier for the token/NFT being listed for resale.
    * @param price The new sale price to list the token for in the marketplace.
    */
    function resellToken(uint256 tokenId, uint256 price) public payable {
        require(idToMarketItem[tokenId].owner == msg.sender, "Only item owner can perform this operation");
        require(msg.value == listingPrice, "Price must be equal to listing price");

        idToMarketItem[tokenId].sold = false;
        idToMarketItem[tokenId].price = price;
        idToMarketItem[tokenId].seller = payable(msg.sender);
        idToMarketItem[tokenId].owner = payable(address(this));

        _itemsSold.decrement();

        _transfer(msg.sender, address(this), tokenId);
    }

    /**
    * @dev Executes the sale of a market item. This public function allows a buyer to purchase an NFT listed in the marketplace
    * by providing the asking price. It transfers the ownership of the NFT from the contract to the buyer and marks the item as sold.
    * It increments the count of items sold and transfers the listing fee to the marketplace owner. Requires the provided value to match
    * the asking price of the item.
    *
    * @param tokenId The unique identifier for the token/NFT being purchased.
    */
    function createMarketSale(uint256 tokenId) public payable {
        uint price = idToMarketItem[tokenId].price;
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");

        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].sold = true;
        _itemsSold.increment();
        _transfer(address(this), msg.sender, tokenId);
        payable(owner).transfer(listingPrice);
    }

    /**
    * @dev Initiates an auction for a specified NFT (Non-Fungible Token).
    * The auction is created with a starting price and an ending timestamp.
    * Only the owner of the NFT can start an auction. The auction details are 
    * then recorded in the auctions mapping against the provided tokenId.
    *
    * @param tokenId The unique identifier for the NFT to auction.
    * @param startPrice The minimum price at which the auction will start.
    * @param endTimestamp The UNIX timestamp at which the auction will end.
    */
    function startAuction(uint256 tokenId, uint256 startPrice, uint256 endTimestamp) public {
        require(msg.sender == ownerOf(tokenId), "Only the owner can start an auction.");
        auctions[tokenId] = Auction(startPrice, endTimestamp, address(0), 0, true);
    }


        /**
    * @dev Finalizes an auction, transferring ownership of the NFT to the highest bidder
    * and sending the bid funds to the seller. It can only be called once the auction end
    * time has passed. If there are no bids, the NFT remains with the original owner.
    * This function also ensures that the auction is marked as inactive and the highest
    * bid is reset to zero to prevent repeated finalizations.
    *
    * @param tokenId The unique identifier for the NFT whose auction is to be finalized.
    */
    function finalizeAuction(uint256 tokenId) public {
        require(auctions[tokenId].active, "No active auction for this token.");
        require(block.timestamp >= auctions[tokenId].endTimestamp, "The auction has not ended yet.");

        auctions[tokenId].active = false;
        if (auctions[tokenId].highestBidder != address(0)) {
            // Transfer the NFT to the highest bidder
            _transfer(address(this), auctions[tokenId].highestBidder, tokenId);
             
             // Reset the highest bid
            _bids[tokenId][auctions[tokenId].highestBidder] = 0;
            
            // Transfer the bid amount to the seller
            address payable seller = idToMarketItem[tokenId].seller;
            seller.transfer(auctions[tokenId].highestBid);
        }

       
    }


        /**
    * @dev Allows participants to place a bid on an active auction. The function requires
    * the auction to be active and not yet ended. The bid value must exceed the current
    * highest bid. If there was a previous highest bidder, their bid is stored to allow
    * for a refund. The new highest bid and bidder are recorded, and the bid amount is 
    * held within the contract.
    *
    * @param tokenId The unique identifier for the NFT being auctioned.
    */
    function placeBid(uint256 tokenId) public payable {
        require(auctions[tokenId].active, "No active auction for this token.");
        require(block.timestamp < auctions[tokenId].endTimestamp, "The auction has already ended.");
        require(msg.value > auctions[tokenId].highestBid, "Bid must be higher than the current highest bid.");

        // If there's a previous bid, it's added to the previous bidder's total refundable amount
        if (auctions[tokenId].highestBidder != address(0)) {
            _bids[tokenId][auctions[tokenId].highestBidder] += auctions[tokenId].highestBid;
        }

        // Set the new highest bidder and bid amount
        auctions[tokenId].highestBidder = msg.sender;
        auctions[tokenId].highestBid = msg.value;
        _bids[tokenId][msg.sender] = msg.value;
    }
    /**
    * @dev Enables bidders to withdraw their bids for a token. This function can only be called
    * by a bidder who has a bid on the specified token. It ensures the bidder has a non-zero bid,
    * then resets their bid amount to zero before transferring the bid amount back to them.
    * This withdrawal mechanism is essential to prevent locking participants' funds indefinitely
    * and allows for bid withdrawal in case a bidder decides to retract their bid for any reason.
    *
    * @param tokenId The unique identifier for the NFT that the bid was placed on.
    */
    function withdrawBid(uint256 tokenId) public {
        uint256 bidAmount = _bids[tokenId][msg.sender];
        require(bidAmount > 0, "You do not have any bids to withdraw for this token.");

        // Reset the bid to prevent re-entrancy attacks before transferring funds
        _bids[tokenId][msg.sender] = 0;

        // Transfer the bid amount back to the bidder
        payable(msg.sender).transfer(bidAmount);
    }

    /**
    * @dev Private function to create a market item for a token. This function is called internally when a new token 
    * is minted via `createToken`. It initializes a new market item with the given token ID and price, and sets the 
    * market item's state to unsold. The newly created item is then transferred to the marketplace contract, ready to be
    * purchased by a buyer. This function also emits the `MarketItemCreated` event to signal the creation of the new market item.
    *
    * @param tokenId The ID of the token to be put on sale in the marketplace.
    * @param price The price at which the token is to be listed, which must be greater than 0.
    */
    function createMarketItem(
        uint256 tokenId,
        uint256 price
    ) private {
        require(price > 0, "Price must be at least 1 wei");
        require(msg.value == listingPrice, "Price must be equal to listing price");

        idToMarketItem[tokenId] =  MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            price,
            false
        );

        _transfer(msg.sender, address(this), tokenId);
        emit MarketItemCreated(
            tokenId,
            msg.sender,
            address(this),
            price,
            false
        );
    }

    /**
    * @dev Retrieves the list of all NFTs currently available for sale on the marketplace.
    * This function goes through the list of all minted tokens and checks which ones are still owned by the contract,
    * indicating they haven't been sold yet. It returns an array containing the details of these unsold market items.
    *
    * @return MarketItem[] An array of unsold market items, where each MarketItem includes tokenId, seller, current owner 
    * (the contract address in this case), price, and the sold status (which should be false for all items returned by this function).
    */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint itemCount = _tokenIds.current();
        uint unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        for (uint i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this)) {
                uint currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        
        return items;
    }

    /**
    * @dev Retrieves the list of NFTs owned by the caller of the function. This function scans through
    * all the market items to check if the caller is the current owner. If the caller owns the item,
    * it is added to the array of items to be returned. This provides a convenient way for users to
    * see all the NFTs they have purchased from the marketplace.
    *
    * @return MarketItem[] An array of market items owned by the caller. Each item includes details like
    * tokenId, seller, owner, price, and whether it has been sold.
    */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        // Count how many items the caller owns
        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        // Initialize an array to store the items owned by the caller
        MarketItem[] memory items = new MarketItem[](itemCount);

        // Populate the array with items owned by the caller
        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    /**
    * @dev Retrieves the list of market items created by the caller of the function.
    * It goes through all the items ever created and checks if the caller is the seller of the item.
    * If the caller is the seller, the item is added to the array of items to be returned.
    * This provides a way for users to see all the items they have put up for sale in the marketplace.
    *
    * @return MarketItem[] An array of market items created by the caller. Each item includes details like
    * tokenId, seller, owner, price, and sale status.
    */
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        // Count the number of items created by the caller
        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        // Prepare an array to hold the items
        MarketItem[] memory items = new MarketItem[](itemCount);

        // Populate the array with items created by the caller
        for (uint i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }


   
        /**
    * @dev Sets a new listing price for creating market items.
    * The listing price is the fee that users pay to list their NFTs on the marketplace.
    * This function can only be called by the owner of the contract, providing a control mechanism
    * for the marketplace operator to adjust the listing fee in response to market conditions or business strategy.
    * The listing price is paid by users every time they mint an NFT and want to list it on the marketplace.
    *
    * @param _listingPrice The new fee to be paid by users for listing an NFT (in wei).
    */
    function updateListingPrice(uint _listingPrice) public payable {
        // Check if the caller of the function is the owner of the contract
        require(owner == msg.sender, "Only marketplace owner can update listing price.");
        
        // Set the new listing price
        listingPrice = _listingPrice;
    }


    /**
    * @dev Allows the owner of a token to set or update its associated metadata URI.
    * This function is crucial for updating the metadata of a token post-minting. 
    * It ensures that only the current owner can update the URI, preserving the integrity 
    * of the token's metadata. If the metadata needs to be updated or corrected after the 
    * token has been minted, this function will be called.
    *
    * @param tokenId The unique identifier for the NFT whose URI is being set or updated.
    * @param _tokenURI The new metadata URI that will be associated with the NFT.
    */
    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        // Ensure the caller is the owner of the token
        require(msg.sender == ownerOf(tokenId), "Only the owner can set the token URI.");

        // Update the token's metadata URI
        _setTokenURI(tokenId, _tokenURI);
    }
    
}


