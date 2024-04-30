//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";
import {ERC404} from "./ERC404.sol";
import {ERC1155Events} from "./lib/ERC1155Events.sol";
import {ERC721Events} from "./lib/ERC721Events.sol";
import {ERC20Events} from "./lib/ERC20Events.sol";
import {ERC404ERC1155Extension} from "./extensions/ERC404ERC1155Extension.sol";
import {ERC404UniswapV3Exempt} from "./extensions/ERC404UniswapV3Exempt.sol";

contract Marlboro is Ownable, ERC404, ERC404ERC1155Extension /* ERC404UniswapV3Exempt */{

    // For batch operations on SFTs
    using Arrays for uint256[];
    using Arrays for address[];
    
    /// @dev set token values constant for efficiency
    uint256 private constant MARLBORO_MEN = 600;
    uint256 private constant CARTONS = 200;
    uint256 private constant PACKS = 20;
    uint256 private constant LOOSIES = 1;
    /// @dev Does not include Marlboro Men, since this value is used to calculate SFTs.
    uint256 private constant NUM_TOKEN_VALUES = 3;

    /// @notice tokenValues is an index of token values
    /// @dev token value index needs to be in descending order, largest to smallest for calculations to work
    uint256[NUM_TOKEN_VALUES] public tokenValues = [
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
        address initialMintRecipient_
     //   address uniswapSwapRouter_
      //  address uniswapV3NonfungiblePositionManager_
    ) 
        ERC404(name_, symbol_, decimals_) 
        Ownable(initialOwner_) 
        ERC404ERC1155Extension()
     /*   ERC404UniswapV3Exempt(
            uniswapSwapRouter_,
            uniswapV3NonfungiblePositionManager_ 
        )  */
    {
        // Do not mint the ERC721s to the initial owner, as it's a waste of gas.
        _setERC721TransferExempt(initialMintRecipient_, true);
        _mintERC20(initialMintRecipient_, maxTotalSupplyERC721_ * units);
    }

    function setERC721TransferExempt(
        address account_,
        bool value_
    ) external onlyOwner {
        _setERC721TransferExempt(account_, value_);
    }


    /// @dev override set approval for all from ERC404 to include ERC1155Event
    /// @notice Function for ERC-721 and ERC1155 approvals
    function setApprovalForAll(
        address operator_,
        bool approved_
    ) public override(ERC404, IERC404ERC1155Extension) {
        // Prevent approvals to 0x0.
        if (operator_ == address(0)) {
            revert InvalidOperator();
        }
        isApprovedForAll[msg.sender][operator_] = approved_;
        emit ERC721Events.ApprovalForAll(msg.sender, operator_, approved_);
        emit ERC1155Events.ApprovalForAll(msg.sender, operator_, approved_);
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
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override {
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

    /// @notice function to transfer ERC1155s of a given id
    /// @dev transfers ERC20 value of sfts without handling ERC721 

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public override {
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll[from][msg.sender]) {
            revert InvalidOperator();
        }
        

        _safeTransferFrom(from, to, id, value, data);

         // Calculate ERC20 value of sfts being transferred and bypass ERC721 transfer path
        // So that the SFTs are not implicitly converted to NFTs
        uint256 amount = id * value * units;
        _transferERC20(from, to, amount);
    }

      /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public override {
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll[from][sender]) {
            revert("Missing approvals");
        }
        _safeBatchTransferFrom(from, to, ids, values, data);
        
        uint256 amount = _sumProductsOfArrayValues(ids, values);
        uint256 amountUnits = amount * units;
        _transferERC20(from, to, amountUnits);
    }


    function tokenURI(uint256 id_) public view override(ERC404, IERC404ERC1155Extension) returns (string memory) {
        require(_isValidTokenId(id_), "Invalid token ID");

        // Determine if it's a NFT or SFT based on prefix
        if (id_ > ID_ENCODING_PREFIX) {
            // Handling NFTs
            return _handleNFTURI(id_);
        } else {
            // Handling SFTs
            return _handleSFTURI(id_);
        }
    }


    function _handleNFTURI(uint256 id_) private view returns (string memory) {
        string memory baseURI = "https://example.com/nfts/";
        return string(abi.encodePacked(baseURI, Strings.toString(id_), ".json"));
    }

    function _handleSFTURI(uint256 id_) private view returns (string memory) {
        string memory baseURI;
        if (id_ == LOOSIES) {
            baseURI = "https://example.com/loosies/";
        } else if (id_ == PACKS) {
            baseURI = "https://example.com/packs/";
        } else if (id_ == CARTONS) {
            baseURI = "https://example.com/cartons/";
        } else {
            revert("Invalid SFT ID");
        }

        return string(abi.encodePacked(baseURI, Strings.toString(id_), ".json"));
    }


    function _sumProductsOfArrayValues(uint256[] memory ids, uint256[] memory values) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < ids.length; ) {
            result += ids[i] * values[i];
        unchecked {
                ++i;
            }
        }
        return result;
    }


    /// @notice Function for self-exemption
    function setSelfERC721TransferExempt(bool state_) public override {
        _setERC721TransferExempt(msg.sender, state_);
    }

/*
    /// @notice Function for mixed transfers from an operator that may be different than 'from'.
    /// @dev This function checks token prefix to determine whether transfer token is ERC721
    ///       
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
 */   
    
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
        uint256 erc20Value = units * MARLBORO_MEN;
        _transferERC20(from_, to_, erc20Value);
        _transferERC721(from_, to_, id_);
// In this context there is no need to handle SFT transfers, since the transfer of a single NFT
// is inherently an "exact change" transfer
//        _transferERC1155(from_, to_, erc20Value);
    }


    function _transferERC1155(address from_, address to_, uint256 units_) internal {
        // Update ERC1155 balances based on unit value transfered
        (uint256[] memory values_, uint256[] memory ids_) = calculateTokens(units_);

        _updateWithAcceptanceCheck(from_, to_, ids_, values_, "");
    }
  /*  
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
            

            // send ERC1155s from zero address
       //     _transferERC1155(address(0), to_, sftsToRetrieveOrMint);


              // Only cares about whole number increments.
            uint256 nftsToRetrieveOrMint = ((balanceOf[to_] / units) -
                (erc20BalanceOfReceiverBefore / units)) / 
                    MARLBORO_MEN;


            for (uint256 i = 0; i < nftsToRetrieveOrMint; ) {
                _retrieveOrMintERC721(to_);
                unchecked {
                    ++i;
                }
            }
            
            if (nftsToRetrieveOrMint % MARLBORO_MEN != 0) {
            // Update receiver's ERC1155 balances
            _updateERC1155Balances(to_);
            }
        } else if (isToERC721TransferExempt) {
            // Case 3) The sender is not ERC-721 transfer exempt, but the recipient is. Contract should attempt
            //         to withdraw and store ERC-721s from the sender, but the recipient should not
            //         receive ERC-721s from the bank/minted.
            // Only cares about whole number increments.
            

            uint256 nftsToWithdrawAndStore = ((erc20BalanceOfSenderBefore /
                units) - (balanceOf[from_] / units)) /
                    MARLBORO_MEN;

           
            for (uint256 i = 0; i < nftsToWithdrawAndStore; ) {
                _withdrawAndStoreERC721(from_);
                unchecked {
                    ++i;
                }
            }
            
            if (nftsToWithdrawAndStore % MARLBORO_MEN != 0) {
            // Update receiver's ERC1155 balances
            _updateERC1155Balances(from_);
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
            uint256 nftsToTransfer = value_ / units / MARLBORO_MEN;
            
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
            // If the sender's transaction changes their holding from a fractional to a non-fractional
            // amount (or vice versa), adjust ERC-721s.
            //
            // Check if the send causes the sender to lose a whole token that was represented by an ERC-721
            // due to a fractional part being transferred.

            if (
                erc20BalanceOfSenderBefore /
                    (units * MARLBORO_MEN) -
                    erc20BalanceOf(from_) /
                    (units * MARLBORO_MEN) >
                nftsToTransfer
            ) {
                // Burn a Marlboro Man
                _withdrawAndStoreERC721(from_);
            }

            if (   
                erc20BalanceOf(to_) /
                    (units * MARLBORO_MEN) -
                    erc20BalanceOfReceiverBefore /
                    (units * MARLBORO_MEN) >
                nftsToTransfer
            ) {
                // Gain a Marlboro Man
                _retrieveOrMintERC721(to_);
            }
            // Update sender's ERC1155 balances
            _updateERC1155Balances(from_);

            // Update receiver's ERC1155 balances
            _updateERC1155Balances(to_);
        }

        return true;
    }

    /// @notice function to update sfts balances for an account
    /// @dev skips the _update function and calculateTokens logic used
    ///     for direct sft transfers, to save gas

    function _updateERC1155Balances(address account) private {
        uint256 units_ = erc20BalanceOf(account) / units;
        uint256 remainder = units_ % MARLBORO_MEN;
            uint256 cartons = remainder / CARTONS;
            remainder = remainder % CARTONS;
            uint256 packs = remainder / PACKS;
            remainder = remainder % PACKS;
            uint256 loosies = remainder / LOOSIES;

            // Update account balances
            _balances[CARTONS][account] = cartons;
            _balances[PACKS][account] = packs;
            _balances[LOOSIES][account] = loosies;

    } 
    

    /// @dev takes a quantity of units and builds a list of tokens to mint for each value
    /// @param _units are whole ERC20s to calculate from
    function calculateTokens(
        uint256 _units
    ) internal view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory sftsToRetrieveOrMint = new uint256[](NUM_TOKEN_VALUES);
        uint256[] memory tokenValuesFiltered = new uint256[](NUM_TOKEN_VALUES);
        uint256 remainingUnits = _units % MARLBORO_MEN;
        uint256 count = 0;

        // Calculate the number of units to retrieve or mint for each token value
        for (uint256 i = 0; i < NUM_TOKEN_VALUES; ++i) {
            uint256 amount = remainingUnits / tokenValues[i];
            if (amount > 0) {
                sftsToRetrieveOrMint[count] = amount;
                tokenValuesFiltered[count] = tokenValues[i];
                ++count;
            }
            remainingUnits %= tokenValues[i];
        }

        // Resize arrays to match the count of non-zero entries
        uint256[] memory finalNfts = new uint256[](count);
        uint256[] memory finalTokenValues = new uint256[](count);
        for (uint256 i = 0; i < count; ++i) {
            finalNfts[i] = sftsToRetrieveOrMint[i];
            finalTokenValues[i] = tokenValuesFiltered[i];
        }

        return (finalNfts, finalTokenValues);
    }


        function mintERC20(address account_, uint256 value_) external onlyOwner {
            _mintERC20(account_, value_);
    }




} 