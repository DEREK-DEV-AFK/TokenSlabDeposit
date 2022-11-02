const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Token Slab",() => {
    async function deployFixture() {
        const [addr1, addr2, addr3, addr4] = await ethers.getSigners();

        const contractErc20Token = await ethers.getContractFactory("mintableERC20");
        const ERC20TokenContract = await contractErc20Token.deploy("X Token","XT");

        const contractTokenSlab = await ethers.getContractFactory("tokenSlabDeposit");
        const TokenSlabContract = await contractTokenSlab.deploy(4,ERC20TokenContract.address);

        return {ERC20TokenContract, TokenSlabContract, addr1, addr2, addr3, addr4};
    }

    describe("Deployment", () => {
        describe("Token", () => {
            it("should have totalsupply zero", async () => {
                const {ERC20TokenContract} = await loadFixture(deployFixture);
                expect(await ERC20TokenContract.totalSupply()).to.be.equal(0);
            })
        })
        describe("TokenSlab", () => {
            it("should have currentslab variable to zero", async () => {
                const {TokenSlabContract} = await loadFixture(deployFixture);
                expect(await TokenSlabContract.currentSlab()).to.be.equal(0);
            })
            it("should have maxSlab variable with the same value whcih was assign", async () => {
                const {ERC20TokenContract, TokenSlabContract, addr1} = await loadFixture(deployFixture);
                expect(await TokenSlabContract.maxSlab()).to.be.equal(4);
            })
        })
    })
    describe("Deposit", () => {
        describe("Validation", () => {
            it("should check that the amount specify by user has also allowed to tokenslab contract to transfer", async () => {
                const {ERC20TokenContract, TokenSlabContract, addr1} = await loadFixture(deployFixture);
                expect(TokenSlabContract.depositToken(100)).to.rejectedWith("depositToken: please approve contract to transfer token");
            })
            it("should move to next slab if the current slab is full", async () => {
                const {ERC20TokenContract, TokenSlabContract, addr1, addr2} = await loadFixture(deployFixture);

                let One = "1000000000000000000"; // 1 ** 18
                let ten = "10000000000000000000"; // 10 ** 18
                let hundered = "100000000000000000000"; // 100 ** 18
                let thousand = "1000000000000000000000"; // 1000 ** 18
                
                // mint some token
                const mintToken = await ERC20TokenContract.mint(ethers.BigNumber.from(thousand));
                //console.log("minted ",ethers.utils.formatUnits(ethers.BigNumber.from(thousand)))
                mintToken.wait();

                //console.log(await ERC20TokenContract.totalSupply());

                // allow the token slab contract
                const allowanceTx = await ERC20TokenContract.approve(TokenSlabContract.address,ethers.BigNumber.from(thousand));
                allowanceTx.wait();

                // desposit token, filling the first slab 0
                const depositToken = await TokenSlabContract.depositToken(ethers.BigNumber.from(hundered));
                depositToken.wait();

                // it must be deposited to slab 1
                const depositTokenInSlab1 = await TokenSlabContract.depositToken(ethers.BigNumber.from(hundered));
                depositTokenInSlab1.wait();

                // checking which slab the user have deposit
                expect(await TokenSlabContract.userSlabsDepositInfo(addr1.address)).to.be.equal(1);

            })
        })
        describe("Event", () => {
            it("should emit event when deposit token", async () => {
                const {ERC20TokenContract, TokenSlabContract, addr1} = await loadFixture(deployFixture);
                // mint some token
                const mintToken = await ERC20TokenContract.mint(1000);
                mintToken.wait();

                // allow the token slab contract
                const allowanceTx = await ERC20TokenContract.approve(TokenSlabContract.address,100);
                allowanceTx.wait();

                // despot token
                expect(await TokenSlabContract.depositToken(100)).to.emit(TokenSlabContract,"deposit").withArgs(addr1.address,100,0);
            })
        })
    })
})