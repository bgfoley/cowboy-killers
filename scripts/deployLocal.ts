// Import ethers from Hardhat package
const { ethers } = require("hardhat");

async function main() {
    // Get signers
    const [deployer] = await ethers.getSigners();

    // Contract constructor arguments
    const name = "Example";
    const symbol = "EX-A";
    const decimals = 18;
    const units = BigInt(10) ** BigInt(decimals);
    const maxTotalSupplyERC721 = 100n;
    const maxTotalSupplyERC20 = maxTotalSupplyERC721 * units;
    // Assuming the deployer is the initialOwner, initialMintRecipient, and uniswapV2Router for this example
    const initialOwner = deployer.address;
    const initialMintRecipient = deployer.address;
    const uniswapV2Router = deployer.address; // Adjust this as necessary for your actual deployment

    // ID Prefix, adjust as necessary
    const idPrefix = 57896044618658097711785492504343953926634992332820282019728792003956564819968n;

    // Deploy the contract
    console.log("Deploying contract...");
    const ERC404TVExt = await ethers.getContractFactory("ERC404TVExt", deployer);
    const contract = await ERC404TVExt.deploy(
      name,
      symbol,
      decimals,
      maxTotalSupplyERC721,
      initialOwner,
      initialMintRecipient,
      uniswapV2Router
    );

    await contract.deployed();
    console.log("Contract deployed to:", contract.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
