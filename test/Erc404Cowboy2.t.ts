import { expect } from "chai"
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers"
import { ethers } from "hardhat"

describe("ERC404UniswapV2Exempt", function () {
  async function deployERC404ExampleUniswapV2() {
    const signers = await ethers.getSigners()

    // Deploy Uniswap v2 factory.
    const uniswapV2FactorySource = require("@uniswap/v2-core/build/UniswapV2Factory.json")
    const uniswapV2FactoryContract = await new ethers.ContractFactory(
      uniswapV2FactorySource.interface,
      uniswapV2FactorySource.bytecode,
      signers[0],
    ).deploy(signers[0].address)
    await uniswapV2FactoryContract.waitForDeployment()

    // Deploy WETH.
    const wethSource = require("@uniswap/v2-periphery/build/WETH9.json")
    const wethContract = await new ethers.ContractFactory(
      wethSource.interface,
      wethSource.bytecode,
      signers[0],
    ).deploy()
    await wethContract.waitForDeployment()

    // Deploy Uniswap v2 router.
    const uniswapV2RouterSource = require("@uniswap/v2-periphery/build/UniswapV2Router02.json")
    const uniswapV2RouterContract = await new ethers.ContractFactory(
      uniswapV2RouterSource.interface,
      uniswapV2RouterSource.bytecode,
      signers[0],
    ).deploy(
      await uniswapV2FactoryContract.getAddress(),
      await wethContract.getAddress(),
    )
    await uniswapV2RouterContract.waitForDeployment()

    // Deploy the token with UniswapV2Router address as a constructor argument.
    const factory = await ethers.getContractFactory("Cowboy")
    const contract = await factory.deploy(
        await uniswapV2RouterContract.getAddress()
    )

    await contract.waitForDeployment()
    const contractAddress = await contract.getAddress()

    return {
      contract,
      contractAddress,
      signers,
      uniswapV2RouterContract,
      uniswapV2FactoryContract,
      wethContract,
    }
  }

  describe("#constructor", function () {
    it("Adds the UniswapV2Router02 to the ERC-721 transfer exempt list", async function () {
      const f = await loadFixture(deployERC404ExampleUniswapV2)

      const uniswapV2RouterContractAddress =
        await f.uniswapV2RouterContract.getAddress()

      expect(uniswapV2RouterContractAddress).to.not.eq(ethers.constants.AddressZero)

      expect(
        await f.contract.erc721TransferExempt(uniswapV2RouterContractAddress),
      ).to.equal(true)
    })

    it("Adds the Uniswap v2 Pair address for this token + WETH to the ERC-721 transfer exempt list", async function () {
      const f = await loadFixture(deployERC404ExampleUniswapV2)

      // Create the pair using the Uniswap v2 factory.
      await f.uniswapV2FactoryContract.createPair(
        f.contractAddress,
        await f.wethContract.getAddress(),
      )

      const expectedPairAddress =
        await f.uniswapV2FactoryContract.getPair(
          f.contractAddress,
          await f.wethContract.getAddress(),
        )

      // Pair address is not 0x0.
      expect(expectedPairAddress).to.not.eq(ethers.constants.AddressZero)

      expect(
        await f.contract.erc721TransferExempt(expectedPairAddress),
      ).to.equal(true)
    })
  })
})
