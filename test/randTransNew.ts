import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract } from "ethers";

describe("Cowboy Contract", function () {
  async function deployCowboyFixture() {
    console.log("Getting signers...");
    const signers = await ethers.getSigners();
    console.log("Retrieved signers.");

    console.log("Fetching contract factory...");
    const factory = await ethers.getContractFactory("ERC4041155");
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

    console.log("Generating random addresses...");
    const randomAddresses = Array.from(
      { length: 10 },
      () => ethers.Wallet.createRandom().address,
    );
    console.log("Random addresses generated.");

    const transferAmounts = Array.from({ length: 50 }, (_, i) => ethers.parseUnits((i + 1527).toString(), 18));

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
    const { contract, signers, randomAddresses, transferAmounts, maxTotalSupplyERC20 } = await deployCowboyFixture();

    console.log("Minting ERC20 tokens to the owner...", maxTotalSupplyERC20.toString());
    await contract.mintERC20(signers[0].address, maxTotalSupplyERC20.toString());
    console.log("Tokens minted.");

    // Map to keep track of how much each address receives
    const balances = new Map<string, bigint>();

    // First, distribute tokens to random addresses from owner
    for (const amount of transferAmounts) {
      const fromSigner = signers[0];
      const toAddress = randomAddresses[Math.floor(Math.random() * randomAddresses.length)];

      console.log(`Initiating transfer of ${amount.toString()} tokens to ${toAddress}...`);
      const tx = await contract.connect(fromSigner).transfer(toAddress, amount);
      const receipt = await tx.wait();
      console.log(`Transferred ${amount.toString()} tokens to ${toAddress} - Gas Used: ${receipt.gasUsed.toString()}`);

      // Store the transfer amount to this address
      balances.set(toAddress, BigInt(amount.toString()));
    }

    // Then, make each recipient transfer a random part of their tokens to another random address
    for (const fromAddress of randomAddresses) {
      const recipientIndex = Math.floor(Math.random() * randomAddresses.length);
      // Ensure the recipient is not the same as the sender
      const toAddress = randomAddresses[recipientIndex] === fromAddress ? randomAddresses[(recipientIndex + 1) % randomAddresses.length] : randomAddresses[recipientIndex];

      // Retrieve the balance for this address, defaulting to zero if undefined
      const maxTransferAmount = balances.get(fromAddress) || BigInt(0);

      // Determine a random transfer amount that is less than the initial amount received
      const transferAmount = BigInt(Math.floor(Math.random() * Number(maxTransferAmount.toString()) * 0.5)); // up to 50% of the received amount

      console.log(`Initiating secondary transfer of ${transferAmount.toString()} tokens from ${fromAddress} to ${toAddress}...`);
      try {
        const tx = await contract.connect(signers.find(signer => signer.address === fromAddress)).transfer(toAddress, transferAmount);
        const receipt = await tx.wait();
        console.log(`Transferred ${transferAmount.toString()} tokens from ${fromAddress} to ${toAddress} - Gas Used: ${receipt.gasUsed.toString()}`);
      } catch (error) {
        console.error(`Failed to transfer from ${fromAddress} to ${toAddress}: ${error}`);
      }
    }
  });

  it("should transfer entire balance from initialMintRecipient to signers[1] and initiate transfers", async function () {
    console.log("Deploying and setting up contract...");
    const { contract, signers, randomAddresses, transferAmounts, maxTotalSupplyERC20 } = await deployCowboyFixture();

    console.log("Minting ERC20 tokens to the owner...", maxTotalSupplyERC20.toString());
    await contract.mintERC20(signers[0].address, maxTotalSupplyERC20.toString());
    console.log("Tokens minted.");

    console.log("Transferring entire balance from initialMintRecipient to signers[1]...");
    await contract.transfer(signers[1].address, maxTotalSupplyERC20.toString());

    // Now, signers[1] initiates transfers to random addresses
    console.log("Minting ERC20 tokens to signers[1]...", maxTotalSupplyERC20.toString());
    await contract.mintERC20(signers[1].address, maxTotalSupplyERC20.toString());
    console.log("Tokens minted.");

    // Map to keep track of how much each address receives
    const balances = new Map<string, bigint>();

    // First, distribute tokens to random addresses from signers[1]
    for (const amount of transferAmounts) {
      const fromSigner = signers[1];
      const toAddress = randomAddresses[Math.floor(Math.random() * randomAddresses.length)];

      console.log(`Initiating transfer of ${amount.toString()} tokens to ${toAddress}...`);
      const tx = await contract.connect(fromSigner).transfer(toAddress, amount);
      const receipt = await tx.wait();
      console.log(`Transferred ${amount.toString()} tokens to ${toAddress} - Gas Used: ${receipt.gasUsed.toString()}`);

      // Store the transfer amount to this address
      balances.set(toAddress, BigInt(amount.toString()));
    }

    // Then, make each recipient transfer a random part of their tokens to another random address
    for (const fromAddress of randomAddresses) {
      const recipientIndex = Math.floor(Math.random() * randomAddresses.length);
      // Ensure the recipient is not the same as the sender
      const toAddress = randomAddresses[recipientIndex] === fromAddress ? randomAddresses[(recipientIndex + 1) % randomAddresses.length] : randomAddresses[recipientIndex];

      // Retrieve the balance for this address, defaulting to zero if undefined
      const maxTransferAmount = balances.get(fromAddress) || BigInt(0);

      // Determine a random transfer amount that is less than the initial amount received
      const transferAmount = BigInt(Math.floor(Math.random() * Number(maxTransferAmount.toString()) * 0.5)); // up to 50% of the received amount

      console.log(`Initiating secondary transfer of ${transferAmount.toString()} tokens from ${fromAddress} to ${toAddress}...`);
      try {
        const tx = await contract.connect(signers.find(signer => signer.address === fromAddress)).transfer(toAddress, transferAmount);
        const receipt = await tx.wait();
        console.log(`Transferred ${transferAmount.toString()} tokens from ${fromAddress} to ${toAddress} - Gas Used: ${receipt.gasUsed.toString()}`);
      } catch (error) {
        console.error(`Failed to transfer from ${fromAddress} to ${toAddress}: ${error}`);
      }
    }
  });
});
