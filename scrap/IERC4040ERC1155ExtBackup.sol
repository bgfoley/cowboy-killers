// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
interface IERC404ERC1155Extension is IERC165 {

//    error InvalidOperator();
//    error InvalidRecipient();
//    error InvalidSender();
    error ERC1155MissingApprovalForAll(address operator, address from);
    error ERC1155InvalidReceiver(address receiver);
    error ERC1155InvalidSender(address sender);
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
    error ERC1155InsufficientBalance(address account, uint256 currentBalance, uint256 requiredBalance, uint256 id);

    // Function Signatures
    function getBalanceOf(address account, uint256 id) external view returns (uint256);
    function setApprovalForAll(address operator, bool approved) external;
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external;
    function tokenURI(uint256 id) external view returns (string memory);
}
