import { expect } from "chai"
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers"
import { ethers, network } from "hardhat"

describe("Cowboy Contract", function () {
  async function deployCowboy() {
    const signers = await ethers.getSigners()
    const factory = await ethers.getContractFactory("Cowboy")

    const name = "Example"
    const symbol = "EX-A"
    const decimals = 18n
    const units = 10n ** decimals
    const maxTotalSupplyERC721 = 1000n
    const maxTotalSupplyERC20 = maxTotalSupplyERC721 * units
    const initialOwner = signers[0]
    const initialMintRecipient = signers[0]
    const uniswapV2Router = signers[0]
    const idPrefix =
      57896044618658097711785492504343953926634992332820282019728792003956564819968n

    const contract = await factory.deploy(
      name,
      symbol,
      decimals,
      maxTotalSupplyERC721,
      initialOwner.address,
      initialMintRecipient.address,
      uniswapV2Router
    )
    await contract.waitForDeployment()
    const contractAddress = await contract.getAddress()

    // Generate 10 random addresses for experiments.
    const randomAddresses = Array.from(
      { length: 10 },
      () => ethers.Wallet.createRandom().address,
    )

    const transferAmounts = [19n, 55n, 219n, 857n]

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
        idPrefix,
      },
      randomAddresses,

    }
  }

  async function getPermitSignature(
    contractAddress: string,
    msgSender: any,
    spender: any,
    value: bigint,
    nonce: bigint,
    deadline: bigint,
  ) {
    const domain = {
      name: "Example",
      version: "1",
      chainId: network.config.chainId as number,
      verifyingContract: contractAddress,
    }

    const types = {
      Permit: [
        {
          name: "owner",
          type: "address",
        },
        {
          name: "spender",
          type: "address",
        },
        {
          name: "value",
          type: "uint256",
        },
        {
          name: "nonce",
          type: "uint256",
        },
        {
          name: "deadline",
          type: "uint256",
        },
      ],
    }

    // set the Permit type values
    const values = {
      owner: msgSender.address,
      spender: spender,
      value: value,
      nonce: nonce,
      deadline: deadline,
    }

    // sign the Permit type data with the deployer's private key
    const signature = await msgSender.signTypedData(domain, types, values)

    // split the signature into its components
    return ethers.Signature.from(signature)
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



  async function deployMinimalERC404WithERC20sAndERC721sMinted() {
    const f = await loadFixture(deployCowboy)

    // Mint the full supply of ERC20 tokens (with the corresponding ERC721 tokens minted as well)
    await f.contract
      .connect(f.signers[0])
      .mintERC20(
        f.deployConfig.initialMintRecipient.address,
        f.deployConfig.maxTotalSupplyERC20,
      )

    return f
  }

  async function deployMockContractsForERC721Receiver() {
    const mockValidERC721ReceiverFactory = await ethers.getContractFactory(
      "MockValidERC721Receiver",
    )

    const mockValidERC721Receiver =
      await mockValidERC721ReceiverFactory.deploy()
    await mockValidERC721Receiver.waitForDeployment()

    const mockInvalidERC721ReceiverFactory = await ethers.getContractFactory(
      "MockInvalidERC721Receiver",
    )

    const mockInvalidERC721Receiver =
      await mockInvalidERC721ReceiverFactory.deploy()
    await mockInvalidERC721Receiver.waitForDeployment()

    return {
      mockValidERC721Receiver,
      mockInvalidERC721Receiver,
    }
  }

  async function deployMinimalERC404ForHavingAlreadyGrantedApprovalForAllTests() {
    const f = await loadFixture(deployMinimalERC404WithERC20sAndERC721sMinted)

    const msgSender = f.signers[0]
    const intendedOperator = f.signers[1]
    const secondOperator = f.signers[2]

    // Add an approved for all operator for msgSender
    await f.contract
      .connect(msgSender)
      .setApprovalForAll(intendedOperator.address, true)

    return {
      ...f,
      msgSender,
      intendedOperator,
      secondOperator,
    }
  }

  async function deployERC404ExampleWithTokensInSecondSigner() {
    const f = await loadFixture(deployCowboy)
    const from = f.signers[1]
    const to = f.signers[2]

    // Start off with 100 full tokens.
    const initialExperimentBalanceERC721 = 100n
    const initialExperimentBalanceERC20 =
      initialExperimentBalanceERC721 * f.deployConfig.units

    const balancesBeforeSigner0 = await getBalances(
      f.contract,
      f.signers[0].address,
    )
    const balancesBeforeSigner1 = await getBalances(
      f.contract,
      f.signers[1].address,
    )

    // console.log("balancesBeforeSigner0", balancesBeforeSigner0)
    // console.log("balancesBeforeSigner1", balancesBeforeSigner1)

    // Add the owner to the exemption list
    await f.contract
      .connect(f.signers[0])
      .setERC721TransferExempt(f.signers[0].address, true)

    // Transfer all tokens from the owner to 'from', who is the initial sender for the tests.
    await f.contract
      .connect(f.signers[0])
      .transfer(from.address, initialExperimentBalanceERC20)

    return {
      ...f,
      initialExperimentBalanceERC20,
      initialExperimentBalanceERC721,
      from,
      to,
    }
  }


  async function deployERC404ExampleWithSomeTokensTransferredToRandomAddress() {
    const f = await loadFixture(deployCowboy)

    const targetAddress = f.randomAddresses[0]

    // Transfer some tokens to a non-exempted wallet to generate the NFTs.
    await f.contract
      .connect(f.signers[0])
      .transfer(targetAddress, 25n * f.deployConfig.units)

    expect(await f.contract.erc721TotalSupply()).to.equal(6n)

    return {
      ...f,
      targetAddress,
    }
  }

  async function getBalances(contract: any, address: string) {
    return {
      erc20: await contract.erc20BalanceOf(address),
      erc721: await contract.erc721BalanceOf(address),
    }
  }


  function containsERC721TransferEvent(
    logs: any[],
    from: string,
    to: string,
    id: bigint,
  ) {
    for (const log of logs) {
      if (log.topics.length == 4) {
        if (
          log.topics[0] ==
            "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" &&
          log.topics[1] ==
            "0x000000000000000000000000" +
              from.substring(2, from.length).toLowerCase() &&
          log.topics[2] ==
            "0x000000000000000000000000" +
              to.substring(2, to.length).toLowerCase() &&
          log.topics[3] == "0x" + id.toString(16)
        ) {
          return true
        }
      }
    }

    return false
  }

  function containsERC721ApprovalEvent(
    logs: any[],
    owner: string,
    spender: string,
    id: bigint,
  ) {
    for (const log of logs) {
      if (log.topics.length == 4) {
        if (
          log.topics[0] ==
            "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925" &&
          log.topics[1] ==
            "0x000000000000000000000000" +
              owner.substring(2, owner.length).toLowerCase() &&
          log.topics[2] ==
            "0x000000000000000000000000" +
              spender.substring(2, spender.length).toLowerCase() &&
          log.topics[3] == "0x" + id.toString(16)
        ) {
          return true
        }
      }
    }

    return false
  }

  describe("#constructor", function () {
    it("Initializes the contract with the expected values", async function () {
      const f = await loadFixture(deployCowboy)

      expect(await f.contract.name()).to.equal(f.deployConfig.name)
      expect(await f.contract.symbol()).to.equal(f.deployConfig.symbol)
      expect(await f.contract.decimals()).to.equal(f.deployConfig.decimals)
      expect(await f.contract.owner()).to.equal(
        f.deployConfig.initialOwner.address,
      )
    })

    it("Mints the initial supply of tokens to the initial mint recipient", async function () {
      const f = await loadFixture(deployCowboy)

      // Expect full supply of ERC20 tokens to be minted to the initial recipient.
      expect(
        await f.contract.erc20BalanceOf(
          f.deployConfig.initialMintRecipient.address,
        ),
      ).to.equal(f.deployConfig.maxTotalSupplyERC20)
      // Expect 0 ERC721 tokens to be minted to the initial recipient, since 1) the user is on the exemption list and 2) the supply is minted using _mintERC20 with mintCorrespondingERC721s_ set to false.
      expect(
        await f.contract.erc721BalanceOf(
          f.deployConfig.initialMintRecipient.address,
        ),
      ).to.equal(0n)

      // NFT minted count should be 0.
      expect(await f.contract.erc721TotalSupply()).to.equal(0n)

      // Total supply of ERC20s tokens should be equal to the initial mint recipient's balance.
      expect(await f.contract.totalSupply()).to.equal(
        f.deployConfig.maxTotalSupplyERC20,
      )
    })

    it("Initializes the exemption list with the initial mint recipient", async function () {
      const f = await loadFixture(deployCowboy)

      expect(
        await f.contract.erc721TransferExempt(
          f.deployConfig.initialMintRecipient.address,
        ),
      ).to.equal(true)
    })
  })

  describe("#erc20TotalSupply", function () {
    it("Returns the correct total supply", async function () {
      const f = await loadFixture(
        deployERC404ExampleWithSomeTokensTransferredToRandomAddress,
      )

      expect(await f.contract.erc20TotalSupply()).to.eq(
        1000n * f.deployConfig.units,
      )
    })
  })

  describe("#erc721TotalSupply", function () {
    it("Returns the correct total supply", async function () {
      const f = await loadFixture(
        deployERC404ExampleWithSomeTokensTransferredToRandomAddress,
      )

      expect(await f.contract.erc721TotalSupply()).to.eq(6n)
    })
  })

  describe("#ownerOf", function () {
    context("Some tokens have been minted", function () {
      it("Reverts if the token ID is below the allowed range", async function () {
        const f = await loadFixture(
          deployERC404ExampleWithSomeTokensTransferredToRandomAddress,
        )

        const minimumValidTokenId = (await f.contract.ID_ENCODING_PREFIX()) + 1n

        expect(await f.contract.ownerOf(minimumValidTokenId)).to.eq(
          f.targetAddress,
        )

        await expect(
          f.contract.ownerOf(minimumValidTokenId - 1n),
        ).to.be.revertedWithCustomError(f.contract, "InvalidTokenId")
      })

      it("Reverts if the token ID is within the range of valid Ids, but is above 'minted', the max valid minted id", async function () {
        const f = await loadFixture(
          deployERC404ExampleWithSomeTokensTransferredToRandomAddress,
        )

        const minted = await f.contract.minted()

        const mintedWithPrefix =
          (await f.contract.ID_ENCODING_PREFIX()) + minted

        expect(await f.contract.ownerOf(mintedWithPrefix)).to.eq(
          f.targetAddress,
        )

        await expect(
          f.contract.ownerOf(mintedWithPrefix + 1n),
        ).to.be.revertedWithCustomError(f.contract, "NotFound")
      })

      it("Reverts when for id = MAX_INT", async function () {
        const f = await loadFixture(
          deployERC404ExampleWithSomeTokensTransferredToRandomAddress,
        )

        const maxId = 2n ** 256n - 1n

        await expect(f.contract.ownerOf(maxId)).to.be.revertedWithCustomError(
          f.contract,
          "InvalidTokenId",
        )
      })

      it("Returns the address of the owner of the token", async function () {
        const f = await loadFixture(
          deployERC404ExampleWithSomeTokensTransferredToRandomAddress,
        )

        // Transferred 5 full tokens from a exempted address to the target address (not exempted), which minted the first 5 NFTs.

        // Expect the owner of the token to be the recipient
        for (let i = 1n; i <= 5n; i++) {
          expect(
            await f.contract.ownerOf(f.deployConfig.idPrefix + i),
          ).to.equal(f.targetAddress)
        }
      })
    })
  })

    
    describe("Storage and retrieval of unused ERC721s on contract", function () {
        it("Mints ERC721s from 0x0 when the contract's bank is empty", async function () {
          const f = await loadFixture(deployCowboy)
    
          // Total supply should be 0
          expect(await f.contract.erc721TotalSupply()).to.equal(0n)
    
          // Expect the contract's bank to be empty
          expect(await f.contract.balanceOf(f.contractAddress)).to.equal(0n)
          expect(await f.contract.getERC721QueueLength()).to.equal(0n)
    
          const nftQty = 10n
          const value = nftQty * f.deployConfig.units
    
          // Mint 10 ERC721s
          const mintTx = await f.contract
            .connect(f.signers[0])
            .mintERC20(f.signers[1].address, value)
    
          const receipt = await mintTx.wait()
    
          // Check for ERC721Transfer mint events (from 0x0 to the recipient)
          for (let i = 1n; i <= nftQty; i++) {
            expect(
              containsERC721TransferEvent(
                receipt.logs,
                ethers.ZeroAddress,
                f.signers[1].address,
                f.deployConfig.idPrefix + i,
              ),
            ).to.eq(true)
          }
    
          // Check for ERC20Transfer mint events (from 0x0 to the recipient)
          await expect(mintTx)
            .to.emit(f.contract, "Transfer")
            .withArgs(ethers.ZeroAddress, f.signers[1].address, value)
    
          // 10 NFTs should have been minted
          expect(await f.contract.erc721TotalSupply()).to.equal(10n)
    
          // Expect the recipient to have 10 NFTs
          expect(await f.contract.erc721BalanceOf(f.signers[1].address)).to.equal(
            10n,
          )
        })
    
        it("Stores ERC721s in contract's bank when a sender loses a full token", async function () {
          const f = await loadFixture(deployCowboy)
    
          // Total supply should be 0
          expect(await f.contract.erc721TotalSupply()).to.equal(0n)
    
          // Expect the contract's bank to be empty
          expect(await f.contract.balanceOf(f.contractAddress)).to.equal(0n)
          expect(await f.contract.getERC721QueueLength()).to.equal(0n)
    
          const nftQty = 10n
          const value = nftQty * f.deployConfig.units
    
          await f.contract
            .connect(f.signers[0])
            .mintERC20(f.signers[1].address, value)
    
          expect(await f.contract.erc721TotalSupply()).to.equal(10n)
    
          // Expect the contract's bank to be empty
          expect(await f.contract.balanceOf(f.contractAddress)).to.equal(0n)
          expect(await f.contract.getERC721QueueLength()).to.equal(0n)
    
          // Move a fraction of a token to another address to break apart a full NFT.
    
          const fractionalValueToTransferERC20 = f.deployConfig.units / 10n // 0.1 tokens
          const fractionalTransferTx = await f.contract
            .connect(f.signers[1])
            .transfer(f.signers[2].address, fractionalValueToTransferERC20)
    
          await expect(fractionalTransferTx)
            .to.emit(f.contract, "Transfer")
            .withArgs(
              f.signers[1].address,
              f.signers[2].address,
              fractionalValueToTransferERC20,
            )
    
          // Expect token id 10 to be transferred to the contract's address (popping the last NFT from the sender's stack)
          await expect(
            containsERC721TransferEvent(
              (await fractionalTransferTx.wait()).logs,
              f.signers[1].address,
              ethers.ZeroAddress,
              f.deployConfig.idPrefix + 10n,
            ),
          ).to.eq(true)
    
          // 10 tokens still minted, nothing changes there.
          expect(await f.contract.erc721TotalSupply()).to.equal(10n)
    
          // The owner of NFT 10 should be the 0x0
          await expect(
            f.contract.ownerOf(f.deployConfig.idPrefix + 10n),
          ).to.be.revertedWithCustomError(f.contract, "NotFound")
    
          // The sender's NFT balance should be 9
          expect(await f.contract.erc721BalanceOf(f.signers[1].address)).to.equal(
            9n,
          )
    
          // The contract's balance is still 0
          expect(await f.contract.balanceOf(f.contractAddress)).to.equal(0n)
          // The contract's bank to contain 1 NFT
          expect(await f.contract.getERC721QueueLength()).to.equal(1n)
        })
    
        it("Retrieves ERC721s from the contract's bank when the contract's bank holds NFTs and the user regains a full token", async function () {
          const f = await loadFixture(deployCowboy)
    
          expect(await f.contract.erc721TotalSupply()).to.equal(0n)
    
          const nftQty = 10n
          const erc20Value = nftQty * f.deployConfig.units
    
          await f.contract
            .connect(f.signers[0])
            .mintERC20(f.signers[1].address, erc20Value)
    
          expect(await f.contract.erc721TotalSupply()).to.equal(10n)
    
          // Move a fraction of a token to another address to break apart a full NFT.
          const fractionalValueToTransferERC20 = f.deployConfig.units / 10n // 0.1 tokens
    
          await f.contract
            .connect(f.signers[1])
            .transfer(f.signers[2].address, fractionalValueToTransferERC20)
    
          // The owner of NFT 10 should be the contract's address
          await expect(
            f.contract.ownerOf(f.deployConfig.idPrefix + 10n),
          ).to.be.revertedWithCustomError(f.contract, "NotFound")
    
          // The sender's NFT balance should be 9
          expect(await f.contract.erc721BalanceOf(f.signers[1].address)).to.equal(
            9n,
          )
    
          // The contract's NFT balance should be 0
          expect(await f.contract.erc721BalanceOf(f.contractAddress)).to.equal(0n)
          // The contract's bank should contain 1 NFTs
          expect(await f.contract.getERC721QueueLength()).to.equal(1n)
    
          // Transfer the fractional portion needed to regain a full token back to the original sender
          const regainFullTokenTx = await f.contract
            .connect(f.signers[2])
            .transfer(f.signers[1].address, fractionalValueToTransferERC20)
    
          expect(regainFullTokenTx)
            .to.emit(f.contract, "Transfer")
            .withArgs(
              f.signers[2].address,
              f.signers[1].address,
              fractionalValueToTransferERC20,
            )
          expect(regainFullTokenTx)
            .to.emit(f.contract, "Transfer")
            .withArgs(
              ethers.ZeroAddress,
              f.signers[1].address,
              f.deployConfig.idPrefix + 9n,
            )
    
          // Original sender's ERC20 balance should be 10 * units
          expect(await f.contract.erc20BalanceOf(f.signers[1].address)).to.equal(
            erc20Value,
          )
    
          // The owner of NFT 9 should be the original sender's address
          expect(await f.contract.ownerOf(f.deployConfig.idPrefix + 10n)).to.equal(
            f.signers[1].address,
          )
    
          // The sender's NFT balance should be 10
          expect(await f.contract.erc721BalanceOf(f.signers[1].address)).to.equal(
            10n,
          )
    
          // The contract's NFT balance should be 0
          expect(await f.contract.erc721BalanceOf(f.contractAddress)).to.equal(0n)
          // The contract's bank should contain 0 NFTs
          expect(await f.contract.getERC721QueueLength()).to.equal(0n)
        })
      })

  })


