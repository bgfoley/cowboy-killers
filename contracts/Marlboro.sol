// MARLBORO
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {PackedDoubleEndedQueue} from "./lib/PackedDoubleEndedQueue.sol";
import {ERC404} from "./ERC404.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ERC721Events} from "./lib/ERC721Events.sol";
import {ERC20Events} from "./lib/ERC20Events.sol";
import {ERC1155Events} from "./lib/ERC1155Events.sol";





contract ERC4041155 is Ownable, ERC404 {
    using PackedDoubleEndedQueue for PackedDoubleEndedQueue.Uint16Deque;

    /// @dev The queue of ERC-721 tokens stored in the contract.
    PackedDoubleEndedQueue.Uint16Deque private _storedERC721Ids;
    
    using Strings for uint256;

    // For batch operations on SFTs
    using Arrays for uint256[];
    using Arrays for address[];

    // Mappings for SFTs (like ERC1155)
    mapping(uint256 id => mapping(address account => uint256)) private _balances;

    // Approvals for SFTs
    mapping(address account => mapping(address operator => bool)) private _operatorApprovals;
    
    /// @dev for assigning sequential IDs for each value 
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
    //     IUniswapV2Router02 uniswapV2RouterContract = IUniswapV2Router02(
    //        uniswapV2Router_
    //    );

        
        // Do not mint the ERC721s to the initial owner, as it's a waste of gas.
        _setERC721TransferExempt(initialMintRecipient_, true);
        _setERC721TransferExempt(uniswapV2Router_, true);
          // Determine the Uniswap v2 pair address for this token.
   //    address uniswapV2Pair = _getUniswapV2Pair(
  //       uniswapV2RouterContract.factory(),
   //         uniswapV2RouterContract.WETH()
  //      );

        // Set the Uniswap v2 pair as exempt.
   //     _setERC721TransferExempt(uniswapV2Pair, true);

        _mintERC20(initialMintRecipient_, maxTotalSupplyERC721_ * units);
    }
/*
    
     //@dev See {IERC165-supportsInterface}.
  
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }
*/
/*
    function uri(uint256 ) public view virtual returns (string memory) {
        return _uri;
    }
*/
      /**
     * @dev See {IERC1155-balanceOf}. added Id
     */
    function getBalanceOf(address account, uint256 id) public view returns (uint256) {
        return _balances[id][account];
    }

     /// erc1155BalanceOf or balanceOfId
    function erc1155BalanceOf(
        address owner_,
        uint256 id_
    ) public view returns (uint256) {
        return getBalanceOf(owner_, id_);
    }


/**
     * @dev Transfers a `value` amount of tokens of type `id` from `from` to `to`. Will mint (or burn) if `from`
     * (or `to`) is the zero address.
     *
     * Emits a {TransferSingle} event if the arrays contain one element, and {TransferBatch} otherwise.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement either {IERC1155Receiver-onERC1155Received}
     *   or {IERC1155Receiver-onERC1155BatchReceived} and return the acceptance magic value.
     * - `ids` and `values` must have the same length.
     *
     * NOTE: The ERC-1155 acceptance check is not performed in this function. See {_updateWithAcceptanceCheck} instead.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal {
        if (ids.length != values.length) {
            revert("Array lengths do not match");
        }

        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids.unsafeMemoryAccess(i);
            uint256 value = values.unsafeMemoryAccess(i);

            if (from != address(0)) {
                uint256 fromBalance = _balances[id][from];
                if (fromBalance < value) {
                    revert("Insufficient balance");
                }
                unchecked {
                    // Overflow not possible: value <= fromBalance
                    _balances[id][from] = fromBalance - value;
                }
            }

            if (to != address(0)) {
                _balances[id][to] += value;
            }
        }

        if (ids.length == 1) {
            uint256 id = ids.unsafeMemoryAccess(0);
            uint256 value = values.unsafeMemoryAccess(0);
            emit ERC1155Events.TransferSingle(operator, from, to, id, value);
        } else {
            emit ERC1155Events.TransferBatch(operator, from, to, ids, values);
        }
    }

      /**
     * @dev Version of {_update} that performs the token acceptance check by calling
     * {IERC1155Receiver-onERC1155Received} or {IERC1155Receiver-onERC1155BatchReceived} on the receiver address if it
     * contains code (eg. is a smart contract at the moment of execution).
     *
     * IMPORTANT: Overriding this function is discouraged because it poses a reentrancy risk from the receiver. So any
     * update to the contract state after this function would break the check-effect-interaction pattern. Consider
     * overriding {_update} instead.
     */
    function _updateWithAcceptanceCheck(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal virtual {
        _update(from, to, ids, values);
        if (to != address(0)) {
            address operator = _msgSender();
            if (ids.length == 1) {
                uint256 id = ids.unsafeMemoryAccess(0);
                uint256 value = values.unsafeMemoryAccess(0);
                _doSafeTransferAcceptanceCheck(operator, from, to, id, value, data);
            } else {
                _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, values, data);
            }
        }
    }

     /**
     * @dev Creates a `value` amount of tokens of type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(address to, uint256 id, uint256 value, bytes memory data) internal {
        if (to == address(0)) {
            revert("Cannot mint to zero address");
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(address(0), to, ids, values, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `values` must have the same length.
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory values, bytes memory data) internal {
        if (to == address(0)) {
            revert("Cannot mint to zero address");
        }
        _updateWithAcceptanceCheck(address(0), to, ids, values, data);
    }

     /**
     * @dev Destroys a `value` amount of tokens of type `id` from `from`
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `value` amount of tokens of type `id`.
     */
    function _burn(address from, uint256 id, uint256 value) internal {
        if (from == address(0)) {
            revert("Cannot burn from zero address");
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(from, address(0), ids, values, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `value` amount of tokens of type `id`.
     * - `ids` and `values` must have the same length.
     */
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory values) internal {
        if (from == address(0)) {
            revert("Cannot mint to zero address");
        }
        _updateWithAcceptanceCheck(from, address(0), ids, values, "");
    }

  //  function erc1155Approve(address spender_, uint256 id_)

      /**
     * @dev Performs an acceptance check by calling {IERC1155-onERC1155Received} on the `to` address
     * if it contains code at the moment of execution.
     */
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, value, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    // Tokens rejected
                    revert ("Invalid receiver");
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert ("Invalid receiver");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev Performs a batch acceptance check by calling {IERC1155-onERC1155BatchReceived} on the `to` address
     * if it contains code at the moment of execution.
     */
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, values, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    // Tokens rejected
                    revert ("Invalid receiver");
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    // non-ERC1155Receiver implementer
                    revert ("Invalid receiver");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }
    
      /**
     * @dev Creates an array in memory with only one value for each of the elements provided.
     */
    function _asSingletonArrays(
        uint256 element1,
        uint256 element2
    ) private pure returns (uint256[] memory array1, uint256[] memory array2) {
        /// @solidity memory-safe-assembly
        assembly {
            // Load the free memory pointer
            array1 := mload(0x40)
            // Set array length to 1
            mstore(array1, 1)
            // Store the single element at the next word after the length (where content starts)
            mstore(add(array1, 0x20), element1)

            // Repeat for next array locating it right after the first array
            array2 := add(array1, 0x40)
            mstore(array2, 1)
            mstore(add(array2, 0x20), element2)

            // Update the free memory pointer by pointing after the second array
            mstore(0x40, add(array2, 0x40))
        }
    }

    /// @notice internal Function for safe transfer of erc1155 tokens 
    
    /// @dev override original erc1155 function to include updates to erc20 balance

    function _safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) internal {
        if (to == address(0)) {
            revert ("Invalid receiver");
        }
        if (from == address(0)) {
            revert ("Invalid sender");
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(from, to, ids, values, data);

        // ERC20 and ERC721 Transfer logic included here
        uint256 amount = id * value;
        _transferERC20WithERC721(from, to, amount);
    }



     /**
        * @notice for safe transfer of erc1155 tokens with data argument 
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public {
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll[from][msg.sender]) {
            revert ("MIssing approval for all");
        }

        _safeTransferFrom(from, to, id, value, data);
    }

    


    function _sumProduct(uint256[] memory ids, uint256[] memory values) external pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < ids.length; ) {
            result += ids[i] * values[i];
        unchecked {
                ++i;
            }
        }
        return result;
    }



     /// @notice Function for ERC-721 approvals - override to include event for ERC1155 approvals
    function setApprovalForAll(
        address operator_,
        bool approved_
    ) public override {
        // Prevent approvals to 0x0.
        if (operator_ == address(0)) {
            revert InvalidOperator();
        }
        isApprovedForAll[msg.sender][operator_] = approved_;
        emit ERC721Events.ApprovalForAll(msg.sender, operator_, approved_);
        emit ERC1155Events.ApprovalForAll(msg.sender, operator_, approved_);
    }

/*

    function erc721TotalSupply() public view override returns (uint256) {
        uint256 erc721Supply = 0;
        unchecked {
            for (uint256 i = 0; i < NUM_TOKEN_VALUES; i++) {
                erc721Supply += _mintedOfValue[tokenValues[i]];
            }
        }
        return erc721Supply;
    }

 */   


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

     /// @notice Function for mixed transfers from an operator that may be different than 'from'.
    /// @dev This function assumes the operator is attempting to transfer an ERC-721
    ///      if valueOrId is less than or equal to current max id.
    function transferFrom(
        address from_,
        address to_,
        uint256 valueOrId_
    ) public override returns (bool) {
        if (_isValidTokenId(valueOrId_)) {
            erc721TransferFrom(from_, to_, valueOrId_);
        } else {
            // Intention is to transfer as ERC-20 token (value).
            return erc20TransferFrom(from_, to_, valueOrId_);
        }

        return true;
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
        _transferERC1155(from_, to_, erc20Value);
    }
    
    function _transferERC1155(address from_, address to_, uint256 amount_) internal {
        // Update ERC1155 balances based on unit value transfered
        (uint256[] memory values_, uint256[] memory ids_) = calculateTokens(amount_);

        _updateWithAcceptanceCheck(from_, to_, ids_, values_, "");
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
            
            // send 1155s from zero address
            _transferERC1155(address(0), to_, value_);
           
            // Only cares about whole number increments.
            uint256 tokensToRetrieveOrMint = (balanceOf[to_] / units * MARLBORO_MEN) -
                (erc20BalanceOfReceiverBefore / units * MARLBORO_MEN);
            for (uint256 i = 0; i < tokensToRetrieveOrMint; ) {
                _retrieveOrMintERC721(to_);
                unchecked {
                    ++i;
                }
            }
        } else if (isToERC721TransferExempt) {
            // Case 3) The sender is not ERC-721 transfer exempt, but the recipient is. Contract should attempt
            //         to withdraw and store ERC-721s from the sender, but the recipient should not
            //         receive ERC-721s from the bank/minted.
            // Only cares about whole number increments.
            // send 1155s to zero address
            _transferERC1155(from_, address(0), value_);

            uint256 tokensToWithdrawAndStore = (erc20BalanceOfSenderBefore /
                units * MARLBORO_MEN) - (balanceOf[from_] / units * MARLBORO_MEN);
            for (uint256 i = 0; i < tokensToWithdrawAndStore; ) {
                _withdrawAndStoreERC721(from_);
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
            // send 1155s to zero address
            _transferERC1155(from_, to_, value_);

            // Whole tokens worth of ERC-20s get transferred as ERC-721s without any burning/minting.
            uint256 nftsToTransfer = value_ / units * MARLBORO_MEN;
            for (uint256 i = 0; i < nftsToTransfer; ) {
                // Pop from sender's ERC-721 stack and transfer them (LIFO)
                uint256 indexOfLastToken = _owned[from_].length - 1;
                uint256 tokenId = ID_ENCODING_PREFIX +
                    _owned[from_][indexOfLastToken];
                _transferERC721(from_, to_, tokenId);
                unchecked {
                    ++i;
                }
            }
/// need to swap out units for 600 units for this one
            // If the sender's transaction changes their holding from a fractional to a non-fractional
            // amount (or vice versa), adjust ERC-721s.
            //
            // Check if the send causes the sender to lose a whole token that was represented by an ERC-721
            // due to a fractional part being transferred.
            if (
                erc20BalanceOfSenderBefore /
                    units * MARLBORO_MEN -
                    erc20BalanceOf(from_) /
                    units * MARLBORO_MEN >
                nftsToTransfer
            ) {
                _withdrawAndStoreERC721(from_);
            }

            if (
                erc20BalanceOf(to_) /
                    units * MARLBORO_MEN -
                    erc20BalanceOfReceiverBefore /
                    units * MARLBORO_MEN >
                nftsToTransfer
            ) {
                _retrieveOrMintERC721(to_);
            }
        }

        return true;
    }

/*
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
                for (uint256 j = 0; j < tokensToMove; ) {
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
*/
/*


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

*/
   /*             
             
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
*/

/*
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

*/
/*
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

*/
/*
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
*/

    /// @dev takes a quantity of units and builds a list of tokens to mint for each value
    /// @param _units are whole ERC20s to calculate from
    function calculateTokens(
        uint256 _units
    ) internal view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory nftsToRetrieveOrMint = new uint256[](NUM_TOKEN_VALUES);
        uint256[] memory tokenValuesFiltered = new uint256[](NUM_TOKEN_VALUES);
        uint256 remainingUnits = _units;
        uint256 count = 0;

        // Calculate the number of units to retrieve or mint for each token value
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; ++i) {
            uint256 amount = remainingUnits / tokenValues[i];
            if (amount > 0) {
                nftsToRetrieveOrMint[count] = amount;
                tokenValuesFiltered[count] = tokenValues[i];
                ++count;
            }
            remainingUnits %= tokenValues[i];
        }

        // Resize arrays to match the count of non-zero entries
        uint256[] memory finalNfts = new uint256[](count);
        uint256[] memory finalTokenValues = new uint256[](count);
        for (uint256 i = 0; i < count; ++i) {
            finalNfts[i] = nftsToRetrieveOrMint[i];
            finalTokenValues[i] = tokenValuesFiltered[i];
        }

        return (finalNfts, finalTokenValues);
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

