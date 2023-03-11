// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

struct SaleItem {
    uint256 tokenId;
    uint256 price;
    uint256 askingPrice;
    uint256 highestBid;
    address highestBidder;
    address sellerAddr;
    bool isAuction;
    address nftContract;
    address ERC20Contract;
}

contract MyMarketplace {
    // nftcontract =>  nftId => saleItem
    mapping(address => mapping(uint256 => SaleItem)) public marketNFTs;

    function listAuctionNFT(
        uint256 _tokenId,
        uint256 _askingPrice,
        address _nftContract,
        address _ERC20Contract
    ) public {
        require(
            IERC721(_nftContract).ownerOf(_tokenId) == msg.sender,
            "Only owner can list NFT"
        );
        require(
           marketNFTs[_nftContract][_tokenId].nftContract == address(0),
            "Already listed"
        );
        require(
            IERC721(_nftContract).getApproved(_tokenId) == address(this),
            "NFT is not approved to this contract"
        );
        require(_askingPrice > 0, "Asking price should be greater than 0");
        

        marketNFTs[_nftContract][_tokenId] = SaleItem(
            _tokenId, // nft token id
            0, // price
            _askingPrice, // minimum bid
            0, // max bid
            address(0), //  highestBidder
            msg.sender, // seller
            true, // isAuction
            _nftContract, // nft contract
            _ERC20Contract // erc20 contract address
        );
    }

    function listFixedPriceNFT(
        uint256 _tokenId,
        uint256 _price,
        address _nftContract,
        address _ERC20Contract
    ) public {
        require(
            IERC721(_nftContract).ownerOf(_tokenId) == msg.sender,
            "Only owner can list NFT"
        );
        require(
           marketNFTs[_nftContract][_tokenId].nftContract == address(0),
            "Already listed"
        );
        require(
            IERC721(_nftContract).getApproved(_tokenId) == address(this),
            "NFT is not approved to this contract"
        );
        if (_ERC20Contract != address(0)) {
        
            require(_price > 0, "price should be greater than 0");
           
        }

        marketNFTs[_nftContract][_tokenId] = SaleItem(
            _tokenId, // nft token id
            _price, // price
            0, // minimum bid
            0, // max bid
            address(0), //  highestBidder
            msg.sender, // seller
            false, // isAuction
            _nftContract, // nft contract
            _ERC20Contract // erc20 contract address
        );
    }

    function placeBid(
        address _nftContract,
        uint256 _nftId,
        uint256 amount
    ) public payable {
        SaleItem memory NftToBid = marketNFTs[_nftContract][_nftId];
        require(NftToBid.nftContract != address(0), "Invalid NFT");
        require(NftToBid.sellerAddr != msg.sender, "Owner cannot placed Bid");
        require(NftToBid.isAuction, "Not for auction");
        require(
            (msg.value >= NftToBid.askingPrice &&
                msg.value > NftToBid.highestBid) ||
                (amount >= NftToBid.askingPrice &&
                    amount > NftToBid.highestBid),
            "Bid should be greater than Asking price and highest Bid"
        );
        if (NftToBid.ERC20Contract == address(0)) {
            require(
                (msg.value >= NftToBid.askingPrice &&
                    msg.value > NftToBid.highestBid),
                "Bid should be greater than Asking price and highest Bid"
            );
            refund(
                NftToBid.highestBid,
                NftToBid.sellerAddr,
                NftToBid.ERC20Contract,
                NftToBid.highestBidder
            );
            marketNFTs[_nftContract][_nftId].highestBid = msg.value;
        } else {
            require(
                amount >= NftToBid.askingPrice && amount > NftToBid.highestBid,
                "Bid should be greater than Asking price and highest Bid"
            );
            require(
                IERC20(NftToBid.ERC20Contract).allowance(
                    msg.sender,
                    address(this)
                ) >= amount,
                "Not Enough tokens approved"
            );
            refund(
                NftToBid.highestBid,
                NftToBid.sellerAddr,
                NftToBid.ERC20Contract,
                NftToBid.highestBidder
            );
            marketNFTs[_nftContract][_nftId].highestBid = amount;
        }
        marketNFTs[_nftContract][_nftId].highestBidder = msg.sender;
    }

    function buyNft(
        address _nftContract,
        uint256 _nftId,
        address _ERC20Contract,
        uint256 amount
    ) public payable {
        SaleItem memory NftToBid = marketNFTs[_nftContract][_nftId];
        require(NftToBid.nftContract != address(0), "Invalid NFT");
        require(!NftToBid.isAuction, "NFT is on auction");
        if (NftToBid.ERC20Contract == address(0)) {
            require(
                msg.value == NftToBid.price,
                "Amount should be equal price"
            );
        } else {
            require(
                IERC20(_ERC20Contract).allowance(msg.sender, address(this)) >=
                    amount,
                "Not Enough tokens approved"
            );
        }

            // transfer amount to seller
            refund(msg.value, msg.sender, NftToBid.ERC20Contract, NftToBid.sellerAddr);

            // transfer nft to highestBidder
            IERC721(_nftContract).transferFrom(
                NftToBid.sellerAddr,
                msg.sender,
                _nftId
            );
        
        delete marketNFTs[_nftContract][_nftId];
    }

    function refund(
        uint256 _amount,
        address _from,
        address _ERC20Contract,
        address _to
    ) internal {
        if (_ERC20Contract == address(0)) {
            payable(_to).transfer(_amount);
        } else {
            IERC20(_ERC20Contract).transferFrom(_from, _to, _amount);
        }
    }

    function endAuction(
        address _nftContract,
        uint256 _nftId,
        address _ERC20Contract

    ) public {
        SaleItem memory NftToBid = marketNFTs[_nftContract][_nftId];
        require(msg.sender == NftToBid.sellerAddr, "Only seller can end Auction");

        if (NftToBid.highestBidder != address(0)) {
            // transfer amount to seller
            refund(NftToBid.highestBid, NftToBid.highestBidder, NftToBid.ERC20Contract, NftToBid.sellerAddr);

            // transfer nft to highestBidder
            IERC721(_nftContract).transferFrom(
                NftToBid.sellerAddr,
                NftToBid.highestBidder,
                _nftId
            );
        }

        // delete auction
        delete marketNFTs[_nftContract][_nftId];
    }
}
