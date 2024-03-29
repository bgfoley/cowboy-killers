//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DoubleEndedQueue} from "./lib/DoubleEndedQueue.sol";
import {ERC404UniswapV2Exempt} from "./extensions/ERC404UniswapV2Exempt.sol";
import {ERC404} from "./ERC404.sol"; 
import {ERC721Events} from "./lib/ERC721Events.sol";
import {ERC20Events} from "./lib/ERC20Events.sol";

contract Cowboy is Ownable, ERC404TV, ERC404UniswapV2Exempt {

    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;
    mapping(uint256 => DoubleEndedQueue.Uint256Deque) private _storedERC721sByValue;

    using Strings for uint256;
    ///@dev token values constant for efficiency
    uint256 private constant MARLBORO_MEN = 600;
    uint256 private constant CARTONS = 200;
    uint256 private constant PACKS = 20;
    uint256 private constant LOOSIES = 1;
    uint256 private constant NUM_TOKEN_VALUES = 4;

    ///@dev token values need to be in descending order for loopBurn logic to work
    uint256[NUM_TOKEN_VALUES] public tokenValue = [
        MARLBORO_MEN, CARTONS, PACKS, LOOSIES];

    /// @dev use IdsOwned index instead of _owned to sort by value
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
    )
        ERC404(name_, symbol_, decimals_)
        Ownable(initialOwner_)
        ERC404UniswapV2Exempt(uniswapV2Router_)
    {
        // Do not mint the ERC721s to the initial owner, as it's a waste of gas.
        _setERC721TransferExempt(initialMintRecipient_, true);
        _mintERC20(initialMintRecipient_, maxTotalSupplyERC721_ * units);
    }

    function owned(
        address owner_
      ) public view override returns (
        uint256[] memory
        ) {
        // Assuming tokenValue is accessible and contains the four distinct values
        uint256 totalLength = 0;

        // Calculate total length needed for the consolidated array
        for (uint256 i = 0; i < tokenValue.length; i++) {
            totalLength += _idsOwned[owner_][tokenValue[i]].length;
        }

        // Allocate memory for the consolidated array
        uint256[] memory allIds = new uint256[](totalLength);

        // Populate the consolidated array
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < tokenValue.length; i++) {
            uint256[] memory idsForValue = _idsOwned[owner_][tokenValue[i]];
            for (uint256 j = 0; j < idsForValue.length; j++) {
                allIds[currentIndex] = idsForValue[j];
                currentIndex++;
            }
        }

        return allIds;
    }

    function getNominalBalances(address user) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](NUM_TOKEN_VALUES);

        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256 _tokenValue = tokenValue[i]; // Use the global constant array
            balances[i] = _idsOwned[user][_tokenValue].length;
        }

        return balances;
    }


    function erc721BalanceOf(
        address user
      ) public view override 
        returns (uint256) {
        uint256[] memory balances = getNominalBalances(user);
        // Since balances.length is always 4, directly sum up the elements.
        return balances[0] + balances[1] + balances[2] + balances[3];
    }


/// @todo update to new mapping
    function getERC721QueueLength(
        uint256 tokenValue_
      ) public view override returns (uint256) 
        uint256 queue = _storedERC721sByValue[tokenValue_]
      {
        return queue.length();
    }

/// @todo update to new mapping
    function getERC721TokensInQueueByValue(
        uint256 tokenValue_,
        uint256 start_,
        uint256 count_
    ) public view returns (uint256[] memory) {
        uint256[] memory tokensInQueue = new uint256[](count_);

        for (uint256 i = start_; i < start_ + count_; ) {
            tokensInQueue[i - start_] = (_storedERC721sByValue[tokenValue_]).at(i);

            unchecked {
                ++i;
            }
        }
        
        return tokensInQueue;
    }    

    function tokenURI(uint256 id_) public pure override returns (string memory) {
        return string.concat("https://example.com/token/", Strings.toString(id_));
    }

    function setERC721TransferExempt(
        address account_,
        bool value_
    )   external onlyOwner {
        _setERC721TransferExempt(account_, value_);
    }
    
    ///@dev override to include valueOfId
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

    
        // Transfer 1 * units ERC-20 and 1 ERC-721 token.
        // ERC-721 transfer exemptions handled above. Can't make it to this point if either is transfer exempt.
        uint256 valueOfId = _valueOfId[id_] * units;
        _transferERC20(from_, to_, valueOfId);
        _transferERC721(from_, to_, id_);
    }

    function _transferERC721(
        address from_,
        address to_,
        uint256 id_
    ) internal override {
        // If this is not a mint, handle record keeping for transfer from previous owner.
        if (from_ != address(0)) {
        // On transfer of an NFT, any previous approval is reset.
        delete getApproved[id_];

        uint256 value = _valueOfId[id_];
        uint256[] ownedOfValue = _idsOwned[from_][value];

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

        uint256[] ownedOfValueTo = _owned[to_][value]; 
        
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

    function _transferERC20WithERC721(
        address from_,
        address to_,
        uint256 value_
    )   internal override returns (bool) {
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

        uint256[] memory _tokensToRetrieveOrMint = calculateTokens(tokensToRetrieveOrMint);

        // Loop through each token value
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256 quantity = _tokensToRetrieveOrMint[i];
            uint256 tokenValue;

            // Assign the correct token value based on the index
            if (i == 0) {
                tokenValue = MARLBORO_MEN;
            } else if (i == 1) {
                tokenValue = CARTONS;
            } else if (i == 2) {
                tokenValue = PACKS;
            } else if (i == 3) {
                tokenValue = LOOSIES;
            } else {
                // Handle unexpected index
                revert("Invalid index");
            }

            // If quantity is zero, no need to call _retrieveOrMintERC721
            if (quantity > 0) {
                // Loop 'quantity' times for this token value
                for (uint256 j = 0; j < quantity; j++) {
                    // Call _retrieveOrMintERC721 for each quantity
                    _retrieveOrMintERC721(to_, tokenValue);
                }
            }
        }
        
        } else if (isToERC721TransferExempt) {
        // Case 3) The sender is not ERC-721 transfer exempt, but the recipient is. Contract should attempt
        //         to withdraw and store ERC-721s from the sender, but the recipient should not
        //         receive ERC-721s from the bank/minted.
        // Only cares about whole number increments.
        uint256 tokensToWithdrawAndStore = (erc20BalanceOfSenderBefore / units) -
        (balanceOf[from_] / units);
///@todo add new function to loop through owned tokens
        uint256[] memory _tokensToWithdrawAndStore = calculateFromTokensOwned(from_, tokensToWithdrawAndStore);

        // Loop through each token value
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256 quantity = _tokensToWithdrawAndStore[i];
            uint256 tokenValue;

            // Assign the correct token value based on the index
            if (i == 0) {
                tokenValue = MARLBORO_MEN;
            } else if (i == 1) {
                tokenValue = CARTONS;
            } else if (i == 2) {
                tokenValue = PACKS;
            } else if (i == 3) {
                tokenValue = LOOSIES;
            } else {
                // Handle unexpected index
                revert("Invalid index");
            }

            // If quantity is zero, no need to call _withdrawAndStore
            if (quantity > 0) {
                // Loop 'quantity' times for this token value
                for (uint256 j = 0; j < quantity; j++) {
                    // Call _retrieveOrMintERC721 for each quantity
                    _withdrawAndStore(to_, tokenValue);
                }
            }
        }
    } else {
      // Case 4) Neither the sender nor the recipient are ERC-721 transfer exempt.
      // Strategy:
      // 1. First deal with the whole tokens. These are easy and will just be transferred.
      // 2. Look at the fractional part of the value:
      //   a) If it causes the sender to lose a whole token that was represented by an NFT due to a
      //      fractional part being transferred, withdraw and store an additional NFT from the sender.
      //   b) If it causes the receiver to gain a whole new token that should be represented by an NFT
      //      due to receiving a fractional part that completes a whole token, retrieve or mint an NFT to the recevier.

      // Whole tokens worth of ERC-20s get transferred as ERC-721s without any burning/minting.
      uint256 nftsToTransfer = value_ / units;
      uint256[] memory _nftsToTransfer = calculateFromTokensOwned(from_, nftsToTransfer);  

      // Loop through each token value
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256 quantity = _tokensToWithdrawAndStore[i];
            uint256 tokenValue;

            // Assign the correct token value based on the index
            if (i == 0) {
                tokenValue = MARLBORO_MEN;
            } else if (i == 1) {
                tokenValue = CARTONS;
            } else if (i == 2) {
                tokenValue = PACKS;
            } else if (i == 3) {
                tokenValue = LOOSIES;
            } else {
                // Handle unexpected index
                revert("Invalid index");
            }

            // If quantity is zero, no need to call _withdrawAndStore
            if (quantity > 0) {
                // Loop 'quantity' times for this token value
                for (uint256 j = 0; j < quantity; j++) {
                    // Call _retrieveOrMintERC721 for each quantity
                    _withdrawAndStore(to_, tokenValue);
                }
            }
        }
      
        if (
            erc20BalanceOfSenderBefore / units - erc20BalanceOf(from_) / units >
            nftsToTransfer
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
            erc20BalanceOf(to_) / units - erc20BalanceOfReceiverBefore / units >
            nftsToTransfer
        )     {
                _retrieveOrMintERC721(to_, LOOSIES);
            }
            } 
        return true;

    }

///@todo DONE - override to add tokenValue
    function _retrieveOrMintERC721(address to_, uint256 tokenValue_) internal override {
        if (to_ == address(0)) {
        revert InvalidRecipient();
        }

        DoubleEndedQueue.Uint256Deque storage idsOfValue = storedERC721sByValue[tokenValue_];

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

        id = ID_ENCODING_PREFIX + minted;
        }

        address erc721Owner = _getOwnerOf(id);

        // The token should not already belong to anyone besides 0x0 or this contract.
        // If it does, something is wrong, as this should never happen.
        if (erc721Owner != address(0)) {
        revert AlreadyExists();
        }

        // Transfer the token to the recipient, either transferring from the contract's bank or minting.
        // Does not handle ERC-721 exemptions.
        _transferERC721(erc721Owner, to_, id);
    }

    /// modify this function to handle bulk
    function _withdrawAndStoreERC721(address from_, uint256 tokenValue_) internal override {
        if (from_ == address(0)) {
        revert InvalidSender();
        }

        // Retrieve the latest token added to the owner's stack (LIFO).
        uint256 id = _owned[from_][_owned[from_].length - 1];

        // Transfer to 0x0.
        // Does not handle ERC-721 exemptions.
        _transferERC721(from_, address(0), id);

        uint256[] _storedERC721sOfValue = storedERC721sByValue[tokenValue_];
        // Record the token in the contract's bank queue.
        _storedERC721sOfValue.pushFront(id);
    }

    function calculateTokens(uint256 _units) internal pure returns (uint256[] memory) {
        uint256[] memory tokensToRetrieveOrMint = new uint256[](NUM_TOKEN_VALUES);
        uint256 remainingUnits = _units;

        // Calculate the number of units to retrieve or mint for each token value
        for (uint256 i = 0; i < tokenValue.length; i++) {
            tokensToRetrieveOrMint[i] = remainingUnits / tokenValue[i];
            remainingUnits %= tokenValue[i];
        }

        return tokensToRetrieveOrMint;
        }


    function calculateFromTokensOwned(
        address owner_, 
        uint256 units_
    ) internal view returns (uint256[] memory, bool) {
        uint256[] memory tokensToWithdraw = new uint256[](NUM_TOKEN_VALUES);
        uint256 remainingUnits = units_;
        uint256[] memory ownerBalances = getNominalBalances(owner_);
        bool canFulfillExactWithdrawal = true;

        for (uint256 i = 0; i < tokenValue.length; i++) {
            uint256 maxTokensPossible = remainingUnits / tokenValue[i];
            uint256 tokensToActuallyWithdraw = (ownerBalances[i] < maxTokensPossible) ? ownerBalances[i] : maxTokensPossible;
            
            tokensToWithdraw[i] = tokensToActuallyWithdraw;
            remainingUnits -= tokensToActuallyWithdraw * tokenValue[i];

            if (remainingUnits == 0) break;
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

/*
    function _retrieveOrMintERC721(address to_) internal override {
        if (to_ == address(0)) {
        revert InvalidRecipient();
        }

        uint256 id;

        if (!_storedERC721Ids.empty()) {
        // If there are any tokens in the bank, use those first.
        // Pop off the end of the queue (FIFO).
        id = _storedERC721Ids.popBack();
        } else {
        // Otherwise, mint a new token, should not be able to go over the total fractional supply.
        ++minted;

        // Reserve max uint256 for approvals
        if (minted == type(uint256).max) {
            revert MintLimitReached();
        }

        id = ID_ENCODING_PREFIX + minted;
        }

        address erc721Owner = _getOwnerOf(id);

        // The token should not already belong to anyone besides 0x0 or this contract.
        // If it does, something is wrong, as this should never happen.
        if (erc721Owner != address(0)) {
        revert AlreadyExists();
        }

        // Transfer the token to the recipient, either transferring from the contract's bank or minting.
        // Does not handle ERC-721 exemptions.
      //  _transferERC721(erc721Owner, to_, id);
    }
*/

/*
  // Adjusted _retrieveOrMintERC721 function to support minting batches
    function retrieveOrMintERC721(address to_, uint256 value, uint256 quantity) internal {
    if (to_ == address(0)) {
        revert InvalidRecipient();
    }

    uint256[] memory ids;

    if (getERC721QueueLength() == 0) {
        // If there are any tokens in the bank, use those first.
        // Pop off the end of the queue (FIFO).
        // Get the length of the queue
        uint256 queueLength = getERC721QueueLength();

        // Calculate the starting index to fetch the tokens from
        uint256 startIndex = queueLength > quantity ? queueLength - quantity : 0;

        // Fetch the tokens from the queue
        ids = getERC721TokensInQueue(startIndex, quantity);

    } else {
        ids = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            // Otherwise, mint a new token, should not be able to go over the total fractional supply.
            ++minted;

            // Reserve max uint256 for approvals
            if (minted == type(uint256).max) {
                revert MintLimitReached();
            }

            uint256 id = ID_ENCODING_PREFIX + minted;
            ids[i] = id;
        }
    }

    // Transfer the tokens to the recipient, either transferring from the contract's bank or minting.
    batchTransferERC721(address(this), to_, ids);
}
*/
/*
function withdrawAndStoreERC721(
    address from_,
    uint256 _tokenValue,
    uint256 quantity
) internal virtual {
    if (from_ == address(0)) {
        revert InvalidSender();
    }

    for (uint256 i = 0; i < quantity; i++) {
        // Retrieve the latest token added to the owner's stack (LIFO).
        uint256 id = _owned[from_][_owned[from_].length - 1];

        // Transfer to 0x0.
        // Does not handle ERC-721 exemptions.
        _transferERC721(from_, address(0), id);

        // Record the token in the contract's bank queue.
        _storedERC721Ids.pushFront(id);

        // Emit Transfer event
        emit ERC721Events.Transfer(from_, address(0), id);
    }
}

*/
/*
function batchTransferERC721(
    address from_,
    address to_,
    uint256[] memory ids
) internal virtual {
    // If this is not a mint, handle record keeping for transfer from previous owner.
    if (from_ != address(0)) {
        // On transfer of an NFT, any previous approval is reset.
        for (uint256 i = 0; i < ids.length; i++) {
            delete getApproved[ids[i]];

            uint256 updatedId = _owned[from_][_owned[from_].length - 1];
            if (updatedId != ids[i]) {
                uint256 updatedIndex = _getOwnedIndex(ids[i]);
                // Update _owned for sender
                _owned[from_][updatedIndex] = updatedId;
                // Update index for the moved id
                _setOwnedIndex(updatedId, updatedIndex);
            }

            // Pop
            _owned[from_].pop();
        }
    }

    // If not a burn, update the owner of the tokens to the new owner.
    if (to_ != address(0)) {
        for (uint256 i = 0; i < ids.length; i++) {
            // Update owner of the token to the new owner.
            _setOwnerOf(ids[i], to_);
            // Push token onto the new owner's stack.
            _owned[to_].push(ids[i]);
            // Update index for new owner's stack.
            _setOwnedIndex(ids[i], _owned[to_].length - 1);
        }
    } else {
        // If this is a burn, reset the owner of the tokens to 0x0 by deleting the tokens from _ownedData.
        for (uint256 i = 0; i < ids.length; i++) {
            delete _ownedData[ids[i]];
        }
    }

    // Emit Transfer event for each token transferred.
    for (uint256 i = 0; i < ids.length; i++) {
        emit ERC721Events.Transfer(from_, to_, ids[i]);
    }
}
*/





function sortOwnedTokens(address owner) internal {
    uint256 totalOwned = _owned[owner].length;
    
    // Step 1: Initialize temporary arrays
    uint256[] memory marlboroMenTokens = new uint256[](totalOwned);
    uint256[] memory cartonTokens = new uint256[](totalOwned);
    uint256[] memory packTokens = new uint256[](totalOwned);
    uint256[] memory loosieTokens = new uint256[](totalOwned);
    
    uint256 marlboroMenCount;
    uint256 cartonCount;
    uint256 packCount;
    uint256 loosieCount;
    
    // Step 2: Group IDs by their value
    for (uint256 i = 0; i < totalOwned; i++) {
        uint256 tokenId = _owned[owner][i];
        uint256 value = _valueOfId[tokenId];
        
        if (value == MARLBORO_MEN) {
            marlboroMenTokens[marlboroMenCount++] = tokenId;
        } else if (value == CARTONS) {
            cartonTokens[cartonCount++] = tokenId;
        } else if (value == PACKS) {
            packTokens[packCount++] = tokenId;
        } else if (value == LOOSIES) {
            loosieTokens[loosieCount++] = tokenId;
        }
    }
    
    // Step 3: Concatenate the groups in descending order of their values
    uint256[] memory sortedTokens = new uint256[](totalOwned);
    uint256 index = 0;
    for (uint256 i = 0; i < marlboroMenCount; i++) {
        sortedTokens[index++] = marlboroMenTokens[i];
    }
    for (uint256 i = 0; i < cartonCount; i++) {
        sortedTokens[index++] = cartonTokens[i];
    }
    for (uint256 i = 0; i < packCount; i++) {
        sortedTokens[index++] = packTokens[i];
    }
    for (uint256 i = 0; i < loosieCount; i++) {
        sortedTokens[index++] = loosieTokens[i];
    }
    
    // Step 4: Update the owner's array
    _owned[owner] = sortedTokens;
}


    