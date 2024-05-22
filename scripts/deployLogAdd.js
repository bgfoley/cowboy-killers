// Importing the required dependencies from Hardhat.
const { ethers } = require("hardhat");

async function main() {
    const uniswapV3Router = 0x89031Ff7240456b4997e367b48eDED3415606e0D;
    
    // Retrieve the contract factory for the MarlboroU16S contract.
    const MarlboroU16S = await ethers.getContractFactory("MarlboroU16S");

    // Deploy the contract.
    console.log("Deploying MarlboroU16S...");
    const marlboroU16S = await MarlboroU16S.deploy();

    // Wait for the deployment to be confirmed.
    await marlboroU16S.waitForDeployment();
    const contractAddress = await marlboroU16S.getAddress()
    console.log(`MarlboroU16S deployed to: ${contractAddress}`);

    // Retrieve Uniswap V3 pair addresses for each fee tier.
    console.log("Fetching Uniswap V3 Pair Addresses for each fee tier...");
    const pairAddresses = await marlboroU16S.getUniswapV3Pairs(uniswapV3Router);

    // Log each address with its corresponding fee tier.
    console.log("Uniswap V3 Pair Addresses:");
    const fees = [0.01, 0.05, 0.3, 1];  // Fee tiers in percentages for clarity
    pairAddresses.forEach((address, index) => {
        console.log(`Fee ${fees[index]}%: ${address}`);
    });

    // Optionally, you can perform additional setup such as setting token URIs or other state variables here.
    // For example:
    // const tokenURISetupTx = await marlboroU16S.setTokenURI("https://yourdomain.com/api/");
    // await tokenURISetupTx.wait();
    // console.log("Token URI is set.");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
});
