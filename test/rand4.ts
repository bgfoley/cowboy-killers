import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract } from "ethers";

describe("Cowboy Contract", function () {
  async function deployCowboyFixture() {
    console.log("Getting signers...");
    const signers = await ethers.getSigners();
    console.log("Retrieved signers.");

    console.log("Fetching contract factory...");
    const factory = await ethers.getContractFactory("ERC404TVExtNew");
    console.log("Factory fetched.");

    const name = "Example";
    const symbol = "EX-A";
    const decimals = 18n; // Using BigInt directly as per your original script
    const units = 10n ** decimals;
    const maxTotalSupplyERC721 = 100000n;
    const maxTotalSupplyERC20 = maxTotalSupplyERC721 * units;
    const initialOwner = signers[0];
    const initialMintRecipient = signers[0];
    const uniswapV2Router = signers[0];

    console.log("Deploying contract...");
    const contract: Contract = await factory.deploy(
      name,
      symbol,
      decimals,
      maxTotalSupplyERC721,
      initialOwner.address,
      initialMintRecipient.address,
      uniswapV2Router.address
    );
    console.log("Contract deployed. Waiting for it to be mined...");
    await contract.waitForDeployment()
    console.log("Contract mined.");

    //const contractAddress = await contract.getAddress()
  //  console.log("Getting contract address.");

    console.log("Generating random addresses...");
    const randomAddresses = Array.from(
      { length: 10 },
      () => ethers.Wallet.createRandom().address,
    );
    console.log("Random addresses generated.");

    const transferAmounts = [1n, 55n, 425n, 69727n]; // Original BigInt amounts

    return {
      contract,
      contractAddress: contract.address,
      signers,
      deployConfig: {
        name,
        symbol,
        decimals,
        units,
        maxTotalSupplyERC721,
        initialOwner,
        initialMintRecipient,
        uniswapV2Router,
      },
      randomAddresses,
      transferAmounts,
      maxTotalSupplyERC20,
    }
  }

  it("should handle a bunch of transfers and log gas usage", async function () {
    console.log("Deploying and setting up contract...");
    const { contract, signers, maxTotalSupplyERC20 } = await deployCowboyFixture();

    console.log("Minting ERC20 tokens to the owner...", maxTotalSupplyERC20);
    await contract.mintERC20(signers[0].address, maxTotalSupplyERC20.toString());
    console.log("Tokens minted.");

    // Transfer to all other signers, random amounts
    for (let i = 1; i < signers.length; i++) {  // Starting from 1 to skip the owner
      const randomAmount = ethers.parseUnits((Math.floor(Math.random() * 100) + 1).toString(), 18); // Random amount between 1 and 100 tokens
      const toAddress = signers[i].address;

      console.log(`Initiating transfer of ${randomAmount.toString()} tokens to ${toAddress}...`);
      const tx = await contract.connect(signers[0]).transfer(toAddress, randomAmount);
      const receipt = await tx.wait();
      console.log(`Transferred ${randomAmount.toString()} tokens to ${toAddress} - Gas Used: ${receipt.gasUsed.toString()}`);
    }
  });
});
