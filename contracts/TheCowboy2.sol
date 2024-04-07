//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DoubleEndedQueue} from "./lib/DoubleEndedQueue.sol";
import {ERC404} from "./ERC404.sol";
import {ERC721Events} from "./lib/ERC721Events.sol";
import {ERC20Events} from "./lib/ERC20Events.sol";

contract TheCowboy is Ownable, ERC404 {
    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;
    ///@dev deque for each token value for easy storage and retrieval
    mapping(uint256 => DoubleEndedQueue.Uint256Deque)
        private _storedERC721sByValue;
    using Strings for uint256;
    ///@dev set token values constant for efficiency
    uint256 private constant MARLBORO_MEN = 600;
    uint256 private constant CARTONS = 200;
    uint256 private constant PACKS = 20;
    uint256 private constant LOOSIES = 1;
    uint256 private constant NUM_TOKEN_VALUES = 4;

    ///@dev token values need to be in descending order, largest to smallest for calculations to work
    uint256[NUM_TOKEN_VALUES] public tokenValues = [
        MARLBORO_MEN,
        CARTONS,
        PACKS,
        LOOSIES
    ];


    /// @dev use IdsOwned (sorted by value) instead of _owned
    mapping(address => mapping(uint256 => uint256[])) internal _idsOwned;
    /// @dev native value of unique token ID
    mapping(uint256 => uint256) internal _valueOfId;

    mapping(uint256 => string) internal _tokenValueURI;
    mapping(uint256 => string) internal _tokenURIs;


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

    function owned(
        address owner_
      ) public view override returns (uint256[] memory) {
        uint256 totalLength = 0;
        // Pre-calculate total list length for each token value 
        unchecked {
            for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
                totalLength += _idsOwned[owner_][tokenValues[i]].length;
            }
        }

        uint256[] memory allIds = new uint256[](totalLength);
        uint256 currentIndex = 0;
        // Iterate only once over tokenValues to populate allIds
        unchecked {
            for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
                uint256[] memory idsForValue = _idsOwned[owner_][tokenValues[i]];
                for (uint256 j = 0; j < idsForValue.length; j++) {
                    allIds[currentIndex++] = idsForValue[j];
                }
            }
        }

        return allIds;
    }


    function ownedOfValue(
        address owner_,
        uint256 tokenValue_
    )
        public view returns (uint256[] memory) {
            // Directly return the list of token IDs of a specific value owned by the address
            return _idsOwned[owner_][tokenValue_];
    }

    /// @notice gets user balance of each token value
    /// @param user is address to get balances for
    function getNominalBalances(
        address user
    ) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](NUM_TOKEN_VALUES);
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256 _tokenValue = tokenValues[i]; // Use the global constant array
            balances[i] = _idsOwned[user][_tokenValue].length;
        }

        return balances;
    }

    function getNextId(
        address owner, 
        uint256 tokenValue
    ) internal view returns (uint256) {
        uint256[] memory list = _idsOwned[owner][tokenValue];
        if (list.length == 0) {
            revert("No tokens found for this value");
        }
        uint256 nextId = list[list.length - 1];
        return nextId;
    }

    /// @notice total ERC721 balance
    /// @param user is address to get balance
    function erc721BalanceOf(
        address user
    ) public view override returns (uint256) {
        uint256[] memory balances = getNominalBalances(user);
        // Since balances.length is always 4, directly sum up the elements.
        return balances[0] + balances[1] + balances[2] + balances[3];
    }

    /// @notice how many ERC721 of given value stored in the queue
    /// @param value of tokens in queue
    function getERC721QueueLength(
        uint256 value
    ) public view override returns (uint256) {
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




    function setERC721TransferExempt(
        address account_,
        bool value_
    ) external onlyOwner {
        _setERC721TransferExempt(account_, value_);
    }

    /// @notice overrides Pandora's ERC404 to include valueOfId
    /// @param from_ address transfering from
    /// @param to_ address sending to
    /// @param id_ token ID for the ERC721 being sent
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

        // Account for value of ID to transfer correct amount of ERC20
        uint256 valueOfId = _valueOfId[id_] * units;
        _transferERC20(from_, to_, valueOfId);
        _transferERC721(from_, to_, id_);
    }

    /// @notice internal function to handle the transfer of a single ERC721
    /// @dev override Pandora's version to include value of ID
    /// @param from_ address transfering from
    /// @param to_ address sending to
    /// @param id_ token ID for the ERC721 being sent
    function _transferERC721(
        address from_,
        address to_,
        uint256 id_
    ) internal override {
        uint256 value = _valueOfId[id_];
        // If this is not a mint, handle record keeping for transfer from previous owner.
        if (from_ != address(0)) {
            // On transfer of an NFT, any previous approval is reset.
            delete getApproved[id_];

            uint256[] storage ownedOfValue = _idsOwned[from_][value];

            uint256 updatedId = ownedOfValue[ownedOfValue.length - 1];
            if (updatedId != id_) {
                uint256 updatedIndex = _getOwnedIndex(id_);
                // updated _idsOwned for sender
                ownedOfValue[updatedIndex] = updatedId;
                // update index for the moved id
                _setOwnedIndex(updatedId, updatedIndex);
            }
            // pop
            ownedOfValue.pop();
        }

        // Check if this is a burn.
        if (to_ != address(0)) {
            // If not a burn, update the owner of the token to the new owner.
            // Update owner of the token to the new owner.
            _setOwnerOf(id_, to_);

            uint256[] storage ownedOfValueTo = _idsOwned[to_][value];

            // Push token onto the new owner's stack.
            ownedOfValueTo.push(id_);
            // Update index for new owner's stack.
            _setOwnedIndex(id_, ownedOfValueTo.length - 1);
        } else {
            // If this is a burn, reset the owner of the token to 0x0 by deleting the token from _ownedData.
            delete _ownedData[id_];
        }

        emit ERC721Events.Transfer(from_, to_, id_);
    }

    /// @notice function for transfering ERC20s and the corresponding ERC721s
    /// @param from_ address transfering from
    /// @param to_ address sending to
    /// @param value_ in this context is quantity of ERC20s being transferred
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

        // Skip _withdrawAndStoreERC721 and/or _retrieveOrMintERC721 for ERC-721 transfer exempt addresses
        // 1) to save gas
        // 2) because ERC-721 transfer exempt addresses won't always have/need ERC-721s corresponding to their ERC20s.
        if (isFromERC721TransferExempt && isToERC721TransferExempt) {
            // Case 1) Both sender and recipient are ERC-721 transfer exempt. No ERC-721s need to be transferred.
            // NOOP.
        } else if (isFromERC721TransferExempt) {
            // Case 2) The sender is ERC-721 transfer exempt, but the recipient is not. Contract should not attempt
            //         to transfer ERC-721s from the sender, but the recipient should receive ERC-721s
            //         from the bank/minted for any whole number increase in their balance.
            // Only cares about whole number increments.
            uint256 tokensToRetrieveOrMint = (balanceOf[to_] / units) -
                (erc20BalanceOfReceiverBefore / units);

            // user calculateTokens to build list to retrieve or mint
            uint256[] memory _tokensToRetrieveOrMint = calculateTokens(
                tokensToRetrieveOrMint
            );

            // Loop through each token value
            for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
                uint256 quantity;
                uint256 _tokenValue;

                unchecked {
                    quantity = _tokensToRetrieveOrMint[i];
                    _tokenValue = tokenValues[i]; // Directly use the value from the array
                }

                // If quantity is zero, no need to call _retrieveOrMintERC721
                if (quantity > 0) {
                    // Loop 'quantity' times for this token value
                    for (uint256 j = 0; j < quantity; ) {
                        // Call _retrieveOrMintERC721 for each quantity
                        
                            _retrieveOrMintERC721(to_, _tokenValue);
                        unchecked {
                            ++j;
                        }
                    }
                }

                unchecked {
                    ++i;
                }
            }
        } else if (isToERC721TransferExempt) {
            // Case 3) The sender is not ERC-721 transfer exempt, but the recipient is. Contract should attempt
            //         to withdraw and store ERC-721s from the sender, but the recipient should not
            //         receive ERC-721s from the bank/minted.
            // Only cares about whole number increments.
            uint256 tokensToWithdrawAndStore = (erc20BalanceOfSenderBefore /
                units) - (balanceOf[from_] / units);
            // iterate through each value
            for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
                tokenValue_ = _tokenValues[i];
                uint256[] ids = ownedOfValue(from_, _tokenValue);
                
                // skip if no tokens of value to withdraw
                // determine how many ERC721 to withdraw
                uint256 tokens = (tokensToWithdrawAndStore/(ids.length));
                if (!ids.length == 0 && tokens > 1) {
                    
                    // withdraw the tokens
                    for (uint256 j = 0; j < tokens; ) {
                        _withdrawAndStoreERC721(from_, _tokenValue);
                        tokensToWithdrawAndStore -= _tokenValue;
                        unchecked {
                            ++j
                        }
                    }
                        unchecked { 
                            ++i
                        }
                    }
                }


                }  else {
                    // check if change will be needed to cover remaining tokens before moving on to next tokenValue
                    if (balanceOf(from_) - (tokenValue_ * (ids.length())) < tokensToWithdrawAndStore) {
                        // withdraw ERC721
                        _withdrawAndStoreERC721(from_, tokenValue_);
                        
                        // update remaining tokens to withdraw
                        uint256 changeOwedToSender = tokenValue - tokensToWithdrawAndStore;
                        
                        // get change for the sender
                        uint256[] tokensToRetrieveOrMintForSender = calculateTokens(changeOwedToSender);
                        // Loop through each token value
                        for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
                            uint256 quantity;
                            uint256 _tokenValue;

                            unchecked {
                                quantity = _tokensToRetrieveOrMintForSender[i];
                                _tokenValue = tokenValues[i]; // Directly use the value from the array
                            }

                            // If quantity is zero, no need to call _retrieveOrMintERC721
                            if (quantity > 0) {
                                // Loop 'quantity' times for this token value
                                for (uint256 j = 0; j < quantity; ) {
                                    // Call _retrieveOrMintERC721 for each quantity
                                    
                                        _retrieveOrMintERC721(to_, _tokenValue);
                                    unchecked {
                                        ++j;
                                    }
                                }
                            }

                            unchecked {
                                ++i;
                            }
                        }
                    }
                }
            }
        } else {
        // Case 4) Neither the sender nor the recipient are ERC-721 transfer exempt.
        // Strategy:
        // 1. First deal with the whole tokens, from highest value to lowest
        // 2. Get change for the sender if need is there
        // 3. Look at the fractional part of the value:
        //   a) If it causes the sender to lose a whole token that was represented by an NFT due to a
        //      fractional part being transferred, withdraw and store an additional NFT from the sender.
        //   b) If it causes the receiver to gain a whole new token that should be represented by an NFT
        //      due to receiving a fractional part that completes a whole token, retrieve or mint an NFT to the recevier.

        // Whole tokens worth of ERC-20s get transferred as ERC-721s without any burning/minting.
            
        uint256 nftsToTransfer = value_ / units;

                // iterate through each token value
                unchecked {
                    for (uint256 i = 0; i < NUM_TOKEN_VALUES; ++i) {
                        _tokenValue = _tokenValues[i];
                        
                        // get a list of tokens owned of value
                        uint256[] memory ids = ownedOfValue(from_, _tokenValue);
                        if (ids.length != 0) {
                            uint256 quantity = nftsToTransfer / ids.length;
                            // Corrected the way to access the last element in the ids array
                            uint256 tokenId = ids[ids.length - 1];
                            if (quantity > 1) {
                                // This inner loop is already unchecked
                                for (uint256 j = 0; j < quantity; ++j) {
                                    _transferERC721(to_, tokenId);
                                    nftsToTransfer -= _tokenValue; 
                                }
                            }
                        }
                    }
                }

            } else {                         
                
                    // check if change will be needed to cover remaining tokens before moving on to next tokenValue
                    // check if no remainder
                    if (balanceOf(from_) - (_tokenValue * (ids.length)) < nftsToTransfer) {
                        // get change to cover 
                        _withdrawAndStoreERC721(from_, _tokenValue);
                        // update remaining tokens to withdraw
                        uint256 changeOwedToSender = _tokenValue - tokensToWithdrawAndStore;
                        uint256[] tokensToRetrieveOrMintForSender = calculateTokens(changeOwedToSender);
                        // Loop through each token value
                        for (uint256 j = 0; j < NUM_TOKEN_VALUES; ) {
                            uint256 quantity;
                            uint256 _tokenValue;

                unchecked {
                                quantity = _tokensToRetrieveOrMintForSender[j];
                                _tokenValue = tokenValues[j]; // Directly use the value from the array
                            }

                            // If quantity is zero, no need to call _retrieveOrMintERC721
                            if (quantity > 0) {
                                // Loop 'quantity' times for this token value
                                for (uint256 k = 0; k < quantity; ) {
                                    // Call _retrieveOrMintERC721 for each quantity
                                    
                                        _retrieveOrMintERC721(from_, _tokenValue);
                                unchecked {
                                        ++k;
                                    }
                                }
                            }

                            unchecked {
                                ++j;
                            }
                        }

                    }
                }
                    
            }
            /*
            
            
            // new internal function to build a list of quantities to withdraw and store
            uint256[] memory _tokenIdsToWithdrawAndStore = owned(from_);

            // loop through Ids to satisfy tokensToWithdrawAndStore 
            for (uint256 i = 0; i < _tokenIdsToWithdrawAndStore.length; --i) {
               
                uint256 tokenValue_ = _valueOfId[_tokensIdsToWithdrawAndStore[i]];
                if (tokensToWithdrawAndStore > tokenValue_) {
                    _withdrawAndStoreERC721(from_, tokenValue_);
                    tokensToWithdrawAndStore -= tokenValue_;
                } else {

                }

            }
            
            = calculateFromTokensOwned(from_, tokensToWithdrawAndStore);

            if (exactChange != true) {
                uint256 changeNeeded = getChangeForTokenValue - remainingUnits; 
                _withdrawAndStoreERC721(from_, getChangeForTokenValue);
                _retrieveOrMintERC721(from_, changeNeeded);
            }

            // Withdraw and store quantity of tokens from each value
            for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
                uint256 quantity;
                uint256 _tokenValue;

                unchecked {
                    quantity = _tokensToWithdrawAndStore[i];
                    _tokenValue = tokenValues[i];
                }

                // If quantity is zero, no need to call _withdrawAndStore
                if (quantity > 0) {
                    // Loop 'quantity' times for this token value
                    for (uint256 j = 0; j < quantity; ) {
                        // Call _withdrawAndStoreERC721 for each quantity
                       

                            _withdrawAndStoreERC721(to_, _tokenValue);

                    unchecked {
                            ++j;
                        }
                    }
                }

                unchecked {
                    ++i;
                }
            } */
       
                
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
        /*    
            
            
            
            
            uint256[] memory _tokensToWithdrawAndStore = calculateTokens(nftsToTransfer);
            
            for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
                
                unchecked {
                ++i;
                }
            }



            (uint256[] memory _nftsToTransfer, 
            bool exactChange, 
            uint256 tokenValueToExchange, 
            uint256 remainingUnits) = calculateFromTokensOwned(
                from_,
                nftsToTransfer
            );
            if (exactChange != true) {
                // make this block another function
                // first withdraw the token that sender needs change for
                _withdrawAndStoreERC721(from_, tokenValueToExchange);
                // calculate units needed to make sender whole
                uint256 changeNeeded = tokenValueToExchange - remainingUnits;
                // calculate the quantity of each denomination to retrieve for sender
                uint256[] memory quantitiesToRetrieveOrMint = calculateTokens(changeNeeded);
                    
                    for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
                        uint256 q;
                        uint256 _tV;
                        
                        unchecked {
                            q = quantitiesToRetrieveOrMint[i];
                          _tV = tokenValues[i];
                        }  

                        if (q > 0) {

                            for (uint256 j = 0; j < q; ) {

                                unchecked {
                                _retrieveOrMintERC721(from_, _tV);
                                ++j;
                                }
                            }
                        }
                        
                        unchecked {
                        ++i;
                        }
                    }

                    
                
            uint256[] memory quantitiesToRetrieveOrMintTo = calculateTokens(remainingUnits);
                for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
                    uint256 q = quantitiesToRetrieveOrMintTo[i];
                    uint256 _tV = tokenValues[i];

                    if (q > 0) {

                        for (uint256 j = 0; j < q; ) {
                            _retrieveOrMintERC721(to_, _tV);
                        }
                    }
                }

            }

            // Loop through each token value
            for (uint256 i = 0; i < NUM_TOKEN_VALUES; ) {
                uint256 quantity = _nftsToTransfer[i];
                uint256 _tokenValue = tokenValues[i];

                // If quantity is zero, no need to call _withdrawAndStore
                if (quantity > 0) {
                    // Loop 'quantity' times for this token value
                    for (uint256 j = 0; j < quantity; ) {
                        uint256 _id = getNextId(from_, _tokenValue);
                        // Call _withdrawAndStoreERC721 for each quantity
                        _transferERC721(from_,to_, _id);
                        unchecked {
                            ++j;
                        }
                    }
                }
                unchecked {
                    ++i;
                }
            }
*/
            if (
                erc20BalanceOfSenderBefore /
                    units -
                    erc20BalanceOf(from_) /
                    units >
                nftsToTransfer
            ) {
                _withdrawAndStoreERC721(from_, LOOSIES);
            }

            // Then, check if the transfer causes the receiver to gain a whole new token which requires gaining
            // an additional ERC-721. In the case of cigarette tokens, it will be a LOOSIE
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
                nftsToTransfer
            ) {
                _retrieveOrMintERC721(to_, LOOSIES);
            }
        }
        return true;
    }

    /// @dev function is modified from Pandora's 404 to use idsOfValue Deque and include tokenValue as param
    /// @param to_ is the address to send stored or minted tokens
    /// @param tokenValue_ is the value of the token to send
    function _retrieveOrMintERC721(
        address to_,
        uint256 tokenValue_
    ) internal override {
        if (to_ == address(0)) {
            revert InvalidRecipient();
        }
        uint256 id;
        DoubleEndedQueue.Uint256Deque
            storage idsOfValue = _storedERC721sByValue[tokenValue_];

        if (!idsOfValue.empty()) {
            // If there are any tokens in the bank, use those first.
            // Pop off the end of the queue (FIFO).
            id = idsOfValue.popBack();
        } else {
            // Otherwise, mint a new token, should not be able to go over the total fractional supply.
            ++minted;

            // Reserve max uint256 for approvals
            if (minted == type(uint256).max) {
                revert MintLimitReached();
            }
        }
        id = ID_ENCODING_PREFIX + minted;

        address erc721Owner = _getOwnerOf(id);

        // The token should not already belong to anyone besides 0x0 or this contract.
        // If it does, something is wrong, as this should never happen.
        if (erc721Owner != address(0)) {
            revert AlreadyExists();
        }

        // store value of ID
        _valueOfId[id] = tokenValue_;

        // Transfer the token to the recipient, either transferring from the contract's bank or minting.
        // Does not handle ERC-721 exemptions.
        _transferERC721(erc721Owner, to_, id);
    }


    /// @dev function is modified from Pandora's 404 to use idsOfValue Deque and include tokenValue as param
    /// @param from_ is the address to withdraw and store tokens from
    /// @param tokenValue_ is the value of the token to send
    function _withdrawAndStoreERC721(
        address from_,
        uint256 tokenValue_
    ) internal override {
        if (from_ == address(0)) {
            revert InvalidSender();
        }

        uint256[] memory ownedOfValue = _idsOwned[from_][tokenValue_];
        // Retrieve the latest token added to the owner's stack (LIFO).
        uint256 updatedId = ownedOfValue[ownedOfValue.length - 1];

        // Transfer to 0x0.
        // Does not handle ERC-721 exemptions.
        _transferERC721(from_, address(0), updatedId);

        DoubleEndedQueue.Uint256Deque
            storage storedERC721sOfValue = _storedERC721sByValue[tokenValue_];
        // Record the token in the contract's bank queue.
        storedERC721sOfValue.pushFront(updatedId);
    }

    /// @dev takes a quantity of units and builds a list of tokens to mint for each value
    /// @param _units are whole ERC20s to calculate from
    function calculateTokens(
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
/*
    /// @dev takes a quantity of units and builds list of tokens to withdraw from address
    /// this is helpful because it is possible for an address to have spare change in terms
    /// of token denominations
    /// @param owner_ is address to calculate tokens from
    /// @param units_ is whole ERC20s to calculate from
    function calculateFromTokensOwned(
        address owner_,
        uint256 units_
    ) internal view returns (uint256[] memory, bool) {
        uint256[] memory tokensToWithdraw = new uint256[](NUM_TOKEN_VALUES);
        uint256 remainingUnits = units_;
        uint256[] memory ownerBalances = getNominalBalances(owner_);
        bool canFulfillExactWithdrawal = true;

        for (uint256 i = 0; i < tokenValues.length; ) {
            uint256 maxTokensPossible = remainingUnits / tokenValues[i];
            uint256 tokensToActuallyWithdraw = (ownerBalances[i] <
                maxTokensPossible)
                ? ownerBalances[i]
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
                tokensToWithdraw[i] = ownerBalances[i];
            }
        }

        // The function now also returns a boolean indicating whether the exact withdrawal request can be fulfilled.
        return (tokensToWithdraw, canFulfillExactWithdrawal);
    }
    */

   function calculateFromTokensOwned(
        address owner_,
        uint256 units_
    ) internal view returns (
        uint256[] memory tokensToWithdraw, 
        bool canFulfillExactWithdrawal, 
        uint256 getChangeFor, 
        uint256 remainingUnits
    ) {
        tokensToWithdraw = new uint256[](NUM_TOKEN_VALUES);
        remainingUnits = units_;
        uint256[] memory ownerBalances = getNominalBalances(owner_);
        canFulfillExactWithdrawal = true;
        getChangeFor = 0; // Assuming 0 is an invalid ID and indicates no additional token is required.

        for (uint256 i = 0; i < tokenValues.length; i++) {
            uint256 maxTokensPossible = remainingUnits / tokenValues[i];
            uint256 tokensToActuallyWithdraw = (ownerBalances[i] < maxTokensPossible) ? ownerBalances[i] : maxTokensPossible;

            tokensToWithdraw[i] = tokensToActuallyWithdraw;
            remainingUnits -= tokensToActuallyWithdraw * tokenValues[i];

            if (remainingUnits == 0) break;
        }

        if (remainingUnits > 0) {
            canFulfillExactWithdrawal = false;

            // Attempt to cover the shortfall by considering an additional token from the previously processed category.
            if (tokenValues.length > 0 && ownerBalances[0] > 0) {
                getChangeFor = tokenValues[0]; // Use the first category's value as an example; adjust based on your logic.
                // Note: Adjust the logic here based on your application's needs.
            }
        }

        return (tokensToWithdraw, canFulfillExactWithdrawal, getChangeFor, remainingUnits);
    }



    /// @notice Function to reinstate balance on exemption removal
    /// @dev Pandora's 404 which had visibility private, changed to internal
    /// to override it
    /// @param target_ address to reinstate balances
    function _reinstateERC721Balance(address target_) internal override {
        uint256 _targetBalance = balanceOf[target_];
        uint256[] memory _tokensToRetrieveOrMint = calculateTokens(
            _targetBalance
        );

        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            if (_tokensToRetrieveOrMint[i] > 0) {
                for (
                    uint256 loops = 0;
                    loops < _tokensToRetrieveOrMint[i];
                    loops++
                ) {
                    uint256 _tokenValue = tokenValues[i]; // Ensure _tokenValue is declared with its type
                    // Transfer ERC721 balance in from pool
                    _retrieveOrMintERC721(target_, _tokenValue);
                }
            }
        }
    }

    /// less gas efficient method
    function _clearERC721Balance(address target_) internal override {
        uint256[] memory ownerBalances = getNominalBalances(target_);
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            if (ownerBalances[i] > 0) {
                for (uint256 loops = 0; loops < ownerBalances[i]; loops++) {
                    uint256 _tokenValue = tokenValues[i]; // Ensure _tokenValue is declared with its type
                    _withdrawAndStoreERC721(target_, _tokenValue);
                }
            }
        }
    }

    /// @notice Function to reinstate balance on exemption removal
    /// @dev Pandora's 404 which had visibility private, changed to internal
    /// to override it -  uses owned function to build list since token
    /// we are clearing all token IDs regardless of value
    /// @param target_ address to reinstate balances
    function clearERC721Balance(address target_) private {
        uint[] memory targetTokens = owned(target_);
        for (uint256 i = 0; i < (targetTokens.length - 1); i++) {
            uint256 tokenId = targetTokens[i];
            uint256 _tokenValue = _valueOfId[tokenId];
            _withdrawAndStoreERC721(target_, _tokenValue);
        }
    }




    function tokenURI(uint256 id_) public view override returns (string memory) {
        // Decode the token value from the ID
        uint256 valueOfId;
        valueOfId = _valueOfId[id_];

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
