//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DoubleEndedQueue} from "./lib/DoubleEndedQueue.sol";
import {ERC404UniswapV2Exempt} from "./extensions/ERC404UniswapV2Exempt.sol";
import {ERC404} from "./ERC404.sol"; 
import {ERC721Events} from "./lib/ERC721Events.sol";
import {ERC20Events} from "./lib/ERC20Events.sol";


contract Cowboy is Ownable, ERC404, ERC404UniswapV2Exempt{
    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;
    // Mapping from token value to its respective queue
    mapping(uint256 => DoubleEndedQueue.Uint256Deque) private _storedERC721IdsByValue;
    using Strings for uint256;
    //@dev token values constant for efficiency
    uint256 private constant MARLBORO_MEN = 600;
    uint256 private constant CARTONS = 200;
    uint256 private constant PACKS = 20;
    uint256 private constant LOOSIES = 1;
    uint256 private constant NUM_TOKEN_VALUES = 4;

    ///@dev token values need to be in descending order for loopBurn logic to work
    uint256[NUM_TOKEN_VALUES] public tokenValue = [
        MARLBORO_MEN, CARTONS, PACKS, LOOSIES];

    mapping(uint256 => string) internal _tokenValueURI;
    mapping(uint256 => string) internal _tokenURIs;
     // map unique token IDs by value
    mapping(uint256 => uint256) internal _valueOfId;  
    // an array of owned IDs grouped by value
    mapping(address => mapping(uint256 => uint256[])) internal _idsOwnedByValue;
    // indices for Owned ids
    mapping(uint256 => uint256) internal _ownedByValueIndex; 
   

    string private constant NAME = "Ciggies";
    string private constant SYMBOL = "CGS";
    uint8 private constant DECIMALS = 18;
    uint256 private constant MAX_TOTAL_SUPPLY_ERC721 = 600000;
    // Ensure this address is correct for your deployment network (e.g., Ethereum Mainnet, Rinkeby, etc.)
    address public UNISWAP_ROUTER;
    constructor(address _router) 
        ERC404(NAME, SYMBOL, DECIMALS) 
        Ownable(msg.sender) 
        ERC404UniswapV2Exempt(_router)
    {
        // Do not mint the ERC721s to the initial owner, as it's a waste of gas.
        _setERC721TransferExempt(owner(), true);
        _mintERC20(msg.sender, MAX_TOTAL_SUPPLY_ERC721 * units);
    }

    function setERC721TransferExempt(
        address account_,
        bool value_
    ) external onlyOwner {
        _setERC721TransferExempt(account_, value_);
    }

    function owned(address owner_) public view override returns (uint256[] memory) {
        uint256 totalSize = 0;
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            totalSize += _idsOwnedByValue[owner_][tokenValue[i]].length;
        }

        uint256[] memory allTokens = new uint256[](totalSize);
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256[] storage tokensOfValue = _idsOwnedByValue[owner_][tokenValue[i]];
        for (uint256 j = 0; j < tokensOfValue.length; j++) {
            allTokens[currentIndex++] = tokensOfValue[j];
            }
        }
        return allTokens;
    }

    function getTokenIdsOfValue(
        address owner, 
        uint256 value
        ) public view returns (uint256[] memory) {
        require(
            value == MARLBORO_MEN || 
            value == CARTONS || 
            value == PACKS || 
            value == LOOSIES, "Invalid token value");
        return _idsOwnedByValue[owner][value];
    }

    function erc721BalanceOf(
        address owner_
        ) public view override returns (uint256) {
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
        totalBalance += _idsOwnedByValue[owner_][tokenValue[i]].length;
        }
        return totalBalance;
    }
    

    function getNominalBalances(
        address owner_
        ) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](NUM_TOKEN_VALUES);

        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256 _tokenValue = tokenValue[i]; // Use the global constant array
            balances[i] = _idsOwnedByValue[owner_][_tokenValue].length;
        }

        return balances;
    }

    
    function tokenURI(uint256 id_) public pure override returns (string memory) {
        return string.concat("https://example.com/token/", Strings.toString(id_));
    }

    ///@dev modified to include token's value so ERC20 balances update correctly
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
        if (
            erc721TransferExempt(to_)) {
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
            // get the value of the ID 
            uint256 valueOfId = _valueOfId[id_];
            // get the appropriate array to pull from
            uint256[] storage senderIdsOfValue = _idsOwnedByValue[from_][valueOfId];
            uint256[] storage receiverIdsOfValue = _idsOwnedByValue[to_][valueOfId];
            // update ownership 
            uint256 updatedId = senderIdsOfValue[senderIdsOfValue.length - 1];
            if (updatedId != id_) {
             
                uint256 updatedIndex = _ownedByValueIndex[id_]; 
                // update _idsOwned sender
                senderIdsOfValue[updatedIndex] = updatedId;
               
                _ownedByValueIndex[updatedId] = _ownedByValueIndex[id_];

                 // update ownedByValueIndex
                senderIdsOfValue.pop();
            }   

        // Check if this is a burn.
        if (to_ != address(0)) {
        // If not a burn, update the owner of the token to the new owner.
        // Update owner of the token to the new owner.
        _setOwnerOf(id_, to_);
        // Push token onto the new owner's stack.
        receiverIdsOfValue.push(id_);
        // Update index for new owner's stack.
        _ownedByValueIndex[id_] = receiverIdsOfValue.length - 1;
        } else {
        // If this is a burn, reset the owner of the token to 0x0 by deleting the token from _ownedData.
        delete _ownedData[id_];
        }

        emit ERC721Events.Transfer(from_, to_, id_);
    }
    }
 /*   

   
    function owned(
        address owner_
    ) public view override returns (uint256[] memory) {
        return _owned[owner_];
    }
*/
/*    
    

    function _getOwnerOf(
        uint256 id_
        ) internal view virtual returns (address ownerOf_) {
        uint256 data = _ownedData[id_];

        assembly {
            ownerOf_ := and(data, _BITMASK_ADDRESS)
        }
    }
*/
   
    
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

        // Skip _withdrawAndStoreERC721_ and/or _retrieveOrMintERC721_ for ERC-721 transfer exempt addresses
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


 

        for (uint256 i = 0; i < tokensToRetrieveOrMint; ) {
 //           _retrieveOrMintERC721_(to_);
            loopToMint(to_, tokensToRetrieveOrMint);
            unchecked {
            ++i;
            }
        }
        }  else if (isToERC721TransferExempt) {
        // Case 3) The sender is not ERC-721 transfer exempt, but the recipient is. Contract should attempt
        //         to withdraw and store ERC-721s from the sender, but the recipient should not
        //         receive ERC-721s from the bank/minted.
        // Only cares about whole number increments.
  
        uint256 tokensToWithdrawAndStore = (erc20BalanceOfSenderBefore / units) -
            (balanceOf[from_] / units);
        for (uint256 i = 0; i < tokensToWithdrawAndStore; ) {

            loopToBurn(from_, tokensToWithdrawAndStore);
            unchecked {
            ++i;
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

        uint256 nftsToTransfer = value_ / units;
        // Whole tokens worth of ERC-20s get transferred as ERC-721s without any burning/minting.
        transferNFTsInExactChange(from_, to_, value_);
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
//revisit this when you understand better    
            erc20BalanceOfSenderBefore / units - erc20BalanceOf(from_) / units >
            nftsToTransfer
        ) {
            loopToBurn(from_, nftsToTransfer);
        }

        // Then, check if the transfer causes the receiver to gain a whole new token which requires gaining
        // an additional ERC-721.
        //
        // Process:
        // Take the difference between the whole number of tokens before and after the transfer for the recipient.
        // If that difference is greater than the number of ERC-721s transferred (whole units), then there was
        // an additional ERC-721 gained due to the fractional portion of the transfer.
        // Again, for self-sends where the before and after balances are equal, no ERC-721s will be gained here.
// same here      
        if (
            erc20BalanceOf(to_) / units - erc20BalanceOfReceiverBefore / units >
            nftsToTransfer
        ) {
            loopToMint(to_, nftsToTransfer);
        }
        }

        return true;
    }

    function transferNFTsInExactChange(address from_, address to_, uint256 value_) internal virtual returns (bool) {
        uint256 remainingValue = value_;

        // Iterate over each token denomination, starting with the largest
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
            uint256 currentValue = tokenValue[i];
            uint256 nftsToTransfer = remainingValue / currentValue;

            // Update the remaining value for the next iteration
            remainingValue -= nftsToTransfer * currentValue;

            for (uint256 j = 0; j < nftsToTransfer; j++) {
                if (_storedERC721IdsByValue[currentValue].empty()){
                    // Retrieve a token of the current denomination

                    uint256 tokenId = _storedERC721IdsByValue[currentValue].popBack();

                    // Transfer the NFT from sender to receiver
                    _transferERC721(from_, to_, tokenId);
                } else {
                    // If there are not enough NFTs of the current denomination in the queue,
                    // this could either trigger a minting process, or you might need to
                    // revise the logic based on your specific requirements.
                    // Placeholder for minting or other logic:
                    // _mintAndTransferERC721(to_, currentValue);
                }
            }

            if (remainingValue == 0) {
                break; // Exit the loop if there's no remaining value to be transferred
            }
        }

        // After iterating through all denominations, if there's still remaining value,
        // additional logic might be needed to handle this scenario.

        return true;
    }

 // reformatted to handle batches
    function _retrieveOrMintERC721_(address to_, uint256 _tokenValue, uint256 quantity) internal {
        if (to_ == address(0)) {
            revert InvalidRecipient();
        }

        for (uint256 q = 0; q < quantity; ++q) {
        uint256 id;

        // Check if there are tokens of the specified value in the bank.
        if (!_storedERC721IdsByValue[_tokenValue].empty()) {
            // Pop off the end of the queue (FIFO) for the specified token value.
            id = _storedERC721IdsByValue[_tokenValue].popBack();
        } else {
            // Mint a new token, ensuring not to exceed the total fractional supply or the max uint256 value.
            ++minted;

            if (minted == type(uint256).max) {
                revert MintLimitReached();
            }

            // Incorporate _tokenValue into the ID encoding if necessary, or use a separate mapping to track values.
            id = ID_ENCODING_PREFIX + minted;
            // Optionally, associate the minted token with its value in a separate mapping if ID encoding doesn't include value.
        }

        address erc721Owner = _getOwnerOf(id);

        // Ensure the token does not already belong to someone other than the zero address or this contract.
        if (erc721Owner != address(0)) {
            revert AlreadyExists();
        }

        // Transfer the token to the recipient, whether from the contract's bank or newly minted.
        _transferERC721(address(0), to_, id); // Assuming erc721Owner is always this contract or 0x0 for these tokens.
        
        // Optionally, update a mapping to record the token's value, if not encoded in the ID.
        }
    }


/// modify to withdraw and store batches
    function _withdrawAndStoreERC721_(address from_, uint256 _tokenValue, uint256 quantity) internal {
        if (from_ == address(0)) {
        revert InvalidSender();
        }

        for (uint256 q = 0; q < quantity; ++q) {

        // Retrieve the latest token added to the owner's stack (LIFO).
        uint256[] storage senderIdsOfValue = _idsOwnedByValue[from_][_tokenValue];
        uint256 id = senderIdsOfValue[senderIdsOfValue.length - 1];

        // Transfer to 0x0.
        // Does not handle ERC-721 exemptions.
        _transferERC721(from_, address(0), id);

        // Record the token in the contract's bank queue.
        _storedERC721IdsByValue[_tokenValue].pushFront(id);
    }
    }

    function loopToMint(address _receiver, uint256 _amount) internal {
        for (uint256 i = 0; i < NUM_TOKEN_VALUES && _amount > 0; i++) {
            uint256 _tokenValue = tokenValue[i]; // Use the global constant array directly
            // Calculate tokens of this denomination to mint
            uint256 tokensOfValueToMint = _amount / _tokenValue;
            if (tokensOfValueToMint > 0) {
                _retrieveOrMintERC721_(_receiver, _tokenValue, tokensOfValueToMint);
                // Update the remaining amount of tokens to mint
                _amount -= tokensOfValueToMint * _tokenValue;
            }
        }
    }

    function loopToBurn(address _burner, uint256 _amount) internal {
        // use the global tokenValue array
        for (uint256 i = 0; i < NUM_TOKEN_VALUES && _amount > 0; i++) {
            uint256 _tokenValue = tokenValue[i];
            uint256 quantityOwned = _idsOwnedByValue[_burner][_tokenValue].length;
            // Calculate tokens of this denomination to burn
            uint256 tokensOfValueToBurn = _amount / _tokenValue;

            if (quantityOwned > 0 && tokensOfValueToBurn > 0) {
                uint256 tokensToActuallyBurn = (tokensOfValueToBurn > quantityOwned) 
                    ? quantityOwned : tokensOfValueToBurn;
                _withdrawAndStoreERC721_(_burner, _tokenValue, tokensToActuallyBurn);
                // Update the remaining amount of tokens to burn
                _amount -= tokensToActuallyBurn * _tokenValue;
            }
        }
    }

/*

///include new mapping logic
    function _setOwnerOf(uint256 id_, address owner_) internal virtual {
        uint256 data = _ownedData[id_];

        assembly {
        data := add(
            and(data, _BITMASK_OWNED_INDEX),
            and(owner_, _BITMASK_ADDRESS)
        )
        }

    _ownedData[id_] = data;
  }

 */
/*

// include new mapping logic
  function _getOwnedIndex(
    uint256 id_
  ) internal view virtual returns (uint256 ownedIndex_) {
    uint256 data = _ownedData[id_];

    assembly {
      ownedIndex_ := shr(160, data)
    }
  }

*/

/*
///@todo include new mapping logic
  function _setOwnedIndex(uint256 id_, uint256 index_) internal virtual {
    uint256 data = _ownedData[id_];

    if (index_ > _BITMASK_OWNED_INDEX >> 160) {
      revert OwnedIndexOverflow();
    }

    assembly {
      data := add(
        and(data, _BITMASK_ADDRESS),
        and(shl(160, index_), _BITMASK_OWNED_INDEX)
      )
    }

    _ownedData[id_] = data;
  }
}
*/

}

