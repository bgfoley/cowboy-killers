const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('ERC1155', function () {
  let erc1155;
  let owner, addr1, addr2;
  let cartons, packs, loosies;
  let decimals

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    [cartons, packs, loosies] = [0, 1, 2];
    decimals = 10n ** 18n;
    const ERC1155 = await ethers.getContractFactory('MarlboroU16STest');
    erc1155 = await ERC1155.deploy();
    await erc1155.waitForDeployment();
  });

  describe('Updating ERC1155 balances', function () {
    it('Should mint tokens correctly to non-exempt addresses', async function () {
      await erc1155.mintERC20(addr1.address, (537));
      expect(await erc1155.getBalanceOf(addr1.address, loosies)).to.equal(17);
      expect(await erc1155.getBalanceOf(addr1.address, packs)).to.equal(6);
      expect(await erc1155.getBalanceOf(addr1.address, cartons)).to.equal(2);
    });

    it('Should not mint tokens to exempt addresses', async function () {
        await erc1155.mintERC20(owner.address, (215));
        expect(await erc1155.getBalanceOf(addr1.address, loosies)).to.equal(0);
        expect(await erc1155.getBalanceOf(addr1.address, packs)).to.equal(0);
        expect(await erc1155.getBalanceOf(addr1.address, cartons)).to.equal(0);
      });
    });

  describe('Approval', function () {
        it('Should set approval for all correctly', async function () {
          // Connect erc1155 to addr1 to send the transaction from addr1
          await erc1155.connect(addr1).setApprovalForAll(addr2.address, true);
          // Check that addr1 has approved addr2
          expect(await erc1155.isApprovedForAll(addr1.address, addr2.address)).to.equal(true);
        });
     }); 

  describe('Transferring', function () {
    it('Should transfer tokens safely', async function () {
      // Transfer tokens from owner to addr1
      await erc1155.transfer(addr1.address, (500n * decimals));
      // Connect erc1155 to addr1 to send the transaction from addr 1
      await erc1155.connect(addr1).setApprovalForAll(addr2.address, true);
      // Connect erc1155 to addr2 to send safeTransferFrom from addr2
      await erc1155.connect(addr2)['safeTransferFrom(address,address,uint256,uint256,bytes)'](addr1.address, addr2.address, packs, 2, '0x');
      // Check ERC1155 balances of each
      expect(await erc1155.getBalanceOf(addr1.address, packs)).to.equal(3);
      expect(await erc1155.getBalanceOf(addr2.address, packs)).to.equal(2);
      // Check if ERC20 balances are also updated
      expect(await erc1155.balanceOf(addr1.address)).to.equal(460n * decimals);
      expect(await erc1155.balanceOf(addr2.address)).to.equal(40n * decimals);
    });

    it('Should batch transfer tokens safely', async function () {
      // Transfer tokens from owner to addr1
      await erc1155.transfer(addr1.address, (427n * decimals));
      // Connect erc1155 to addr1 to send the transaction from addr 1
      await erc1155.connect(addr1).setApprovalForAll(addr2.address, true);
      // Connect erc1155 to addr2 to send safeTransferFrom from addr2
      await erc1155.connect(addr2).safeBatchTransferFrom(addr1.address, addr2.address, 
        [cartons, packs, loosies], [1, 1, 5], '0x');
      // Check ERC1155 balances of each
      expect(await erc1155.getBalanceOf(addr1.address, cartons)).to.equal(1);
      expect(await erc1155.getBalanceOf(addr1.address, packs)).to.equal(0);
      expect(await erc1155.getBalanceOf(addr1.address, loosies)).to.equal(2);
      expect(await erc1155.getBalanceOf(addr2.address, cartons)).to.equal(1);
      expect(await erc1155.getBalanceOf(addr2.address, packs)).to.equal(1);
      expect(await erc1155.getBalanceOf(addr2.address, loosies)).to.equal(5);
      // Check ERC20 balances of each
      expect(await erc1155.balanceOf(addr1.address)).to.equal(202n * decimals);
      expect(await erc1155.balanceOf(addr2.address)).to.equal(225n * decimals);
    });
  });
});
/*
  describe('Metadata', function () {
    it('Should return correct URI', async function () {
      await erc1155.mint(addr1.address, 1, 100, '0x');
      expect(await erc1155.uri(1)).to.equal('some-uri');
    });
  });

  describe('Events', function () {
    it('Should emit TransferSingle event on transfer', async function () {
      await erc1155.mint(owner.address, 1, 100, '0x');
      await expect(erc1155.safeTransferFrom(owner.address, addr1.address, 1, 50, '0x'))
        .to.emit(erc1155, 'TransferSingle')
        .withArgs(owner.address, owner.address, addr1.address, 1, 50);
    });

    it('Should emit TransferBatch event on batch transfer', async function () {
      await erc1155.mintBatch(owner.address, [1, 2], [100, 200], '0x');
      await expect(erc1155.safeBatchTransferFrom(owner.address, addr1.address, [1, 2], [50, 100], '0x'))
        .to.emit(erc1155, 'TransferBatch')
        .withArgs(owner.address, owner.address, addr1.address, [1, 2], [50, 100]);
    });
  });

  describe('Approval', function () {
    it('Should set approval for all correctly', async function () {
      await erc1155.setApprovalForAll(addr1.address, true);
      expect(await erc1155.isApprovedForAll(owner.address, addr1.address)).to.equal(true);
    });
  });


});
*/
