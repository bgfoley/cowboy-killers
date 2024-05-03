// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
interface IERC404ERC1155Extension is IERC165 {

    error ERC1155MissingApprovalForAll();
    error ERC1155InvalidReceiver();
    error ERC1155InvalidSender();
    error ERC1155InvalidArrayLength();
    error ERC1155InsufficientBalance();

    // Function Signatures
    
    function getBalanceOf(address account, uint256 id) external view returns (uint256);
 //   function setApprovalForAll(address operator, bool approved) external;
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external;
    function tokenURI(uint256 id) external view returns (string memory);
}
