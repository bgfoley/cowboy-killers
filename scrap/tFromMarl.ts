import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract } from "ethers";

describe("Cowboy Contract", function () {
  async function deployCowboyFixture() {
    console.log("Getting signers...");
    const signers = await ethers.getSigners();
    console.log("Retrieved signers.");

    console.log("Fetching contract factory...");
    const factory = await ethers.getContractFactory("Marlboro");
    console.log("Factory fetched.");

    const name = "Example";
    const symbol = "EX-A";
    const decimals = 18n; // Using BigInt directly as per your original script
    const units = 10n ** decimals;
    const maxTotalSupplyERC721 = 600000n;
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


    return {
        contract,
        signers,
        maxTotalSupplyERC20,
      };
    }
  
    // Utility function to log gas usage
    const logGasUsage = async (transactionPromise: Promise<any>, description: string) => {
      const txResponse = await transactionPromise;
      const txReceipt = await txResponse.wait();
      console.log(`${description} - Gas Used: ${txReceipt.gasUsed.toString()}`);
    };
  
    it("should handle approvals and transferFrom with gas logging", async function () {
      const { contract, signers, maxTotalSupplyERC20 } = await deployCowboyFixture();
      const [owner, addr1, addr2, addr3, addr4] = signers;
  
      await contract.mintERC20(owner.address, maxTotalSupplyERC20.toString());
  
      // Owner approves addr1, addr2, addr3, and addr4 respectively
      await logGasUsage(contract.connect(owner).approve(addr1.address, ethers.parseUnits("1200", 18)), "Owner approves Addr1");
      await logGasUsage(contract.connect(owner).approve(addr2.address, ethers.parseUnits("649", 18)), "Owner approves Addr2");
      await logGasUsage(contract.connect(owner).approve(addr3.address, ethers.parseUnits("200", 18)), "Owner approves Addr3");
      await logGasUsage(contract.connect(owner).approve(addr4.address, ethers.parseUnits("297", 18)), "Owner approves Addr4");
  
      // Each address calls transferFrom owner in the amount they were approved for
      await logGasUsage(contract.connect(addr1).transferFrom(owner.address, addr1.address, ethers.parseUnits("1200", 18)), "Addr1 transfers from Owner");
      await logGasUsage(contract.connect(addr2).transferFrom(owner.address, addr2.address, ethers.parseUnits("649", 18)), "Addr2 transfers from Owner");
      await logGasUsage(contract.connect(addr3).transferFrom(owner.address, addr3.address, ethers.parseUnits("200", 18)), "Addr3 transfers from Owner");
      await logGasUsage(contract.connect(addr4).transferFrom(owner.address, addr4.address, ethers.parseUnits("297", 18)), "Addr4 transfers from Owner");
  
      // Each address approves the owner for half the original amount they were sent
      await logGasUsage(contract.connect(addr1).approve(owner.address, ethers.parseUnits("600", 18)), "Addr1 re-approves Owner");
      await logGasUsage(contract.connect(addr2).approve(owner.address, ethers.parseUnits("325", 18)), "Addr2 re-approves Owner");
      await logGasUsage(contract.connect(addr3).approve(owner.address, ethers.parseUnits("100", 18)), "Addr3 re-approves Owner");
      await logGasUsage(contract.connect(addr4).approve(owner.address, ethers.parseUnits("145", 18)), "Addr4 re-approves Owner");
  
      console.log(`Balance of Addr1 before transferring back: ${await contract.balanceOf(addr1.address)}`);
      console.log(`Balance of Addr2 before transferring back: ${await contract.balanceOf(addr2.address)}`);
      console.log(`Balance of Addr3 before transferring back: ${await contract.balanceOf(addr3.address)}`);
      console.log(`Balance of Addr4 before transferring back: ${await contract.balanceOf(addr4.address)}`);
      
      // The owner calls transferFrom in the amount each address is approved for
      await logGasUsage(contract.connect(owner).transferFrom(addr1.address, owner.address, ethers.parseUnits("600", 18)), "Owner transfers from Addr1");
      await logGasUsage(contract.connect(owner).transferFrom(addr2.address, owner.address, ethers.parseUnits("325", 18)), "Owner transfers from Addr2");
      await logGasUsage(contract.connect(owner).transferFrom(addr3.address, owner.address, ethers.parseUnits("100", 18)), "Owner transfers from Addr3");
      await logGasUsage(contract.connect(owner).transferFrom(addr4.address, owner.address, ethers.parseUnits("145", 18)), "Owner transfers from Addr4");
    });
  });
  