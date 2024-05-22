// Importing the required dependencies from Hardhat.
const { ethers } = require("hardhat");

async function main() {
    // Retrieve the contract factory for the MarlboroU16S contract.
    const MarlboroU16S = await ethers.getContractFactory("MarlboroU16S");

    // Deploy the contract.
    console.log("Deploying MarlboroU16S...");
    const marlboroU16S = await MarlboroU16S.deploy();

    // Wait for the deployment to be confirmed.
    await marlboroU16S.deployed();
    console.log(`MarlboroU16S deployed to: ${marlboroU16S.address}`);

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
