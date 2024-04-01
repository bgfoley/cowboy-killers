import fs from 'fs';
import path from 'path';

// Adjust these paths according to your project structure
const abiPath = path.join(__dirname, '../artifacts/contracts/Cowboy.sol/Cowboy.json');
const outputPath = path.join(__dirname, '../test/generatedTests.2.ts');

// Load ABI from compiled contract JSON
const abi = JSON.parse(fs.readFileSync(abiPath, 'utf8')).abi;

// Function to filter public and external functions
const isPublicOrExternal = (abiItem: any) => 
    (abiItem.type === 'function' && (abiItem.stateMutability === 'nonpayable' || abiItem.stateMutability === 'view' || abiItem.stateMutability === 'pure')) &&
    (abiItem.stateMutability !== 'internal');

// Start test file content
let testFileContent = `import { expect } from "chai";
import { ethers } from "hardhat";

describe("Cowboy Contract", function () {\n`;

// Generate test for each external or public function
abi.filter(isPublicOrExternal).forEach((func: any) => {
    testFileContent += `  it("${func.name}", async function () {
    // Add your test logic here
    console.log("Testing function: ${func.name}");
  });\n`;
});

testFileContent += '});\n';

// Write the test file
fs.writeFileSync(outputPath, testFileContent);
console.log(`Test skeleton generated at: ${outputPath}`);
