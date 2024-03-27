// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "hardhat/console.sol";
import {ERC404UniswapV3Exempt} from "../extensions/ERC404UniswapV3Exempt.sol";
import "./ERC404/ERC404.sol";

contract MBro is ERC404 {
    string public baseTokenURI;
    using Strings for uint256;

    //@dev token values constant for efficiency
    uint256 private constant CARTONS = 200;
    uint256 private constant PACKS = 20;
    uint256 private constant LOOSIES = 1;
    uint8 private constant NUM_TOKEN_VALUES = 3;

    ///@dev token values need to be in descending order for loopBurn logic to work
    uint256[NUM_TOKEN_VALUES] public tokenValue = [
        CARTONS, PACKS, LOOSIES];
 /// work on this
    mapping(uint256 => string) internal _tokenValueURI;
    mapping(uint256 => string) internal _tokenURIs;
    mapping(uint256 => uint256) internal _valueOfId;  // map unique token IDs by value
/// @todo create getter setter functions for this  
    mapping(address => mapping(uint256 => uint256[])) internal _idsOwned;  // Owned ids by type
    mapping(uint256 => uint256) internal _idsOwnedIndex; // Tracks indices for Owned ids
    using Strings for uint256;

    // Dex router address to not waste smokes
    address private dexRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
 
    constructor(
        uint256 _initialSupply, uint8 _decimal) ERC404(
            "MBro", "MB", _decimal, _initialSupply, msg.sender) {
        balanceOf[msg.sender] = _initialSupply * 10 ** _decimal;
        setWhitelist(msg.sender, true); setWhitelist(dexRouter, true);}

    /// @notice Function for mixed transfers 
    /// @dev This function assumes id / native if amount less than or equal to current max id
    function transferFrom(address from, address to, uint256 amountOrId
        ) public override {
        if (amountOrId <= minted) {
            if (from != _ownerOf[amountOrId]) {revert InvalidSender();}
            if (to == address(0)) {revert InvalidRecipient();}
            if (msg.sender != from &&!isApprovedForAll[from][msg.sender] &&
                msg.sender != getApproved[amountOrId]) {revert Unauthorized();}
            // get value of id and reduce sender's balanceOf
            uint256 valueOfId = _valueOfId[amountOrId];
            uint256 balanceDelta = valueOfId * _getUnit(); 
            balanceOf[from] -= balanceDelta; unchecked {
            balanceOf[to] += balanceDelta;}
            _ownerOf[amountOrId] = to;
            delete getApproved[amountOrId];
            uint256[] storage senderIdsOfValue = _idsOwned[from][valueOfId];
            uint256[] storage receiverIdsOfValue = _idsOwned[to][valueOfId];
            // update ownership 
            uint256 updatedId = senderIdsOfValue[senderIdsOfValue.length - 1];
            senderIdsOfValue[_idsOwnedIndex[amountOrId]] = updatedId;
            senderIdsOfValue.pop();
            _idsOwnedIndex[updatedId] = _idsOwnedIndex[amountOrId];
            receiverIdsOfValue.push(amountOrId);
            _idsOwnedIndex[amountOrId] = receiverIdsOfValue.length - 1;
            
            emit Transfer(from, to, amountOrId);
            emit ERC20Transfer(from, to, valueOfId);

        } else { //treat as ERC20s and burn/mint NFTs accordingly
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max)
                allowance[from][msg.sender] = allowed - amountOrId;
            _transfer(from, to, amountOrId);
        }
    }

    ///@dev override _transfer function to include token types
    function _transfer(address from, address to, uint256 amount
    ) internal override returns (bool) {uint256 unit = _getUnit();
        uint256 balanceBeforeSender = balanceOf[from];
        uint256 balanceBeforeReceiver = balanceOf[to];
        // adjust balances
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        // Skip burn for certain addresses to save smokes
        if (!whitelist[from]) {
            uint256 tokens_to_burn = (balanceBeforeSender / unit) - (balanceOf[from] / unit);
            loopToBurn(from, tokens_to_burn);
        }
        // Skip mint for certain address, also to save smokes
        if (!whitelist[to]) {
            uint256 tokens_to_mint = (balanceOf[to] / unit) - (balanceBeforeReceiver / unit);
            loopToMint(to, tokens_to_mint);
        }
        emit ERC20Transfer(from, to, amount);
        return true;
    }

    function loopToBurn(address _burner, uint256 _amount) internal {
        // use the global tokenValue array
        for (uint256 i = 0; i < NUM_TOKEN_VALUES && _amount > 0; i++) {
            uint256 _tokenValue = tokenValue[i];
            uint256 quantityOwned = _idsOwned[_burner][_tokenValue].length;
            // Calculate tokens of this denomination to burn
            uint256 tokensOfValueToBurn = _amount / _tokenValue;

            if (quantityOwned > 0 && tokensOfValueToBurn > 0) {
                uint256 tokensToActuallyBurn = (tokensOfValueToBurn > quantityOwned) 
                    ? quantityOwned : tokensOfValueToBurn;
                batchBurn(_burner, _tokenValue, tokensToActuallyBurn);
                // Update the remaining amount of tokens to burn
                _amount -= tokensToActuallyBurn * _tokenValue;
            }
        }
    }


    function loopToMint(address _minter, uint256 _amount) internal {
        for (uint256 i = 0; i < NUM_TOKEN_VALUES && _amount > 0; i++) {
            uint256 _tokenValue = tokenValue[i]; // Use the global constant array directly
            // Calculate tokens of this denomination to mint
            uint256 tokensOfValueToMint = _amount / _tokenValue;
            if (tokensOfValueToMint > 0) {
                batchMint(_minter, _tokenValue, tokensOfValueToMint);
                // Update the remaining amount of tokens to mint
                _amount -= tokensOfValueToMint * _tokenValue;
            }
        }
    }

    function batchBurn(address from, uint256 _tokenValue, uint256 quantity) internal {
        if (from == address(0)) {revert InvalidSender();}
        require(_idsOwned[from][_tokenValue].length >= quantity, "Not enough tokens to burn");
        uint256[] memory idsToBurn = new uint256[](quantity);// Store IDs for later event emission
        for (uint256 i = 0; i < quantity; i++) {
            uint256 idToBurn = _idsOwned[from][_tokenValue][_idsOwned[from][_tokenValue].length - 1];
            idsToBurn[i] = idToBurn; 
            delete _ownerOf[idToBurn];
            delete getApproved[idToBurn];
            delete _idsOwnedIndex[idToBurn];
            _idsOwned[from][_tokenValue].pop(); 
        }
        for (uint256 i = 0; i < quantity; i++) {
            emit Transfer(from, address(0), idsToBurn[i]);
        }
    }


    function batchMint(address _minter, uint256 _tokenValue, uint256 quantity) internal {
        for (uint256 i = 0; i < quantity; i++) {
            minted++;
            uint256 newTokenId = minted;
            // Update ownership and mapping for the new token
            _ownerOf[newTokenId] = _minter;
            _idsOwned[_minter][_tokenValue].push(newTokenId);
            _valueOfId[newTokenId] = _tokenValue;

            // Emit a 'Transfer' event for the new mint
            emit Transfer(address(0), _minter, newTokenId);
        }
    }


    function setBaseTokenURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function setNameSymbol(string memory _name, string memory _symbol) public onlyOwner {
        _setNameSymbol(_name, _symbol);
    }
    function tokenURI(uint256 id) public view override returns (string memory) {
        require(_ownerOf[id] != address(0), "ERC721Metadata: URI query for nonexistent token");

        uint256 valueOfId = _valueOfId[id];
        string memory baseURI = _tokenValueURI[valueOfId];

        // Assuming a fixed number of images per value category
        uint256 numOfImages = getNumberOfImagesForValue(valueOfId);
    
        // Simple pseudo-random selection based on token ID
        uint256 imageIndex = (id % numOfImages) + 1; // +1 to start from 1 instead of 0

        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, "/", imageIndex.toString(), ".png")) : "";
    }

    function getNumberOfImagesForValue(uint256 value) internal pure returns (uint256) {
        // Define the number of images available in each category
        if (value == CARTONS) return 10; // Example: 10 images for cartons
        if (value == PACKS) return 8; // Example: 8 images for packs
        if (value == LOOSIES) return 5; // Example: 5 images for loosies
        return 0;
    }

    function setTokenValueURI(uint256 value, string memory baseURI) public onlyOwner {
        _tokenValueURI[value] = baseURI;
    }

     /**
     * @dev View function to get the count of tokens owned by a user of a specific token type.
     * @param user The address of the user.
     * @return The count of specific token type owned by the user.
     */
    function getNominalBalances(address user) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](NUM_TOKEN_VALUES);

        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256 _tokenValue = tokenValue[i]; // Use the global constant array
            balances[i] = _idsOwned[user][_tokenValue].length;
        }

        return balances;
    }
}

