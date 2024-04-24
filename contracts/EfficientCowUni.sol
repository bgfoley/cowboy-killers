// MARLBORO
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DoubleEndedQueue} from "./lib/DoubleEndedQueue.sol";
import {ERC404} from "./ERC404.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ERC721Events} from "./lib/ERC721Events.sol";
import {ERC20Events} from "./lib/ERC20Events.sol";


contract ERC404TVUNI is Ownable, ERC404 {
    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;
    ///@dev deque for each token value for easy storage and retrieval
    mapping(uint256 => DoubleEndedQueue.Uint256Deque) private _storedERC721sByValue;
    using Strings for uint256;
    
    /// @dev for assigning sequential IDs for each value 
    mapping(uint256 => uint256) private _mintedOfValue;
    mapping(uint256 => string) internal _tokenURIs;
    
    ///@dev set token values constant for efficiency
    uint256 private constant MARLBORO_MEN = 600;
    uint256 private constant CARTONS = 200;
    uint256 private constant PACKS = 20;
    uint256 private constant LOOSIES = 1;
    uint256 private constant NUM_TOKEN_VALUES = 4;

    /// @dev prefixes for different token values 
    uint256 private constant PREFIX_MARLBORO_MEN = (1 << 255) | (0 << 253);
    uint256 private constant PREFIX_CARTONS = (1 << 255) | (1 << 253);
    uint256 private constant PREFIX_PACKS = (1 << 255) | (2 << 253);
    uint256 private constant PREFIX_LOOSIES = (1 << 255) | (3 << 253);

    /// @notice tokenValues is an index of token values
    /// @dev token value index needs to be in descending order, largest to smallest for calculations to work
    uint256[NUM_TOKEN_VALUES] public tokenValues = [
        MARLBORO_MEN,
        CARTONS,
        PACKS,
        LOOSIES
    ];
    
  
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 maxTotalSupplyERC721_,
        address initialOwner_,
        address initialMintRecipient_,
        address uniswapV2Router_
    ) ERC404(name_, symbol_, decimals_) Ownable(initialOwner_) {
         IUniswapV2Router02 uniswapV2RouterContract = IUniswapV2Router02(
            uniswapV2Router_
        );

        
        // Do not mint the ERC721s to the initial owner, as it's a waste of gas.
        _setERC721TransferExempt(initialMintRecipient_, true);
        _setERC721TransferExempt(uniswapV2Router_, true);
          // Determine the Uniswap v2 pair address for this token.
   //     address uniswapV2Pair = _getUniswapV2Pair(
   //         uniswapV2RouterContract.factory(),
   //         uniswapV2RouterContract.WETH()
      //  );

        // Set the Uniswap v2 pair as exempt.
       // _setERC721TransferExempt(uniswapV2Pair, true);

        _mintERC20(initialMintRecipient_, maxTotalSupplyERC721_ * units);
    }


    function erc721TotalSupply() public view override returns (uint256) {
        uint256 erc721Supply = 0;
        unchecked {
            for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
                erc721Supply += _mintedOfValue[tokenValues[i]];
            }
        }
        return erc721Supply;
    }


     function getBalanceOfTokenValue(address tokenHolder_, uint256 tokenValue_) 
        public 
        view 
        returns (uint256) 
    {
        uint256[] memory ownedTokens = _owned[tokenHolder_];
        uint256 tokenCount = 0;

        // Count tokens of the specified value
        for (uint256 i = 0; i < ownedTokens.length; i++) {
            if (getTokenValueFromId(ownedTokens[i]) == tokenValue_) {
                tokenCount++;
            }
        }

        return tokenCount;
    }



    function getNominalBalances(address tokenHolder_) 
        public 
        view 
        returns (uint256[] memory) 
    {
        uint256[] memory ownedTokens = _owned[tokenHolder_];
        uint256 marlboroManCount;
        uint256 cartonCount;
        uint256 packCount;
        uint256 loosieCount;

        // First, count tokens in each category to allocate memory
        for (uint256 i = 0; i < ownedTokens.length; i++) {
            uint256 value = getTokenValueFromId(ownedTokens[i]);
            if (value == MARLBORO_MEN) marlboroManCount++;
            else if (value == CARTONS) cartonCount++;
            else if (value == PACKS) packCount++;
            else if (value == LOOSIES) loosieCount++;
        }
        // Set the counts in the nominalBalances array and return it
        uint256[] memory nominalBalances = new uint256[](4);
        nominalBalances[0] = marlboroManCount;
        nominalBalances[1] = cartonCount;
        nominalBalances[2] = packCount;
        nominalBalances[3] = loosieCount;

        return nominalBalances;
    }

 
    
    function getOwnedTokensOfValue(
        address tokenHolder_, 
        uint256 tokenValue_ // This is now an index referring to the position in the tokenValues array
      ) public view returns (uint256[] memory tokensOfCategory) {

        uint256 count = 0;
        uint256[] memory ownedTokens = _owned[tokenHolder_];
        // First, count the tokens of the specified category to allocate memory efficiently
        for (uint256 i = 0; i < ownedTokens.length; i++) {
            if (getTokenValueFromId(ownedTokens[i]) == tokenValue_) {
                count++;
            }
        }

        // Allocate memory for the array
        tokensOfCategory = new uint256[](count);

        // Fill the array
        uint256 index = 0;
        for (uint256 i = 0; i < ownedTokens.length; i++) {
            uint256 tokenId = ownedTokens[i];
            if (getTokenValueFromId(tokenId) == tokenValue_) {
                tokensOfCategory[index++] = tokenId;
            }
        }

        return tokensOfCategory;
    }



    /// @notice view to sort owned tokens by value
    function getAllOwnedTokensSorted(address tokenHolder_) 
        public 
        view 
        returns (
            uint256[] memory marlboroMen, 
            uint256[] memory cartons, 
            uint256[] memory packs, 
            uint256[] memory loosies
        ) 
      {
        // Assume getNominalBalances() has been implemented to return the counts as expected
        uint256[] memory nominalBalances = getNominalBalances(tokenHolder_);
        
        // Allocate memory for arrays based on counts from getNominalBalances
        marlboroMen = new uint256[](nominalBalances[0]);
        cartons = new uint256[](nominalBalances[1]);
        packs = new uint256[](nominalBalances[2]);
        loosies = new uint256[](nominalBalances[3]);

        uint256 marlboroManIndex = 0;
        uint256 cartonIndex = 0;
        uint256 packIndex = 0;
        uint256 loosieIndex = 0;
        uint256[] memory ownedTokens = _owned[tokenHolder_];

        // Sort tokens into their respective arrays
        for (uint256 i = 0; i < ownedTokens.length; i++) {
            uint256 tokenId = ownedTokens[i];
            uint256 value = getTokenValueFromId(tokenId);

            if (value == MARLBORO_MEN) {
                marlboroMen[marlboroManIndex++] = tokenId;
            } else if (value == CARTONS) {
                cartons[cartonIndex++] = tokenId;
            } else if (value == PACKS) {
                packs[packIndex++] = tokenId;
            } else if (value == LOOSIES) {
                loosies[loosieIndex++] = tokenId;
            }
        }

        return (marlboroMen, cartons, packs, loosies);
    }

   
    function getTokenValueFromId(uint256 tokenId) public pure returns (uint256) {
        // Extract the prefix part of the token ID
        uint256 prefix = tokenId & (uint256(7) << 253); // Use 7 (111 in binary) to include the top three bits


        // Compare the extracted prefix against known prefixes to determine the value
        if (prefix == PREFIX_MARLBORO_MEN) return MARLBORO_MEN;
        if (prefix == PREFIX_CARTONS) return CARTONS;
        if (prefix == PREFIX_PACKS) return PACKS;
        if (prefix == PREFIX_LOOSIES) return LOOSIES;
        
        revert("Invalid token ID");
    }



    /// @notice how many ERC721 of given value stored in the queue
    /// @param value of tokens in queue
    function getERC721QueueLengthByValue(
        uint256 value
    ) public view returns (uint256) {
        DoubleEndedQueue.Uint256Deque storage deque = _storedERC721sByValue[
            value
        ];
        return deque.length();
    }

    /// @notice total ERC721s in the queue
    function getERC721QueueLength()
        public
        view
        override
        returns (uint256 totalLength)
    {
        totalLength = 0;
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256 tokenValue = tokenValues[i];
            DoubleEndedQueue.Uint256Deque storage deque = _storedERC721sByValue[
                tokenValue
            ];
            // Sum the lengths
            unchecked {
                totalLength += deque.length();
            }
        }
    }

    /// @notice gets the number of tokens in the queue by value and index
    function getERC721TokensInQueueByValue(
        uint256 tokenValue_,
        uint256 start_,
        uint256 count_
    ) public view returns (uint256[] memory) {
        uint256[] memory tokensInQueue = new uint256[](count_);

        for (uint256 i = start_; i < start_ + count_; ) {
            tokensInQueue[i - start_] = (_storedERC721sByValue[tokenValue_]).at(
                i
            );

            unchecked {
                ++i;
            }
        }

        return tokensInQueue;
    }


    
    function tokenURI(uint256 id_) public view override returns (string memory) {
        // Decode the token value from the ID
        uint256 valueOfId;
        valueOfId = getTokenValueFromId(id_);

        // Base URI for metadata
        string memory baseURI;

        // Determine the appropriate directory based on the token value
        if (valueOfId == LOOSIES) {
            baseURI = "https://example.com/loosies/";
        } else if (valueOfId == PACKS) {
            baseURI = "https://example.com/packs/";
        } else if (valueOfId == CARTONS) {
            baseURI = "https://example.com/cartons/";
        } else if (valueOfId == MARLBORO_MEN) {
            baseURI = "https://example.com/marlboro_men/";
        } else {
            revert("Invalid token value");
        }

        // Construct the full URI for the token's metadata
        string memory fullURI = string(abi.encodePacked(baseURI, Strings.toString(id_), ".json"));

        return fullURI;
    }


    /// @notice Function for self-exemption
    function setSelfERC721TransferExempt(bool state_) public override {
        _setERC721TransferExempt(msg.sender, state_);
    }

    /// @notice External, onlyOwner Function to set a dex address ERC721 transfer exempt
    function setERC721TransferExempt(
        address account_,
        bool value_
      ) external onlyOwner {
        _setERC721TransferExempt(account_, value_);
    }

    /// @notice Function for ERC-721 transfers from. 
    /// @dev This function is recommended for ERC721 transfers.
    /// Override accounts for token value for update ERC20 ballance
    function erc721TransferFrom(
        address from_,
        address to_,
        uint256 id_
    ) public override {
        // Prevent minting tokens from 0x0.
        if (from_ == address(0)) {
            revert InvalidSender();
        }

        // Prevent burning tokens to 0x0.
        if (to_ == address(0)) {
            revert InvalidRecipient();
        }

        if (from_ != _getOwnerOf(id_)) {
            revert Unauthorized();
        }

        // Check that the operator is either the sender or approved for the transfer.
        if (
            msg.sender != from_ &&
            !isApprovedForAll[from_][msg.sender] &&
            msg.sender != getApproved[id_]
        ) {
            revert Unauthorized();
        }

        // We only need to check ERC-721 transfer exempt status for the recipient
        // since the sender being ERC-721 transfer exempt means they have already
        // had their ERC-721s stripped away during the rebalancing process.
        if (erc721TransferExempt(to_)) {
            revert RecipientIsERC721TransferExempt();
        }

        // Transfer 1 * units * value ERC-20 and 1 ERC-721 token.
        // ERC-721 transfer exemptions handled above. Can't make it to this point if either is transfer exempt.
        uint256 erc20Value = units * getTokenValueFromId(id_);
        _transferERC20(from_, to_, erc20Value);
        _transferERC721(from_, to_, id_);
    }
    
    
    /// @notice Initialization function to set pairs / etc, saving gas by avoiding mint / burn on unnecessary targets
    function _setERC721TransferExempt(
        address target_,
        bool state_
    ) internal override {
        if (target_ == address(0)) {
            revert InvalidExemption();
        }

        // Adjust the ERC721 balances of the target to respect exemption rules.
        // Despite this logic, it is still recommended practice to exempt prior to the target
        // having an active balance.
        if (state_) {
            _clearERC721Balance(target_);
        } else {
            _reinstateERC721Balance(target_);
        }

        _erc721TransferExempt[target_] = state_;
    }

    // Removed this function due to overcomplication with expectedERC721 Balance
    /// @notice Function to reinstate balance on exemption removal
    function _reinstateERC721Balance(address target_) internal override {
        uint256 erc20Balance = erc20BalanceOf(target_) / units;
        
        uint256[] memory expectedERC721Balances = calculateTokens(erc20Balance);
        uint256[] memory actualERC721Balances = getNominalBalances(target_);
    

        for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
            uint256 expectedBalance = expectedERC721Balances[i];
            uint256 actualERC721Balance = actualERC721Balances[i];
            uint256 tokensToRetrieveOrMint = expectedBalance - actualERC721Balance;

            for (uint256 j = 0; j < tokensToRetrieveOrMint; ) {
            
                // Transfer ERC721 balance in from pool
                _retrieveOrMintERC721(target_);
                    unchecked {
                        ++j;
                    }
                }
            unchecked {
                ++i;
            }    
        }
    }



    
    function _transferERC20WithERC721(
        address from_,
        address to_,
        uint256 value_
    ) internal override returns (bool) {
        uint256 erc20BalanceOfSenderBefore = erc20BalanceOf(from_);
        uint256 erc20BalanceOfReceiverBefore = erc20BalanceOf(to_);

        _transferERC20(from_, to_, value_);

        // Preload for gas savings on branches
        bool isFromERC721TransferExempt = erc721TransferExempt(from_);
        bool isToERC721TransferExempt = erc721TransferExempt(to_);

        // Case 1) Both sender and recipient are ERC-721 transfer exempt. No ERC-721s need to be transferred.
        if (isFromERC721TransferExempt && isToERC721TransferExempt) {
        
        // Case 2) Sender is ERC721 transfer exempt, but recipient is not. Use retrieveOrMintBatch 
        } else if (isFromERC721TransferExempt) {
            
                uint256 tokensToRetrieveOrMint = (balanceOf[to_] / units) -
                (erc20BalanceOfReceiverBefore / units);
            // Handles batch of ERC721s
            _retrieveOrMintBatch(to_, tokensToRetrieveOrMint);
        
        // Case 3) Recipient is ERC721 transfer exempt, but sender is not. Use loopTowithDrawAndStoreBatch
        } else if (isToERC721TransferExempt) {
            uint256 tokensToWithdrawAndStore = (erc20BalanceOfSenderBefore / units) -
                (erc20BalanceOf(from_) / units);
            
            // Use the greedy algo logic to loop the values from greatest to least
            // Mixed purpose function, use zero address as placeholder for to_
            // Set bool isTransfer to false
            _batchTransferOrWithdrawAndStoreERC721(from_, address(0), tokensToWithdrawAndStore, false);
        } else {
            
            // Case 4) niether are ERC721 exempt 
            uint256 unitsToTransfer = value_ / units;
            // Set bool isTransfer true
            _batchTransferOrWithdrawAndStoreERC721(from_, to_, unitsToTransfer, true);
            
            // If the transfer changes either the sender or the recipient's holdings from a fractional to a non-fractional
            // amount (or vice versa), adjust ERC-721s.

            // First check if the send causes the sender to lose a whole token that was represented by an ERC-721
            // due to a fractional part being transferred.
            //
            // Process:
            // Take the difference between the whole number of tokens before and after the transfer for the sender.
            // If that difference is greater than the number of ERC-721s transferred (whole units), then there was
            // an additional ERC-721 lost due to the fractional portion of the transfer.
            // If this is a self-send and the before and after balances are equal (not always the case but often),
            // then no ERC-721s will be lost here.

            if (
                erc20BalanceOfSenderBefore /
                    units -
                    erc20BalanceOf(from_) /
                    units >
                unitsToTransfer
            ) {
                
                _withdrawAndStoreERC721(from_, LOOSIES);
            }

            // Then, check if the transfer causes the receiver to gain a whole new token which requires gaining
            // an additional ERC-721.
            //
            // Process:
            // Take the difference between the whole number of tokens before and after the transfer for the recipient.
            // If that difference is greater than the number of ERC-721s transferred (whole units), then there was
            // an additional ERC-721 gained due to the fractional portion of the transfer.
            // Again, for self-sends where the before and after balances are equal, no ERC-721s will be gained here.
            if (
                erc20BalanceOf(to_) /
                    units -
                    erc20BalanceOfReceiverBefore /
                    units >
                unitsToTransfer
            ) {
                _retrieveOrMintERC721(to_, LOOSIES);
            }
        }

        return true;
    }


    /// @notice Function to handle internal logic for bulk transfers of ERC721 tokens that occurs
    /// with transferERC20WithERC721 
    /// @param from_ is sender
    /// @param to_ is receipient. For withdrawAndStore, zero address used as placeholer
    /// @param amountInUnits_ is the native value of the transfer
    function _batchTransferOrWithdrawAndStoreERC721(
        address from_,
        address to_, 
        uint256 amountInUnits_,
        bool isTransfer // true for transfer, false for withdraw and store
      ) internal {


        // At this point sender's erc20 balance has been reduced by the amount of the transfer - 
        // their erc20 balance before transfer will help them retrieve exact change
        uint256 senderNativeBalanceBefore = (balanceOf[from_]) / units + amountInUnits_;
        
        // Counter
        uint256 unitsToTransfer = amountInUnits_;

        // Use greedy algo logic to withdraw token values from greatest > to least
        for (uint256 i = 0; i < NUM_TOKEN_VALUES && unitsToTransfer > 0;) {
            uint256 tokenValue_ = tokenValues[i];

             // Get from_ balance of selected token value
            uint256 balance = getBalanceOfTokenValue(from_, tokenValue_);


            // Check if senders has enough tokens of lesser value to complete transfer. If not, get change.
            if (tokenValue_ >= unitsToTransfer 
                && (senderNativeBalanceBefore - (
                    balance * tokenValue_) < unitsToTransfer)) {

                
                if (isTransfer && tokenValue_ == unitsToTransfer) {
                    // If isTransfer is true and tokenValue equals unitsToTransfer, 
                    
                    // Get token id to transfer
                    uint256[] memory ownedTokens = 
                      getOwnedTokensOfValue(from_, tokenValue_);
                    
                    uint256 id = ownedTokens.length - 1;  
                    
                    // perform a direct transfer of the ERC721 token.
                    _transferERC721(from_, to_, id);

                    // Update remaining units to transfer
                    unitsToTransfer -= tokenValue_;    
                } else {
                    
                    // Otherwise, withdraw ERC721 to the bank and get exact change
                    _withdrawAndStoreERC721(from_, tokenValue_);

                    // Check if there's a non-zero change owed to the sender.
                    // If so, get change. Do not update unitsToTransfer as this will be done 
                    // in subsequent loops with exact change
                    if (tokenValue_ != unitsToTransfer) {
                        uint256 changeOwedToSender = tokenValue_ - unitsToTransfer;
                        _retrieveOrMintBatch(from_, changeOwedToSender);
                   
                    // If no change is needed and no unitsRemaining to transfer, update remainingUnits
                     } else {
                        unitsToTransfer -= tokenValue_;
                     }
                }
            
                 
             } else if (tokenValue_ < unitsToTransfer) {
                
                // Determine how many ERC721 to withdraw
                uint256 tokens = unitsToTransfer / tokenValue_;
                
                // Use the greater of the two values, otherwise will not have enough for transfer
                uint256 tokensToMove = balance >= tokens ? tokens : balance;

                // Transfer tokensToMove one at a time
                for (uint256 j = 0; j < tokensToMove; /* increment inside the loop body */) {
                    if (isTransfer) {
                        // If isTransfer is true, transfer the ERC721 token
                        _transferERC721(from_, to_, tokenValue_);
                    } else {
                        // If isTransfer is false, withdraw and store the ERC721 token
                        _withdrawAndStoreERC721(from_, tokenValue_);
                    }

                    // Increment j inside an unchecked block to avoid overflow checks
                    unchecked {
                        j++;
                    }
                    // Update remaining unitsToTransfer
                    unitsToTransfer -= (tokensToMove * tokenValue_);

                }
            
            }

        unchecked { ++i; }
        }
    }

    function _retrieveOrMintBatch(
            address to_,
            uint256 amountInUnits_
        ) internal {
            uint256[] memory _tokensToRetrieveOrMint = calculateTokens(amountInUnits_);

            // Loop through each token value & check change owed in loop condition
            for (uint256 i = 0; i < NUM_TOKEN_VALUES && amountInUnits_ > 0; ) {
                uint256 _quantity = _tokensToRetrieveOrMint[i];
                uint256 _tokenValue = tokenValues[i]; // Directly use the value from the array

                // If _quantity is zero, no need to call _retrieveOrMintERC721
                if (_quantity > 0) {
                    // Loop '_quantity' times for this token value
                    for (uint256 j = 0; j < _quantity && amountInUnits_ >= _tokenValue; ) {
                        // Call _retrieveOrMintERC721 for each quantity
                        _retrieveOrMintERC721(to_, _tokenValue);
                        // Update change owed
                        amountInUnits_ -= _tokenValue;
                        unchecked { ++j; }
                    }
                }
                unchecked { ++i; }
            }

    }


                
             
    function _retrieveOrMintERC721(address to_, uint256 tokenValue_) internal override {
        if (to_ == address(0)) {
            revert InvalidRecipient();
        }
        uint256 id;

        // Check for tokens in the contract's bank queue.
        DoubleEndedQueue.Uint256Deque
            storage storedERC721sOfValue = _storedERC721sByValue[tokenValue_];
        
        // If tokens available in the bank get Id from there
        if (!storedERC721sOfValue.empty()) {
        
            DoubleEndedQueue.Uint256Deque storage idsOfValue = _storedERC721sByValue[tokenValue_];
            id = idsOfValue.popBack();
        
        
        } else {
            // Mint a new token if no reserves available for the required value
            uint256 _mintedTokens = ++_mintedOfValue[tokenValue_];
            
            // Guard against exceeding the uint256 storage limit
            if (_mintedTokens == type(uint256).max) {
                revert MintLimitReached();
            }

            // Create a new token ID with the incremented mint counter
            id = _generateTokenId(tokenValue_, _mintedTokens);
            
            address erc721Owner = _getOwnerOf(id);

            // Verify that the token is not already owned
            if (erc721Owner != address(0)) {
                revert AlreadyExists();
            }

            // Transfer the token to the recipient. For minting, this uses address(0) as the source.
            _transferERC721(address(0), to_, id);
        }
    }



    function _withdrawAndStoreERC721(address from_, uint256 tokenValue_) internal override {
        if (from_ == address(0)) {
            revert InvalidSender();
        }

        // Get a list of token Ids of the selected value owned by sender 
        uint256[] memory ids = getOwnedTokensOfValue(from_, tokenValue_);

        
        // Retrieve the latest token added to the owner's stack (LIFO).
        uint256 id = ids.length - 1;

        // Transfer to 0x0.
        // Does not handle ERC-721 exemptions.
        _transferERC721(from_, address(0), id);

        // Record the token in the contract's bank queue.
        DoubleEndedQueue.Uint256Deque
            storage storedERC721sOfValue = _storedERC721sByValue[tokenValue_];
        // Record the token in the contract's bank queue.
        storedERC721sOfValue.pushFront(id);
    }

    /// @notice Internal function for ERC-721 deposits to bank (this contract).
    /// @dev This function will allow depositing of ERC-721s to the bank, which can be retrieved by future minters.
    // Does not handle ERC-721 exemptions.
    function _withdrawAndStoreERC721(address from_) internal override {
        if (from_ == address(0)) {
            revert InvalidSender();
        }

        // Retrieve the latest token added to the owner's stack (LIFO).
        uint256 id = _owned[from_][_owned[from_].length - 1];
        uint256 tokenValue_ = getTokenValueFromId(id);

        // Transfer to 0x0.
        // Does not handle ERC-721 exemptions.
        _transferERC721(from_, address(0), id);
        // Record the token in the contract's bank queue.
        DoubleEndedQueue.Uint256Deque
            storage storedERC721sOfValue = _storedERC721sByValue[tokenValue_];
        // Record the token in the contract's bank queue.
        storedERC721sOfValue.pushFront(id);
    }



    /// @dev takes a quantity of units and builds a list of tokens to mint for each value
    /// @param _units are whole ERC20s to calculate from
    function calculateTokens(
        uint256 _units
      ) internal view returns (uint256[] memory) {
        uint256[] memory nftsToRetrieveOrMint = new uint256[](
            NUM_TOKEN_VALUES
        );
        uint256 remainingUnits = _units;

        // Calculate the number of units to retrieve or mint for each token value
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
            nftsToRetrieveOrMint[i] = remainingUnits / tokenValues[i];
            remainingUnits %= tokenValues[i];
            unchecked {
                ++i;
            }
        }

        return nftsToRetrieveOrMint;
    }



    
    /// @notice function to assemble unique token ID
    /// @param value of token
    /// @param sequence unique ID paramater
    function _generateTokenId(uint256 value, uint256 sequence) internal pure returns (uint256) {
        uint256 prefix = _getTokenPrefix(value);
        // Ensure sequence does not overlap with prefix bits
        // This might involve ensuring sequence occupies a specific range or using bitwise operations to combine values more safely
        uint256 id = prefix | (sequence & ((uint256(1) << 253) - 1));
        return id;
    }

    

    function _isValidTokenId(uint256 id_) internal pure override returns (bool) {
        // Extract the prefix part of the token ID
        uint256 prefix = id_ & (uint256(3) << 253);

        // Check if the prefix matches one of the valid prefixes
        bool validPrefix = prefix == PREFIX_MARLBORO_MEN || prefix == PREFIX_CARTONS ||
                        prefix == PREFIX_PACKS || prefix == PREFIX_LOOSIES;

        // Ensure the sequence number is valid (non-zero and within bounds).
        // Assuming the sequence is stored in the lower 253 bits, 
        // it should be non-zero and less than 2^253.
        uint256 sequence = id_ & ((uint256(1) << 253) - 1);
        bool validSequence = sequence > 0 && sequence < (uint256(1) << 253);

        // The ID is valid if both the prefix and sequence number are valid
        return validPrefix && validSequence;
    }

     /// @notice returns prefix for each token value -- hardcoded for efficiency
    function _getTokenPrefix(uint256 value) internal pure returns (uint256) {
        if (value == MARLBORO_MEN) return PREFIX_MARLBORO_MEN;
        if (value == CARTONS) return PREFIX_CARTONS;
        if (value == PACKS) return PREFIX_PACKS;
        if (value == LOOSIES) return PREFIX_LOOSIES;

        revert("Invalid token value");
    }

function _getUniswapV2Pair(
        address uniswapV2Factory_,
        address weth_
    ) private view returns (address) {
        address thisAddress = address(this);

        (address token0, address token1) = thisAddress < weth_
            ? (thisAddress, weth_)
            : (weth_, thisAddress);

        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                hex"ff",
                                uniswapV2Factory_,
                                keccak256(abi.encodePacked(token0, token1)),
                                hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f"
                            )
                        )
                    )
                )
            );
    }

        function mintERC20(address account_, uint256 value_) external onlyOwner {
        _mintERC20(account_, value_);
    }

}

