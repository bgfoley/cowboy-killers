//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC404U16} from "../ERC404U16.sol";
import {ERC404U16ERC1155Extension} from "../extensions/ERC404U16ERC1155Extension.sol";
import {ERC404UniswapV3Exempt} from "../extensions/ERC404UniswapV3Exempt.sol";

contract MinimalMarlboroU16BigUnits is
    Ownable,
    ERC404U16,
    ERC404U16ERC1155Extension
   // ERC404U16UniswapV3Exempt
{

    /// @dev base token URI
    string private baseURI;
    
    /// @dev set token values constant for efficiency
    /// NFTs represented as native units 
    uint256 private constant _MARLBORO_MEN = 1000 * 10 ** 18;
    
    // ERC1155 token values in ERC20 representation for updating ERC1155 balances
    uint256 private constant _CARTONS = _MARLBORO_MEN / 5; // 5 Cartons per Marlboro Man
    uint256 private constant _PACKS = _CARTONS / 10; // 10 Packs per Carton
    uint256 private constant _LOOSIES = _PACKS / 20; // 20 Cigarettes per Pack

    // ERC1155 token IDs stored by the number of cigarettes represented per token
    uint256 private constant CARTONS = 200;
    uint256 private constant PACKS = 20;
    uint256 private constant LOOSIES = 1;

    string private constant NAME = "Marlbro";
    string private constant SYMBOL = "MBRO";
    uint8 private constant DECIMALS = 18;
    
    uint256 private MAX_TOTAL_SUPPLY_ERC721 = 1000;
    // Arbitrum sepolia
    address private UNISWAP_SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private NON_FUNGIBLE_POSITION_MANAGER = 0x6b2937Bde17889EDCf8fbD8dE31C3C2a70Bc4d65; 


    /// @notice tokenValues is an index of token values
    /// @dev token value index needs to be in descending order, largest to smallest for calculations to work
    uint256[3] public tokenValues = [_CARTONS, _PACKS, _LOOSIES];

    constructor()
        ERC404U16(NAME, SYMBOL, DECIMALS)
        Ownable(msg.sender)
        ERC404U16ERC1155Extension()
    /*    ERC404U16UniswapV3Exempt(
            UNISWAP_SWAP_ROUTER,
            NON_FUNGIBLE_POSITION_MANAGER 
        )  */
    {
        // Do not mint the ERC721s to the initial owner, as it's a waste of gas.
        _setERC721TransferExempt(owner(), true);
        _mintERC20(owner(), MAX_TOTAL_SUPPLY_ERC721 * units);
    }


    function setERC721TransferExempt(
        address account_,
        bool value_
    ) external onlyOwner {
        _setERC721TransferExempt(account_, value_);
    }

   

    /// @notice function to transfer ERC1155s of a given id
    /// @dev transfers ERC20 value of ERC1155s without handling ERC721

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public override {
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll[from][msg.sender]) {
            revert InvalidOperator();
        }

        _safeTransferFrom(from, to, id, value, data);

        // Calculate ERC20 value of ERC1155s being transferred and bypass ERC721 transfer path
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
            revert ERC1155MissingApprovalForAll();
        }
        _safeBatchTransferFrom(from, to, ids, values, data);

        uint256 amount = _sumProductsOfArrayValues(ids, values);
        uint256 amountUnits = amount * units;
        _transferERC20(from, to, amountUnits);
    }


    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseURI = _tokenURI;
    }


    function tokenURI(
        uint256 id_
    ) public view override(ERC404U16, ERC404U16ERC1155Extension) returns (string memory) {
        // Check if the id is valid either as an NFT ID or an SFT ID
        if (!_isValidTokenId(id_) && !_isValidERC1155Id(id_)) {
            revert InvalidTokenId();
        }
        
        // Determine if it's a NFT or SFT based on prefix
        if (id_ > ID_ENCODING_PREFIX) {
            // Handling NFTs
            return _handleNFTURI(id_);
        } else {
            // Handling SFTs
            return _handleSFTURI(id_);
        }
    }


    function _isValidERC1155Id(uint256 id_) public pure returns (bool) {
        return id_ == LOOSIES || id_ == PACKS || id_ == CARTONS;
    }



    function _handleNFTURI(uint256 id_) private view returns (string memory) {
     //   string memory baseURI = "https://example.com/nfts/";
        uint256 adjustedId = id_ - ID_ENCODING_PREFIX;

        return string(abi.encodePacked(baseURI, Strings.toString(adjustedId), ".json"));
    }

    function _handleSFTURI(uint256 id_) private view returns (string memory) {

        return
            string(abi.encodePacked(baseURI, Strings.toString(id_), ".json"));
    }

    function _sumProductsOfArrayValues(
        uint256[] memory ids,
        uint256[] memory values
    ) internal view returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < ids.length; ) {
            result += tokenValues[i] * values[i];
            unchecked {
                ++i;
            }
        }
        return result;
    }



    /// @notice Initialization function to set pairs / etc, saving gas by avoiding mint / burn on unnecessary targets
    /// @dev clears or reinstates all NFT balances
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
            _clearERC721andERC1155Balances(target_);
        } else {
            _reinstateERC721andERC1155Balances(target_);
        }

        _erc721TransferExempt[target_] = state_;
    }


     /// @notice Function to reinstate ERC1155Balance
    function _reinstateERC721andERC1155Balances(address target_) private {
        _updateERC1155Balances(target_);
        uint256 expectedERC721Balance = erc20BalanceOf(target_) / units;
        uint256 actualERC721Balance = erc721BalanceOf(target_);

        for (uint256 i = 0; i < expectedERC721Balance - actualERC721Balance; ) {
            // Transfer ERC721 balance in from pool
            _retrieveOrMintERC721(target_);
            unchecked {
                ++i;
            }
        }
    }
    

    /// @notice Function to clear ERC1155Balance
    function _clearERC721andERC1155Balances(address target_) private {
        // clear ERC1155s
        _balances[CARTONS][target_] = 0;
        _balances[PACKS][target_] = 0;
        _balances[LOOSIES][target_] = 0;
        
        // clear ERC721s
        uint256 erc721Balance = erc721BalanceOf(target_);

        for (uint256 i = 0; i < erc721Balance; ) {
            // Transfer out ERC721 balance
            _withdrawAndStoreERC721(target_);
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
            uint256 nftsToRetrieveOrMint = (ERC404U16.erc20BalanceOf(to_) / units) -
                (erc20BalanceOfReceiverBefore / units);

            for (uint256 i = 0; i < nftsToRetrieveOrMint; ) {
                _retrieveOrMintERC721(to_);
                unchecked {
                    ++i;
                }
            }
            // Update receiver's ERC1155 balances
            _updateERC1155Balances(to_);
        
        } else if (isToERC721TransferExempt) {
            // Case 3) The sender is not ERC-721 transfer exempt, but the recipient is. Contract should attempt
            //         to withdraw and store ERC-721s from the sender, but the recipient should not
            //         receive ERC-721s from the bank/minted.
            // Only cares about whole number increments.

            uint256 nftsToWithdrawAndStore = (erc20BalanceOfSenderBefore /
                units) - (ERC404U16.erc20BalanceOf(from_) / units);

            for (uint256 i = 0; i < nftsToWithdrawAndStore; ) {
                _withdrawAndStoreERC721(from_);
                unchecked {
                    ++i;
                }
            }
            // Update receiver's ERC1155 balances
            _updateERC1155Balances(from_);
        
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
                    units -
                    erc20BalanceOf(from_) /
                    units >
                nftsToTransfer
            ) {
    
                _withdrawAndStoreERC721(from_);
            }

            if (
                erc20BalanceOf(to_) /
                    units -
                    erc20BalanceOfReceiverBefore /
                    units >
                nftsToTransfer
            ) {
                _retrieveOrMintERC721(to_);
            }
     
            // Update sender's ERC1155 balances
            _updateERC1155Balances(from_);

            // Update receiver's ERC1155 balances
            _updateERC1155Balances(to_);
        }

        return true;
    }

    /// @notice function to update ERC1155 balances for an account
    /// @dev skips the _update function and calculateTokens logic used
    ///     for direct ERC1155 transfers, to save gas

    function _updateERC1155Balances(address account) private {
        uint256 remainder = erc20BalanceOf(account) % _MARLBORO_MEN;
        uint256 cartons = remainder / _CARTONS;
        remainder = remainder % _CARTONS;
        uint256 packs = remainder / _PACKS;
        remainder = remainder % _PACKS;
        uint256 loosies = remainder / _LOOSIES;

        // Update account balances
        _balances[CARTONS][account] = cartons;
        _balances[PACKS][account] = packs;
        _balances[LOOSIES][account] = loosies;
    }


    function mintERC20(address account_, uint256 value_) external onlyOwner {
        _mintERC20(account_, value_);
    }

}
