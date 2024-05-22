import { expect } from "chai"
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers"
import { ethers, network } from "hardhat"

describe("ERC404", function () {
  async function deployERC404Example() {
    const signers = await ethers.getSigners()
    const factory = await ethers.getContractFactory("MarlboroU16")

    const name = "Example"
    const symbol = "EX-A"
    const decimals = 18n
    const units = 10n ** decimals
    const maxTotalSupplyERC721 = 100n
    const maxTotalSupplyERC20 = maxTotalSupplyERC721 * units
    const initialOwner = signers[0]
    const initialMintRecipient = signers[0]
    const cartons = units / 5n
    const packs = cartons / 10n
    const loosies = packs / 20n

    const contract = await factory.deploy(
      name,
      symbol,
      decimals,
      maxTotalSupplyERC721,
      initialOwner.address,
      initialMintRecipient.address,
    )
    await contract.waitForDeployment()
    const contractAddress = await contract.getAddress()

    // Generate 10 random addresses for experiments.
    const randomAddresses = Array.from(
      { length: 10 },
      () => ethers.Wallet.createRandom().address,
    )

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
        units,
        cartons,
        packs,
        loosies,
      },
      randomAddresses,
    }
  }


  async function getSigners() {
    const signers = await ethers.getSigners()

    return {
      bob: signers[0],
      alice: signers[1],
      jason: signers[2],
      patty: signers[3],
      linda: signers[4],
      larry: signers[5],
      tom: signers[6],
      adam: signers[7],
      julie: signers[8],
      robert: signers[9],
      amy: signers[10],
      ...signers,
    }
  }

  
    describe("safeTransferFrom tests", function () {
      it("should revert if isApprovedForAll is false and the caller is not the owner", async function () {
      const f = await loadFixture(deployERC404Example)
        
        const contract = await f.contract;
        const from = await f.signers[1].getAddress();
        const to = await f.signers[2].getAddress();
        const id =  f.deployConfig.cartons; // Using a constant value for ID
     
  
        // Mint tokens to the first signer before transfer
        await contract.mintERC20(from, id);
  
        // Try to make the transfer from a user who is not approved
        await expect(contract.connect(to).safeTransferFrom(from, to, id, value, "0x"))
          .to.be.revertedWith("InvalidOperator");
      });
  
      it("should succeed when called by the owner", async function () {
        const from = await owner.getAddress();
        const to = await randomUser.getAddress();
        const id = _CARTONS;  // Using a constant value for ID
        const value = 5;  // Number of tokens being transferred
  
        // Mint tokens to the owner before transfer
        await contract.mint(from, id, value, "0x");
  
        // Owner making the transfer
        await expect(contract.connect(owner).safeTransferFrom(from, to, id, value, "0x"))
          .to.emit(contract, "TransferSingle").withArgs(owner, from, to, id, value);
  
        // Check balance of ERC20 tokens transferred
        const expectedERC20Transfer = id * value * unitSize_;
        expect(await contract.balanceOf(to)).to.equal(expectedERC20Transfer);
      });
  
      it("should transfer the correct number of ERC20 tokens", async function () {
        const from = await owner.getAddress();
        const to = await randomUser.getAddress();
        const id = _CARTONS;  // Using a constant value for ID
        const value = 5;  // Number of tokens being transferred
  
        // Mint tokens to the owner before transfer
        await contract.mint(from, id, value, "0x");
  
        // Check ERC20 balance before transfer
        const initialBalance = await contract.balanceOf(to);
  
        // Owner making the transfer
        await contract.connect(owner).safeTransferFrom(from, to, id, value, "0x");
  
        // Calculate expected ERC20 transfer
        const expectedERC20Transfer = id * value * unitSize_;
        const finalBalance = await contract.balanceOf(to);
        expect(finalBalance.sub(initialBalance)).to.equal(expectedERC20Transfer);
      });
    });
