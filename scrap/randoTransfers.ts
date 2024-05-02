import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract } from "ethers";

describe("Cowboy Contract", function () {
  async function deployCowboyFixture() {
    const signers = await ethers.getSigners();
    const factory = await ethers.getContractFactory("ERC404TVExtNew");

    const name = "Example";
    const symbol = "EX-A";
    const decimals = 18n
    const units = 10n ** decimals
    const maxTotalSupplyERC721 = 100n
    const maxTotalSupplyERC20 = maxTotalSupplyERC721 * units
    const initialOwner = signers[0]
    const initialMintRecipient = signers[0]
    const uniswapV2Router = signers[0]
    

   

    const contract: Contract = await factory.deploy(
      name,
      symbol,
      decimals,
      maxTotalSupplyERC721,
      maxTotalSupplyERC20,
      initialOwner.address,
      initialOwner.address,
      uniswapV2Router.address
    );
    await contract.waitForDeployment()
    const contractAddress = await contract.getAddress()

    // Generate 10 random addresses for experiments.
    const randomAddresses = Array.from(
      { length: 10 },
      () => ethers.Wallet.createRandom().address,
    )

    const transferAmounts = [1n, 55n, 425n, 69727n]

    return {
      contract,
      contractAddress,
      signers,
      deployConfig: {
        name,
        symbol,
        decimals,
        units,
        maxTotalSupplyERC721,
        maxTotalSupplyERC20,
        initialOwner,
        initialMintRecipient,
        uniswapV2Router,
     //   idPrefix,
      },
      randomAddresses,
      transferAmounts,
      

    }
  }
  it("should handle a bunch of transfers and log gas usage", async function () {
    const { contract, signers, randomAddresses, transferAmounts } = await deployCowboyFixture();

    // Initial mint to the owner assuming mintERC20 is the correct minting function
    await contract.mintERC20(signers[0].address, maxTotalSupplyERC20);

    for (const amount of transferAmounts) {
      const fromSigner = signers[0];
      const toAddress = randomAddresses[Math.floor(Math.random() * randomAddresses.length)];

      const tx = await contract.connect(fromSigner).transfer(toAddress, amount);
      const receipt = await tx.wait();
      console.log(`Transferred ${amount.toString()} tokens to ${toAddress} - Gas Used: ${receipt.gasUsed.toString()}`);
    }
  });
});
