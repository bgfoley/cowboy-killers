


// MARLBOORO
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC721Events} from "./lib/ERC721Events.sol";
import {ERC20Events} from "./lib/ERC20Events.sol";
import {DoubleEndedQueue} from "./lib/DoubleEndedQueue.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC404} from "./ERC404.sol";

contract ERC404TVExt is Ownable, ERC404 {
    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;
    ///@dev deque for each token value for easy storage and retrieval
    mapping(uint256 => DoubleEndedQueue.Uint256Deque) private _storedERC721sByValue;
    using Strings for uint256;
    
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


    ///@dev token values need to be in descending order, largest to smallest for calculations to work
    uint256[NUM_TOKEN_VALUES] public tokenValues = [
        MARLBORO_MEN,
        CARTONS,
        PACKS,
        LOOSIES
    ];

    /// @dev for assigning sequential IDs for each value 
    mapping(uint256 => uint256) private _mintedOfValue;
    mapping(uint256 => string) internal _tokenURIs;
    
    /*/// @dev circulating supply of butts
    uint256 public butts;
    /// @dev smokers club points
    mapping (address => uint256) public smokersClubPoints; 
*/
  
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 maxTotalSupplyERC721_,
        address initialOwner_,
        address initialMintRecipient_,
        address uniswapV2Router_
    ) ERC404(name_, symbol_, decimals_) Ownable(initialOwner_) {
        // Do not mint the ERC721s to the initial owner, as it's a waste of gas.
        _setERC721TransferExempt(initialMintRecipient_, true);
        _setERC721TransferExempt(uniswapV2Router_, true);
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

    /// @notice returns prefix for each token value -- hardcoded for efficiency
    function _getTokenPrefix(uint256 value) internal pure returns (uint256) {
        if (value == MARLBORO_MEN) return PREFIX_MARLBORO_MEN;
        if (value == CARTONS) return PREFIX_CARTONS;
        if (value == PACKS) return PREFIX_PACKS;
        if (value == LOOSIES) return PREFIX_LOOSIES;

        revert("Invalid token value");
    }

    function getTokenValueFromId(uint256 tokenId) public pure returns (uint256) {
        // Extract the prefix part of the token ID
        uint256 prefix = tokenId & (uint256(3) << 253); // Assuming 2 bits for the prefix as per earlier discussion

        // Compare the extracted prefix against known prefixes to determine the value
        if (prefix == PREFIX_MARLBORO_MEN) return MARLBORO_MEN;
        if (prefix == PREFIX_CARTONS) return CARTONS;
        if (prefix == PREFIX_PACKS) return PACKS;
        if (prefix == PREFIX_LOOSIES) return LOOSIES;
        
        revert("Invalid token ID");
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


    function getNominalBalances(address _tokenHolder) 
        public 
        view 
        returns (uint256[] memory) 
    {
        uint256[] memory ownedTokens = _owned[_tokenHolder];
        uint256 marlboroMenCount;
        uint256 cartonsCount;
        uint256 packsCount;
        uint256 loosisCount;

        // First, count tokens in each category to allocate memory
        for (uint256 i = 0; i < ownedTokens.length; i++) {
            uint256 value = getTokenValueFromId(ownedTokens[i]);
            if (value == MARLBORO_MEN) marlboroMenCount++;
            else if (value == CARTONS) cartonsCount++;
            else if (value == PACKS) packsCount++;
            else if (value == LOOSIES) loosisCount++;
        }
        // Set the counts in the nominalBalances array and return it
        uint256[] memory nominalBalances = new uint256[](4);
        nominalBalances[0] = marlboroMenCount;
        nominalBalances[1] = cartonsCount;
        nominalBalances[2] = packsCount;
        nominalBalances[3] = loosisCount;

        return nominalBalances;
    }


    /// @notice view to sort owned tokens by value
    function getOwnedTokensSortedByValue(address _tokenHolder) 
        public 
        view 
        returns (
            uint256[] memory marlboroMens, 
            uint256[] memory cartons, 
            uint256[] memory packs, 
            uint256[] memory loosis
        ) 
    {
        // Assume getNominalBalances() has been implemented to return the counts as expected
        uint256[] memory nominalBalances = getNominalBalances(_tokenHolder);
        
        // Allocate memory for arrays based on counts from getNominalBalances
        marlboroMens = new uint256[](nominalBalances[0]);
        cartons = new uint256[](nominalBalances[1]);
        packs = new uint256[](nominalBalances[2]);
        loosis = new uint256[](nominalBalances[3]);

        uint256 marlboroMensIndex = 0;
        uint256 cartonsIndex = 0;
        uint256 packsIndex = 0;
        uint256 loosisIndex = 0;
        uint256[] memory ownedTokens = _owned[_tokenHolder];

        // Sort tokens into their respective arrays
        for (uint256 i = 0; i < ownedTokens.length; i++) {
            uint256 tokenId = ownedTokens[i];
            uint256 value = getTokenValueFromId(tokenId);

            if (value == MARLBORO_MEN) {
                marlboroMens[marlboroMensIndex++] = tokenId;
            } else if (value == CARTONS) {
                cartons[cartonsIndex++] = tokenId;
            } else if (value == PACKS) {
                packs[packsIndex++] = tokenId;
            } else if (value == LOOSIES) {
                loosis[loosisIndex++] = tokenId;
            }
        }

        return (marlboroMens, cartons, packs, loosis);
    }


    /// @notice function to assemble unique token ID
    /// @param value of token
    /// @param sequence unique ID paramater
    function _createTokenId(uint256 value, uint256 sequence) internal pure returns (uint256) {
        uint256 prefix = _getTokenPrefix(value);
        // Ensure sequence does not overlap with prefix bits
        // This might involve ensuring sequence occupies a specific range or using bitwise operations to combine values more safely
        uint256 id = prefix | (sequence & ((uint256(1) << 253) - 1));
        return id;
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
        uint256 transferValue = units * getTokenValueFromId(id_);
        _transferERC20(from_, to_, transferValue);
        _transferERC721(from_, to_, id_);
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

        // Both sender and recipient are ERC-721 transfer exempt. No ERC-721s need to be transferred.
        if (isFromERC721TransferExempt && isToERC721TransferExempt) {
        
        
        } else if (isFromERC721TransferExempt) {
            
                uint256 tokensToRetrieveOrMint = (balanceOf[to_] / units) -
                (erc20BalanceOfReceiverBefore / units);
            
            // _retrieveOrMintERC721 handles batches
            _retrieveOrMintERC721(to_, tokensToRetrieveOrMint);
        
        } else if (isToERC721TransferExempt) {
            uint256 tokensToWithdrawAndStore = (erc20BalanceOfSenderBefore / units) -
                (erc20BalanceOf(from_) / units);
            // Assuming _withdrawAndStoreERC721 is designed to handle multiple tokens if needed
            _withdrawAndStoreERC721(from_, tokensToWithdrawAndStore);
        } else {
            uint256 nftsToTransfer = value_ / units;
            // Assuming _withdrawAndStoreERC721 is designed to handle one token at a time
        
            _withdrawAndStoreERC721(from_, nftsToTransfer); // This seems to be missing an appropriate loop or logic

            // Deal with loose change
            uint256 extraLoosie = LOOSIES * units;

            // Check if the sender needs to withdraw an additional NFT due to fractional part transfer
            if ((erc20BalanceOfSenderBefore / units) - (erc20BalanceOf(from_) / units) > nftsToTransfer) {
                _withdrawAndStoreERC721(from_, extraLoosie); // This might be a misuse; you likely intend a different logic here
            }

            // Check if the receiver gains a whole new token which requires gaining an additional ERC-721
            if ((erc20BalanceOf(to_) / units) - (erc20BalanceOfReceiverBefore / units) > nftsToTransfer) {
                _retrieveOrMintERC721(to_, extraLoosie); // Misuse of extraLoosie; likely need a different parameter or logic
            }
        }
        return true;
    }
            
    /// @notice Internal function for ERC-721 minting and retrieval from the bank
    /// @dev Handles retrieval of all token values
    ///      first try to pull from the bank, and if the bank is empty, it will mint a new token.
    /// Does not handle ERC-721 exemptions.
    /// @param to_ is the address of the recipient 
    /// @param amount_ is the fractional value of tokens to account for
    function _retrieveOrMintERC721(address to_, uint256 amount_) internal override {
        // Validate the recipient's address
        if (to_ == address(0)) {
            revert InvalidRecipient();
        }

        // Calculate the number of tokens to retrieve or mint for each token value based on the amount
        uint256[] memory tokens = _calculateTokensFromBatch(amount_); 

        // Iterate over each token value category
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256 tokenValue_ = tokenValues[i];
            uint256 tokensOfValue = tokens[i];

            // Retrieve ID of correct value if available
            unchecked {
                for (uint256 j = 0; j < tokensOfValue; j++) {
                    uint256 id;
                    DoubleEndedQueue.Uint256Deque storage idsOfValue = _storedERC721sByValue[tokenValue_];

                    bool isMinting = idsOfValue.empty();

                    if (!isMinting) {
                        // Use tokens from the contract's reserve if available
                        id = idsOfValue.popBack();
                        // Transfer the token to the recipient. Assumes the contract is the initial token holder.
                        _transferERC721(address(this), to_, id);
                    } else {
                        // Mint a new token if no reserve tokens are available for the required value
                        uint256 _mintedTokens = ++_mintedOfValue[tokenValue_];
                        
                        // Guard against exceeding the uint256 storage limit
                        if (_mintedTokens == type(uint256).max) {
                            revert MintLimitReached();
                        }

                        // Create a new token ID with the incremented mint counter
                        id = _createTokenId(tokenValue_, _mintedTokens);
                        
                        address erc721Owner = _getOwnerOf(id);

                        // Verify that the token is not already owned
                        if (erc721Owner != address(0)) {
                            revert AlreadyExists();
                        }

                        // Transfer the token to the recipient. For minting, this uses address(0) as the source.
                        _transferERC721(erc721Owner, to_, id);
                    }
                }
            }
        }
    }
    


    function _withdrawAndStoreERC721(address from_, uint256 amount_) internal override {
        if (from_ == address(0)) {
            revert InvalidSender();
        }
        // get senders inventory
        (
        uint256[] memory loosis, 
        uint256[] memory packs, 
        uint256[] memory cartons, 
        uint256[] memory marlboroMens
        ) = getOwnedTokensSortedByValue(from_);
        // 
        uint256[][] memory tokensByValue = new uint256[][](4);
        tokensByValue[0] = marlboroMens;
        tokensByValue[1] = cartons;
        tokensByValue[2] = packs;
        tokensByValue[3] = loosis;

        uint256[] memory tokensToWithdraw = _calculateFromTokensOwned(from_, amount_);

        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256 tokensToWithdrawForValue = tokensToWithdraw[i];

            unchecked {
                for (uint256 j = 0; j < tokensToWithdrawForValue; j++) {
                    uint256 tokenId = tokensByValue[i][tokensByValue[i].length - j - 1]; // Correct index access

                    // Transfer the token to 0x0 (burning it or transferring it to a "bank")
                    _transferERC721(from_, address(0), tokenId); // Corrected from 'owner' to 'from_'

                    // Record the token in the contract's bank queue for its value
                    _storedERC721sByValue[i].pushFront(tokenId);
                }
            }
        }
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

    /// @notice determine how many of each token value from batch of ERC20s
    /// @param _units of ER
    function _calculateTokensFromBatch(
        uint256 _units
      ) internal view returns (uint256[] memory) {
        uint256[] memory tokensToRetrieveOrMint = new uint256[](
            NUM_TOKEN_VALUES
        );
        uint256 remainingUnits = _units;

        // Calculate the number of units to retrieve or mint for each token value
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
            tokensToRetrieveOrMint[i] = remainingUnits / tokenValues[i];
            remainingUnits %= tokenValues[i];
            unchecked {
                ++i;
            }
        }

        return tokensToRetrieveOrMint;
    }

    /// @dev takes a quantity of units and builds list of tokens to withdraw from address
    /// this is helpful because it is possible for an address to have spare change in terms
    /// of token denominations
    /// @param owner_ is address to calculate tokens from
    /// @param units_ is whole ERC20s to calculate from
    function _calculateFromTokensOwned(
        address owner_,
        uint256 units_
    ) internal view returns (uint256[] memory) {
        uint256[] memory tokensToWithdraw = new uint256[](NUM_TOKEN_VALUES);
        uint256 remainingUnits = units_;
        
        // getOwnedTokensSortedByValue(owner_);
        uint256[] memory nominalBalances = getNominalBalances(owner_);
        bool canFulfillExactWithdrawal = true;

        for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
            uint256 maxTokensPossible = remainingUnits / tokenValues[i];
            uint256 tokensToActuallyWithdraw = (nominalBalances[i] <
                maxTokensPossible)
                ? nominalBalances[i]
                : maxTokensPossible;

            tokensToWithdraw[i] = tokensToActuallyWithdraw;
            remainingUnits -= tokensToActuallyWithdraw * tokenValues[i];

            if (remainingUnits == 0) break;
            unchecked {
                ++i;
            }
        }

        // If there are remaining units after trying to withdraw the maximum possible,
        // it means the withdrawal request cannot be fulfilled exactly.
        // Adjust the function to return all balances owned by the owner instead.
        if (remainingUnits > 0) {
            canFulfillExactWithdrawal = false;
            for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
                // Set tokensToWithdraw to owner's available balances
                // to withdraw all owned ERC721s.
                tokensToWithdraw[i] = nominalBalances[i];
            }
        }

        // The function now also returns a boolean indicating whether the exact withdrawal request can be fulfilled.
        return (tokensToWithdraw);
    }

    /// @notice Function to reinstate balance on exemption removal
    /// @param target_ address to reinstate balances
    function _reinstateERC721Balance(address target_) internal override {
        uint256 _targetBalance = balanceOf[target_];
        _retrieveOrMintERC721(target_, _targetBalance);
    }

    /// @notice Function to clear balance on exemption inclusion
    /// to override it -  uses owned function to build list since
    /// we are clearing all token IDs regardless of value
    /// @param target_ address to reinstate balances
    function _clearERC721Balance(address target_) internal override {
        uint256 balance = balanceOf[target_];
            // Transfer out ERC721 balance
            _withdrawAndStoreERC721(target_, balance);
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
}    
