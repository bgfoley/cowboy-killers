// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC404 {
    // Events from ERC721Events and ERC20Events libraries
    event Transfer(address indexed from, address indexed to, uint256 valueOrId);
    event Approval(address indexed owner, address indexed spender, uint256 valueOrId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // Function declarations
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function units() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function minted() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function getApproved(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function ownerOf(uint256 tokenId) external view returns (address);
    function owned(address owner) external view returns (uint256[] memory);
    function erc721BalanceOf(address owner) external view returns (uint256);
    function erc20BalanceOf(address owner) external view returns (uint256);
    function erc20TotalSupply() external view returns (uint256);
    function erc721TotalSupply() external view returns (uint256);
    function getERC721QueueLength(uint256 value) external view returns (uint256);
    function getERC721TokensInQueue(uint256 start, uint256 count) external view returns (uint256[] memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function approve(address spender, uint256 valueOrId) external returns (bool);
    function setApprovalForAll(address operator, bool approved) external;
    function transferFrom(address from, address to, uint256 valueOrId) external returns (bool);
    function safeTransferFrom(address from, address to, uint256 id) external;
    function safeTransferFrom(address from, address to, uint256 id, bytes memory data) external;
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function setSelfERC721TransferExempt(bool state) external;
    function erc721TransferExempt(address target) external view returns (bool);
}
