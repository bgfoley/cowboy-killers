import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("ERC404", function () {
  async function deployERC404Example() {
    const signers = await ethers.getSigners();
    const factory = await ethers.getContractFactory("MarlboroU16");

    const name = "Example";
    const symbol = "EX-A";
    const decimals = 18;
    const units = 10n ** decimals
    const maxTotalSupplyERC721 = 100n;
    const maxTotalSupplyERC20 = maxTotalSupplyERC721 * units;
    const initialOwner = signers[0];
    const initialMintRecipient = signers[0];

    const contract = await factory.deploy(
      name,
      symbol,
      decimals,
      maxTotalSupplyERC721,
      initialOwner.address,
      initialMintRecipient.address
    );

    await contract.waitForDeployment()
    const contractAddress = await contract.getAddress()

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
        initialMintRecipient
      }
    };
  }

  describe("safeTransferFrom tests", function () {
    let contract: Contract;
    let owner: Signer;
    let randomUser: Signer;

    // Load fixtures and deploy contract before each test
    beforeEach(async function () {
      const fixture = await loadFixture(deployERC404Example);
      contract = fixture.contract;
      owner = fixture.signers[0];
      randomUser = fixture.signers[1];
    });

    it("should revert if isApprovedForAll is false and the caller is not the owner", async function () {
      const from = await owner.getAddress();
      const to = await randomUser.getAddress();
      const id = BigInt(10 ** 18);; // Assuming _CARTONS is defined elsewhere in your contract or test file
      const value = 5; // Number of tokens being transferred

      // Mint tokens to the owner before transfer
      await contract.mint(from, id, value, "0x");

      // Try to make the transfer from a user who is not approved
      await expect(contract.connect(randomUser).safeTransferFrom(from, to, id, value, "0x"))
        .to.be.revertedWith("InvalidOperator");
    });

    it("should succeed when called by the owner", async function () {
      const from = await owner.getAddress();
      const to = await randomUser.getAddress();
      const id = 5n; // Using a constant value for ID
      const value = 5; // Number of tokens being transferred

      // Mint tokens to the owner before transfer
      await contract.mint(from, id, value, "0x");

      // Owner making the transfer
      await expect(contract.connect(owner).safeTransferFrom(from, to, id, value, "0x"))
        .to.emit(contract, "TransferSingle").withArgs(owner.address, from, to, id, value);

      // Check balance of ERC20 tokens transferred
      const expectedERC20Transfer = BigInt(id * value) * BigInt(units); // Adjust units if necessary
      expect(await contract.balanceOf(to)).to.equal(expectedERC20Transfer);
    });

    it("should transfer the correct number of ERC20 tokens", async function () {
      const from = await owner.getAddress();
      const to = await randomUser.getAddress();
      const id = units / 10n; // Using a constant value for ID
      const value = 5; // Number of tokens being transferred

      // Mint tokens to the owner before transfer
      await contract.mint(from, id, value, "0x");

      // Check ERC20 balance before transfer
      const initialBalance = await contract.balanceOf(to);

      // Owner making the transfer
      await contract.connect(owner).safeTransferFrom(from, to, id, value, "0x");

      // Calculate expected ERC20 transfer
      const expectedERC20Transfer = BigInt(id * value) * BigInt(units);
      const finalBalance = await contract.balanceOf(to);
      expect(finalBalance.sub(initialBalance)).to.equal(expectedERC20Transfer);
    });
  });
});
